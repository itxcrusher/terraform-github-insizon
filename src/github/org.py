#!/usr/bin/env python3
import argparse, sys, requests
from _common import load_yaml, get_token, gh_client

API = "https://api.github.com"
HDR = {"Accept": "application/vnd.github+json"}

def _ssm_value(name, region, profile=None):
    import boto3
    if profile:
        session = boto3.Session(profile_name=profile, region_name=region)
        ssm = session.client("ssm")
    else:
        ssm = boto3.client("ssm", region_name=region)
    resp = ssm.get_parameter(Name=name, WithDecryption=True)
    return resp["Parameter"]["Value"]

def _resolve_value(ref, region, profile=None, dry_run=False, skip_missing=False):
    if dry_run:
        return f"<dry-run:{ref}>"
    try:
        if ref.startswith("literal:"):
            return ref.split("literal:", 1)[1]
        if ref.startswith("file:"):
            p = ref.split("file:", 1)[1]
            with open(p, "r", encoding="utf-8") as f:
                return f.read().strip()
        if ref.startswith("ssm:"):
            name = ref.split("ssm:", 1)[1]
            return _ssm_value(name, region, profile)
        raise ValueError(f"Unsupported secret ref: {ref}")
    except Exception as e:
        if skip_missing:
            print(f"WARN: could not resolve webhook secret '{ref}' ({e}); skipping due to --skip-missing")
            return None
        raise

def _require_scope(token, scope):
    r = requests.get(API, headers={"Authorization": f"Bearer {token}", **HDR})
    scopes = [s.strip() for s in r.headers.get("x-oauth-scopes","").split(",") if s.strip()]
    if scope not in scopes:
        raise SystemExit(f"ERROR: token missing required scope '{scope}'. Present: {scopes}")

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

    # Dry-run: skip token lookup and API calls completely
    if args.dry_run:
        hooks = cfg.get("org_webhooks") or []
        for h in hooks:
            print(f"DRY: create org webhook -> {h['url']}")
        sys.exit(0)

    tok = get_token(args.ssm_token, region=args.region, profile=args.profile, dry_run=False)
    _require_scope(tok, "admin:org_hook")
    gh, org = gh_client(args.owner, tok)

    hooks = cfg.get("org_webhooks") or []
    existing = {h.config.get("url"): h for h in org.get_hooks()}

    for h in hooks:
        url = h["url"]
        if url in existing:
            print(f"SKIP: org webhook exists: {url}")
            continue

        secret = _resolve_value(h.get("secret","literal:"), args.region, args.profile, dry_run=False, skip_missing=args.skip_missing)
        if secret is None:
            continue

        payload = {
            "name": "web",
            "config": {
                "url": url,
                "content_type": h.get("content_type","json"),
                "secret": secret,
                "insecure_ssl": "0"
            },
            "events": h.get("events", ["push"]),
            "active": bool(h.get("active", True))
        }
        org.create_hook(**payload)
        print(f"OK: org webhook created -> {url}")

if __name__ == "__main__":
    sys.exit(main())
