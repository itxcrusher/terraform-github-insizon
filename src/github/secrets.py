#!/usr/bin/env python3
import argparse, os, sys, yaml, base64, json, requests
from _common import load_yaml, get_token
import pathlib, stat

try:
    from nacl import encoding, public  # requires pynacl
except Exception as e:
    raise SystemExit("PyNaCl is required. Install dependencies first: pip install -r src/github/requirements.txt") from e

API = "https://api.github.com"
H = {"Accept": "application/vnd.github+json"}

def _h(tok):
    return {"Authorization": f"Bearer {tok}", **H}

def _get(url, tok):
    r = requests.get(url, headers=_h(tok))
    r.raise_for_status()
    return r.json()

def _put(url, tok, payload):
    r = requests.put(url, headers=_h(tok), data=json.dumps(payload))
    r.raise_for_status()
    return r.json() if r.text else {}

def _ensure_pynacl():
    try:
        import nacl; return
    except Exception:
        os.system("python3 -m pip install pynacl >/dev/null 2>&1 || pip install pynacl >/dev/null 2>&1")

def _encrypt(public_key_b64, value_str):
    pk = public.PublicKey(base64.b64decode(public_key_b64))
    sealed_box = public.SealedBox(pk)
    enc = sealed_box.encrypt(value_str.encode("utf-8"))
    return base64.b64encode(enc).decode("utf-8")

def _ssm_client(region, profile=None):
    import boto3
    if profile:
        session = boto3.Session(profile_name=profile, region_name=region)
        return session.client("ssm")
    return boto3.client("ssm", region_name=region)

def _resolve_ref_live(ref, region, profile):
    if ref.startswith("literal:"):
        return ref.split("literal:", 1)[1]
    if ref.startswith("file:"):
        p = ref.split("file:", 1)[1]
        with open(p, "r", encoding="utf-8") as f:
            return f.read().strip()
    if ref.startswith("ssm:"):
        name = ref.split("ssm:", 1)[1]
        ssm = _ssm_client(region, profile)
        resp = ssm.get_parameter(Name=name, WithDecryption=True)
        return resp["Parameter"]["Value"]
    raise ValueError(f"Unsupported secret ref: {ref}")

def _resolve_ref(ref, region, profile, dry_run=False, skip_missing=False):
    if dry_run:
        return f"<dry-run:{ref}>"
    try:
        return _resolve_ref_live(ref, region, profile)
    except FileNotFoundError as e:
        if skip_missing:
            print(f"WARN: file not found for ref '{ref}'; skipping due to --skip-missing")
            return None
        raise
    except Exception as e:
        if skip_missing:
            print(f"WARN: could not resolve '{ref}' ({e}); skipping due to --skip-missing")
            return None
        raise

def _get_repo_id_map(owner, tok):
    r = requests.get(f"{API}/orgs/{owner}/repos?per_page=100", headers=_h(tok))
    r.raise_for_status()
    return {x["name"]: x["id"] for x in r.json()}

def upsert_org_secret(org, name, value, tok, dry, visibility="all", selected_repo_ids=None):
    if dry:
        print(f"DRY: org secret {name} vis={visibility} selected={selected_repo_ids}")
        return
    pk = _get(f"{API}/orgs/{org}/actions/secrets/public-key", tok)
    payload = {
        "encrypted_value": _encrypt(pk["key"], value),
        "key_id": pk["key_id"],
        "visibility": visibility
    }
    if visibility == "selected":
        payload["selected_repository_ids"] = selected_repo_ids or []
    _put(f"{API}/orgs/{org}/actions/secrets/{name}", tok, payload)
    print(f"OK: org secret {name} upserted (vis={visibility})")

def upsert_repo_secret(owner, repo, name, value, tok, dry):
    if dry:
        print(f"DRY: repo {repo} secret {name}")
        return
    pk = _get(f"{API}/repos/{owner}/{repo}/actions/secrets/public-key", tok)
    _put(f"{API}/repos/{owner}/{repo}/actions/secrets/{name}", tok, {
        "encrypted_value": _encrypt(pk["key"], value),
        "key_id": pk["key_id"]
    })
    print(f"OK: repo {repo} secret {name} upserted")

