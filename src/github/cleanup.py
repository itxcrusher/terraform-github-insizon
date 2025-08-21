#!/usr/bin/env python3
import argparse, sys, json, requests
from _common import load_yaml, get_token, gh_client
from github import GithubException

API = "https://api.github.com"
H = {"Accept": "application/vnd.github+json", "X-GitHub-Api-Version": "2022-11-28"}
def _h(tok): return {"Authorization": f"Bearer {tok}", **H}

def _del(url, tok, ok=(204,200,202,404)):
    r = requests.delete(url, headers=_h(tok))
    if r.status_code not in ok:
        raise SystemExit(f"DELETE {url} -> {r.status_code} {r.text}")

# ---------- helpers ----------
def remove_branch_protection(owner, repo, branch, tok, dry):
    url = f"{API}/repos/{owner}/{repo}/branches/{branch}/protection"
    if dry: 
        print(f"DRY: remove protection {owner}/{repo}@{branch}")
        return
    _del(url, tok); print(f"OK: removed protection {owner}/{repo}@{branch}")

def remove_rulesets(owner, repo, names, tok, dry):
    # list all, delete those with matching names
    url = f"{API}/repos/{owner}/{repo}/rulesets"
    if dry:
        print(f"DRY: delete rulesets {names} on {owner}/{repo}")
        return
    r = requests.get(url, headers=_h(tok)); r.raise_for_status()
    for rs in r.json():
        if rs.get("name") in names:
            _del(f"{url}/{rs['id']}", tok); print(f"OK: deleted ruleset '{rs['name']}' on {repo}")

def delete_repo_webhooks(owner, repo, urls, tok, dry):
    if dry:
        for u in urls: print(f"DRY: delete repo webhook {u} on {repo}")
        return
    r = requests.get(f"{API}/repos/{owner}/{repo}/hooks", headers=_h(tok))
    if r.status_code == 404: 
        print(f"SKIP: repo {repo} missing for webhook cleanup"); return
    r.raise_for_status()
    hooks = r.json()
    for h in hooks:
        if h.get("config",{}).get("url") in urls:
            _del(f"{API}/repos/{owner}/{repo}/hooks/{h['id']}", tok); print(f"OK: deleted repo webhook {h['config']['url']}")

def delete_org_webhooks(owner, urls, tok, dry, org):
    if dry:
        for u in urls: print(f"DRY: delete org webhook {u}")
        return
    for h in org.get_hooks():
        if h.config.get("url") in urls:
            h.delete(); print(f"OK: deleted org webhook {h.config.get('url')}")

def delete_org_secret(owner, name, tok, dry):
    url = f"{API}/orgs/{owner}/actions/secrets/{name}"
    if dry: 
        print(f"DRY: delete org secret {name}"); return
    _del(url, tok); print(f"OK: deleted org secret {name}")

def delete_repo_secret(owner, repo, name, tok, dry):
    url = f"{API}/repos/{owner}/{repo}/actions/secrets/{name}"
    if dry: 
        print(f"DRY: delete repo {repo} secret {name}"); return
    _del(url, tok); print(f"OK: deleted repo {repo} secret {name}")

def delete_env_secret(owner, repo, env, name, tok, dry):
    url = f"{API}/repos/{owner}/{repo}/environments/{env}/secrets/{name}"
    if dry:
        print(f"DRY: delete env secret {name} in {repo}/{env}"); return
    _del(url, tok); print(f"OK: deleted env secret {name} in {repo}/{env}")

def delete_deploy_keys(org, repo_name, titles, dry):
    if dry:
        for t in titles: print(f"DRY: delete deploy key '{t}' on {repo_name}")
        return
    try:
        repo = org.get_repo(repo_name)
    except Exception:
        print(f"SKIP: repo {repo_name} not found for deploy keys"); return
    existing = {k.title: k for k in repo.get_keys()}
    for t in titles:
        k = existing.get(t)
        if k:
            k.delete(); print(f"OK: deleted deploy key '{t}' on {repo_name}")
        else:
            print(f"SKIP: deploy key '{t}' not present on {repo_name}")

def remove_team(org, slug, repos_to_detach, dry):
    try:
        team = org.get_team_by_slug(slug)
    except Exception:
        print(f"SKIP: team {slug} not found"); return
    if dry:
        for r in repos_to_detach: print(f"DRY: remove {slug} access to {r}")
        print(f"DRY: delete team {slug}")
        return
    # detach perms
    for r in repos_to_detach:
        try:
            repo = org.get_repo(r)
            team.remove_from_repos(repo)
            print(f"OK: removed {slug} access to {r}")
        except Exception:
            pass
    team.delete(); print(f"OK: deleted team {slug}")

