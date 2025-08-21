#!/usr/bin/env python3
import argparse, sys, json, requests
from _common import load_yaml, get_token, gh_client
from github import GithubException

API = "https://api.github.com"
H = {"Accept": "application/vnd.github+json", "X-GitHub-Api-Version": "2022-11-28"}
def _h(tok): return {"Authorization": f"Bearer {tok}", **H}

def _delete_branch_protection(owner, repo, branch, tok):
    url = f"{API}/repos/{owner}/{repo}/branches/{branch}/protection"
    r = requests.delete(url, headers=_h(tok))
    if r.status_code not in (204, 404):
        raise SystemExit(f"Failed to delete protection {owner}/{repo}@{branch}: {r.status_code} {r.text}")

def _apply_protection_from_spec(owner, repo, branch, spec, tok):
    ensure_branch_protection(owner, repo, branch, spec, tok, dry=False)

def upsert_file(repo, path, content_str, message, branch):
    from github import GithubException
    try:
        existing = repo.get_contents(path, ref=branch)
        repo.update_file(path, message, content_str, existing.sha, branch=branch)
        print(f"OK: updated {repo.full_name}:{path} on {branch}")
        return True
    except GithubException as e:
        if getattr(e, "status", None) == 404:
            repo.create_file(path, message, content_str, branch=branch)
            print(f"OK: created {repo.full_name}:{path} on {branch}")
            return True
        raise  # let caller decide (e.g., on 409)

def ensure_branch_protection(owner, repo, branch, spec, tok, dry):
    url = f"{API}/repos/{owner}/{repo}/branches/{branch}/protection"
    payload = {
        "required_status_checks": None,
        "enforce_admins": bool(spec.get("enforce_admins", True)),
        "required_pull_request_reviews": None,
        "restrictions": None,
        "required_linear_history": False,
        "allow_force_pushes": False,
        "allow_deletions": False,
        "block_creations": False,
        "required_conversation_resolution": False,
    }
    rsc = spec.get("require_status_checks", {}) or {}
    contexts = rsc.get("contexts", []) or []
    if contexts:
        payload["required_status_checks"] = {"strict": False, "contexts": contexts}

    prc = {}
    if "require_pr_reviews" in spec:
        prc["required_approving_review_count"] = int(spec["require_pr_reviews"])
    if spec.get("dismiss_stale_reviews"):
        prc["dismiss_stale_reviews"] = True
    payload["required_pull_request_reviews"] = prc or None

    if dry:
        print(f"DRY: protect {owner}/{repo}@{branch} -> {json.dumps(payload)}")
        return

    r = requests.put(url, headers=_h(tok), data=json.dumps(payload))
    if r.status_code not in (200, 201):
        raise SystemExit(f"Branch protection failed {owner}/{repo}@{branch}: {r.status_code} {r.text}")

def ensure_rulesets(owner, repo, rulesets, tok, dry):
    url = f"{API}/repos/{owner}/{repo}/rulesets"
    if dry:
        print(f"DRY: rulesets for {owner}/{repo}: {json.dumps(rulesets)}")
        return
    for rs in rulesets:
        payload = {
            "name": rs["name"],
            "target": rs.get("target", "branch"),
            "enforcement": rs.get("enforcement", "active"),
            "conditions": rs.get("conditions", {}),
            "rules": rs.get("rules", {})
        }
        r = requests.post(url, headers=_h(tok), data=json.dumps(payload))
        if r.status_code not in (201, 200, 422):
            raise SystemExit(f"Ruleset create failed {owner}/{repo}: {r.status_code} {r.text}")

def ensure_branch(repo, branch, from_branch="main"):
    try:
        repo.get_branch(branch)
    except GithubException:
        base = repo.get_branch(from_branch)
        repo.create_git_ref(ref=f"refs/heads/{branch}", sha=base.commit.sha)

def ensure_repo_webhooks(owner, repo, hooks, tok):
    # list, ensure present; create if missing
    url = f"{API}/repos/{owner}/{repo.name}/hooks"
    r = requests.get(url, headers=_h(tok)); r.raise_for_status()
    existing = {h["config"].get("url"): h for h in r.json()}
    for h in hooks or []:
        u = h["url"]
        if u in existing:
            print(f"SKIP: repo webhook exists: {u}")
            continue
        payload = {
          "name": "web",
          "config": {
            "url": u,
            "content_type": h.get("content_type","json"),
            "secret": h.get("secret") and h["secret"],  # resolve if needed
            "insecure_ssl": "0"
          },
          "events": h.get("events", ["push"]),
          "active": bool(h.get("active", True))
        }
        rr = requests.post(url, headers=_h(tok), json=payload)
        rr.raise_for_status()
        print(f"OK: repo webhook created -> {u}")