def upsert_env_secret(owner, repo, env, name, value, tok, dry):
    if dry:
        print(f"DRY: repo {repo} env {env} secret {name}")
        return
    pk = _get(f"{API}/repos/{owner}/{repo}/environments/{env}/secrets/public-key", tok)
    _put(f"{API}/repos/{owner}/{repo}/environments/{env}/secrets/{name}", tok, {
        "encrypted_value": _encrypt(pk["key"], value),
        "key_id": pk["key_id"]
    })
    print(f"OK: repo {repo} env {env} secret {name} upserted")

def _safe_write(root, parts, name, value):
    base = pathlib.Path(root).joinpath(*parts)
    base.mkdir(parents=True, exist_ok=True)
    fp = base / name
    with open(fp, "w", encoding="utf-8") as f:
        f.write(value)
    try:
        fp.chmod(stat.S_IRUSR | stat.S_IWUSR)
    except Exception:
        pass
    print(f"DUMP: wrote {fp}")

def main():
    _ensure_pynacl()
    ap = argparse.ArgumentParser()
    ap.add_argument("--owner", required=True)
    ap.add_argument("--config", default="src/config/secrets.yaml")
    ap.add_argument("--ssm-token", default="insizon-github-admin-token")
    ap.add_argument("--region", default="us-east-2")
    ap.add_argument("--dry-run", action="store_true")
    ap.add_argument("--skip-missing", action="store_true")
    ap.add_argument("--dump-dir", default="private/github_secrets")
    ap.add_argument("--profile", default=None)
    args = ap.parse_args()

    cfg = load_yaml(args.config) or {}
    tok = get_token(args.ssm_token, region=args.region, profile=args.profile, dry_run=args.dry_run)

    # ORG secrets
    org_cfg = cfg.get("org") or {}
    repo_id_map = None
    for k, v in org_cfg.items():
        if isinstance(v, dict):
            ref = v.get("value")
            visibility = v.get("visibility", "all")
            sel = v.get("selected_repos", [])
            sel_ids = None
            if visibility == "selected":
                if args.dry_run:
                    sel_ids = []  # do not call GitHub in dry-run
                else:
                    repo_id_map = repo_id_map or _get_repo_id_map(args.owner, tok)
                    sel_ids = [repo_id_map[r] for r in sel if r in repo_id_map]
            val = _resolve_ref(ref, args.region, args.profile, dry_run=args.dry_run, skip_missing=args.skip_missing)
            if val is None:
                continue
            if args.dump_dir and not args.dry_run:
                _safe_write(args.dump_dir, ["org"], k, val)
            upsert_org_secret(args.owner, k, val, tok, args.dry_run, visibility, sel_ids)
        else:
            val = _resolve_ref(v, args.region, args.profile, dry_run=args.dry_run, skip_missing=args.skip_missing)
            if val is None:
                continue
            if args.dump_dir and not args.dry_run:
                _safe_write(args.dump_dir, ["org"], k, val)
            upsert_org_secret(args.owner, k, val, tok, args.dry_run, "all", None)

    # REPO secrets
    for repo, kv in (cfg.get("repos") or {}).items():
        for k, ref in (kv or {}).items():
            val = _resolve_ref(ref, args.region, args.profile, dry_run=args.dry_run, skip_missing=args.skip_missing)
            if val is None:
                continue
            if args.dump_dir and not args.dry_run:
                _safe_write(args.dump_dir, ["repo", repo], k, val)
            upsert_repo_secret(args.owner, repo, k, val, tok, args.dry_run)

    # ENV secrets
    for repo, envs in (cfg.get("envs") or {}).items():
        for env, kv in (envs or {}).items():
            for k, ref in (kv or {}).items():
                val = _resolve_ref(ref, args.region, args.profile, dry_run=args.dry_run, skip_missing=args.skip_missing)
                if val is None:
                    continue
                if args.dump_dir and not args.dry_run:
                    _safe_write(args.dump_dir, ["env", repo, env], k, val)
                upsert_env_secret(args.owner, repo, env, k, val, tok, args.dry_run)

if __name__ == "__main__":
    sys.exit(main())
