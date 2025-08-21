#!/usr/bin/env python3
import argparse, sys
from _common import load_yaml, get_token, gh_client

def _resolve_key(ref, dry_run=False, skip_missing=False):
    if dry_run:
        return f"<dry-run:{ref}>"
    try:
        if ref.startswith("file:"):
            p = ref.split("file:",1)[1]
            with open(p, "r", encoding="utf-8") as f:
                return f.read().strip()
        if ref.startswith("literal:"):
            return ref.split("literal:",1)[1]
        raise ValueError(f"Unsupported key ref: {ref}")
    except Exception as e:
        if skip_missing:
            print(f"WARN: could not resolve deploy key '{ref}' ({e}); skipping due to --skip-missing")
            return None
        raise

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--owner", required=True)
    ap.add_argument("--config", default="src/config/secrets.yaml")
    ap.add_argument("--ssm-token", default="insizon-github-admin-token")
    ap.add_argument("--region", default="us-east-2")
    ap.add_argument("--dry-run", action="store_true")
    ap.add_argument("--skip-missing", action="store_true")
    ap.add_argument("--profile", default=None)
    args = ap.parse_args()

    cfg = load_yaml(args.config) or {}

    if args.dry_run:
        for repo_name, items in (cfg.get("deploy_keys") or {}).items():
            for it in items:
                title = it["title"]
                ro = bool(it.get("read_only", True))
                key = _resolve_key(it["key"], dry_run=True)
                print(f"DRY: add deploy key '{title}' (ro={ro}) to {repo_name} from {key}")
        sys.exit(0)

    token = get_token(args.ssm_token, region=args.region, profile=args.profile, dry_run=False)
    gh, org = gh_client(args.owner, token)

    deploy = cfg.get("deploy_keys") or {}
    for repo_name, items in deploy.items():
        repo = org.get_repo(repo_name)
        existing = {k.title: k for k in repo.get_keys()}
        for it in items:
            title = it["title"]
            key = _resolve_key(it["key"], dry_run=False, skip_missing=args.skip_missing)
            if key is None:
                continue
            ro = bool(it.get("read_only", True))
            if title in existing:
                print(f"SKIP: deploy key '{title}' already exists on {repo_name}")
                continue
            repo.create_key(title=title, key=key, read_only=ro)
            print(f"OK: deploy key '{title}' added to {repo_name}")

if __name__ == "__main__":
    sys.exit(main())