def archive_or_delete_repo(org, name, mode, dry):
    try:
        repo = org.get_repo(name)
    except Exception:
        print(f"SKIP: repo {name} not found"); return
    if dry:
        print(f"DRY: {mode} repo {name}"); return
    if mode == "archive":
        repo.edit(archived=True); print(f"OK: archived {name}")
    elif mode == "delete":
        repo.delete(); print(f"OK: deleted {name}")
    else:
        raise SystemExit(f"Unknown mode {mode}")

# ---------- main ----------
def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--owner", required=True)
    ap.add_argument("--repos", default="src/config/repos.yaml")
    ap.add_argument("--teams", default="src/config/teams.yaml")
    ap.add_argument("--secrets", default="src/config/secrets.yaml")
    ap.add_argument("--ssm-token", default="insizon-github-token")
    ap.add_argument("--region", default="us-east-2")
    ap.add_argument("--profile", default=None)
    ap.add_argument("--dry-run", action="store_true")
    ap.add_argument("--force", action="store_true", help="Required for destructive actions")
    ap.add_argument("--repo-mode", choices=["archive","delete"], default="archive")
    ap.add_argument("--include-gpg", action="store_true", help="Also delete user GPG keys added by automation (best-effort)")
    args = ap.parse_args()

    if not args.force and not args.dry_run:
        raise SystemExit("Refusing to run live cleanup without --force. Use --dry-run to preview.")

    token = get_token(args.ssm_token, region=args.region, profile=args.profile, dry_run=False)
    gh, org = gh_client(args.owner, token)

    repos_cfg  = load_yaml(args.repos) or {}
    teams_cfg  = load_yaml(args.teams) or {}
    secret_cfg = load_yaml(args.secrets) or {}

    # ---- CLEAN ORDER ----
    # 0) Org webhooks (optional)
    org_urls = [h.get("url") for h in (secret_cfg.get("org_webhooks") or []) if h.get("url")]
    if org_urls:
        delete_org_webhooks(args.owner, org_urls, token, args.dry_run, org)

    # 1) Secrets (org → repo → env) — so nothing references them later
    for k in (secret_cfg.get("org") or {}).keys():
        delete_org_secret(args.owner, k, token, args.dry_run)

    for repo_name, kv in (secret_cfg.get("repos") or {}).items():
        for k in (kv or {}).keys():
            delete_repo_secret(args.owner, repo_name, k, token, args.dry_run)

    for repo_name, envs in (secret_cfg.get("envs") or {}).items():
        for env, kv in (envs or {}).items():
            for k in (kv or {}).keys():
                delete_env_secret(args.owner, repo_name, env, k, token, args.dry_run)

    # 2) Deploy keys
    for repo_name, items in (secret_cfg.get("deploy_keys") or {}).items():
        titles = [it.get("title") for it in items or [] if it.get("title")]
        delete_deploy_keys(org, repo_name, titles, args.dry_run)

    # 3) Teams → remove permissions then delete team
    for t in (teams_cfg.get("teams") or []):
        slug = t.get("name")
        repos = [r.get("name") for r in t.get("repos", []) if r.get("name")]
        remove_team(org, slug, repos, args.dry_run)

    # 4) Per-repo cleanup: protection, rulesets, webhooks → then archive/delete
    for spec in (repos_cfg.get("repos") or []):
        name = spec.get("name")
        # remove branch protection
        for p in spec.get("protected_branches", []) or []:
            remove_branch_protection(args.owner, name, p.get("name"), token, args.dry_run)
        # remove rulesets by name
        rs_names = [r.get("name") for r in spec.get("rulesets", []) or [] if r.get("name")]
        if rs_names:
            remove_rulesets(args.owner, name, rs_names, token, args.dry_run)
        # remove repo webhooks
        urls = [h.get("url") for h in (spec.get("repo_webhooks") or []) if h.get("url")]
        if urls:
            delete_repo_webhooks(args.owner, name, urls, token, args.dry_run)
        # archive or delete repo
        archive_or_delete_repo(org, name, args.repo_mode, args.dry_run)

    # 5) (Optional) GPG keys — best-effort only (not strongly recommended)
    if args.include_gpg:
        if args.dry_run:
            print("DRY: would list and delete user GPG keys (best effort, not fingerprint-matched)")
        else:
            r = requests.get(f"{API}/user/gpg_keys", headers=_h(token))
            if r.status_code == 200:
                for k in r.json():
                    _del(f"{API}/user/gpg_keys/{k['id']}", token); print(f"OK: deleted user GPG key id={k['id']}")

    print("CLEANUP COMPLETE (preview)" if args.dry_run else "CLEANUP COMPLETE")

if __name__ == "__main__":
    sys.exit(main())