def upsert_with_unprotect(owner, token, repo, path, content_str, message, branch, protected_specs, allow_unprotect=False):
    try:
        return upsert_file(repo, path, content_str, message, branch)
    except Exception as e:
        is_409 = getattr(e, "status", None) == 409
        if not (is_409 and allow_unprotect):
            raise
        print(f"WARN: 409 writing {path} on {repo.full_name}@{branch}. Temporarily removing protection…")
        _delete_branch_protection(owner, repo.name, branch, token)
        ok = upsert_file(repo, path, content_str, message, branch)
        # Re-apply protection only for this branch, from YAML
        for p in protected_specs or []:
            if p.get("name") == branch:
                _apply_protection_from_spec(owner, repo.name, branch, p, token)
                print(f"OK: re-applied protection on {repo.full_name}@{branch}")
        return ok

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--owner", required=True)
    ap.add_argument("--config", default="src/config/repos.yaml")
    ap.add_argument("--ssm-token", default="insizon-github-admin-token")
    ap.add_argument("--region", default="us-east-2")
    ap.add_argument("--dry-run", action="store_true")
    ap.add_argument("--profile", default=None)
    ap.add_argument("--allow-unprotect", action="store_true")
    args = ap.parse_args()

    cfg = load_yaml(args.config)

    if args.dry_run:
        # Pure simulation: no network calls.
        for spec in cfg.get("repos", []):
            name = spec["name"]
            print(f"==> Repo: {name}")
            if spec.get("rename_from"):
                print(f"DRY: would rename {spec['rename_from']} -> {name}")
            print(f"DRY: would ensure repo exists (vis={spec.get('visibility','private')})")
            topics = spec.get("topics", [])
            if topics:
                print(f"DRY: set topics {topics} on {name}")
            def_branch = spec.get("default_branch", "main")
            print(f"DRY: set default branch to {def_branch} on {name}")
            branches = {def_branch}
            for b in spec.get("protected_branches", []): branches.add(b["name"])
            for env in spec.get("environments", []): branches.add(env)
            for b in sorted(branches): print(f"DRY: ensure branch {b}")
            for env in spec.get("environments", []): print(f"DRY: ensure environment {env}")
            for wf in spec.get("workflows", []): print(f"DRY: upsert workflow {wf['path']} from {wf['source_file']} (on {def_branch})")
            for p in spec.get("protected_branches", []): ensure_branch_protection(args.owner, name, p["name"], p, tok="DRY", dry=True)
            rs = spec.get("rulesets", [])
            if rs: ensure_rulesets(args.owner, name, rs, tok="DRY", dry=True)
            for rwh in spec.get("repo_webhooks", []) or []: print(f"DRY: repo webhook -> {rwh['url']}")
        sys.exit(0)

    token = get_token(args.ssm_token, region=args.region, profile=args.profile, dry_run=False)
    gh, org = gh_client(args.owner, token)

    for spec in cfg.get("repos", []):
        name = spec["name"]
        rename_from = spec.get("rename_from")

        # rename if requested
        if rename_from and rename_from != name:
            try:
                old = org.get_repo(rename_from)
                print(f"==> Renaming repo {rename_from} -> {name}")
                old.edit(name=name)
            except Exception:
                print(f"WARN: rename_from '{rename_from}' not found; creating {name} fresh")

        print(f"==> Repo: {name}")
        try:
            repo = org.get_repo(name); exists = True
        except Exception:
            exists = False

        if not exists:
            repo = org.create_repo(
                name=name,
                description=spec.get("description",""),
                private=(spec.get("visibility","private")!="public"),
                auto_init=True
            )

        # topics
        topics = spec.get("topics", [])
        if topics: repo.replace_topics(topics)

        # default branch
        def_branch = spec.get("default_branch", "main")
        if repo.default_branch != def_branch:
            try: repo.edit(default_branch=def_branch)
            except Exception: pass

        # branches + envs
        branches = {def_branch}
        for b in spec.get("protected_branches", []): branches.add(b["name"])
        for env in spec.get("environments", []): branches.add(env)
        for b in branches:
            if b != repo.default_branch:
                ensure_branch(repo, b, from_branch=repo.default_branch)
        for env in spec.get("environments", []):
            try: repo.create_environment(env)
            except Exception: pass

        # WORKFLOWS FIRST (to avoid 409 on protected branches) — with safe auto-unprotect
        prot_specs = spec.get("protected_branches", [])
        for wf in spec.get("workflows", []):
            with open(wf["source_file"], "r", encoding="utf-8") as f:
                content = f.read()
            upsert_with_unprotect(
                owner=args.owner,
                token=token,
                repo=repo,
                path=wf["path"],
                content_str=content,
                message=wf.get("message","chore: add workflow"),
                branch=repo.default_branch,
                protected_specs=prot_specs,
                allow_unprotect=args.allow_unprotect
            )

        # THEN protection & rulesets
        for p in spec.get("protected_branches", []):
            ensure_branch_protection(args.owner, name, p["name"], p, token, dry=False)

        rs = spec.get("rulesets", [])
        if rs:
            ensure_rulesets(args.owner, name, rs, token, dry=False)

        # repo webhooks (optional – not implemented yet)
        # for rwh in spec.get("repo_webhooks", []) or []:
        #     print("NOTE: repo_webhooks live handling not implemented in this path")
        # ensure_repo_webhooks(args.owner, repo, spec.get("repo_webhooks", []), token)

if __name__ == "__main__":
    sys.exit(main())
