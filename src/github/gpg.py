#!/usr/bin/env python3
import argparse, sys, requests, json, os
from _common import load_yaml, get_token

API = "https://api.github.com"
def _h(tok): return {"Authorization": f"Bearer {tok}", "Accept": "application/vnd.github+json"}

def _ssm_value(name, region, profile=None):
    import boto3, botocore
    if profile:
        session = boto3.Session(profile_name=profile, region_name=region)
        ssm = session.client("ssm")
    else:
        ssm = boto3.client("ssm", region_name=region)
    try:
        resp = ssm.get_parameter(Name=name, WithDecryption=True)
        return resp["Parameter"]["Value"]
    except botocore.exceptions.ClientError as e:
        raise FileNotFoundError(f"SSM parameter not found: {name}") from e

def _resolve_armored(ref, region, profile=None, dry_run=False, skip_missing=False):
    """
    Supports:
      - file:path/to/key.asc
      - literal:-----BEGIN PGP PUBLIC KEY BLOCK----- ...
      - ssm:/path/to/armored/key
    In dry-run: never touch filesystem/SSM; returns placeholder.
    With --skip-missing: returns None if source is missing.
    """
    if dry_run:
        return f"<dry-run:{ref}>"

    try:
        if ref.startswith("file:"):
            p = ref.split("file:",1)[1]
            with open(p, "r", encoding="utf-8") as f:
                return f.read()
        if ref.startswith("literal:"):
            return ref.split("literal:",1)[1]
        if ref.startswith("ssm:"):
            name = ref.split("ssm:",1)[1]
            return _ssm_value(name, region, profile)
        raise SystemExit(f"Unsupported armored key ref: {ref}")
    except Exception as e:
        if skip_missing:
            print(f"WARN: could not resolve GPG key '{ref}' ({e}); skipping due to --skip-missing")
            return None
        raise

def _already_uploaded(tok, armored_prefix_hint=None):
    """
    Lightweight idempotency: fetch user GPG keys and optionally
    look for a prefix match to avoid duplicate POSTs when possible.
    (We can't compute fingerprints without parsing; this is best-effort.)
    """
    try:
        r = requests.get(f"{API}/user/gpg_keys", headers=_h(tok))
        if r.status_code != 200:
            return set()
        data = r.json()
        notes = set()
        for k in data:
            # GitHub returns 'key_id','id','public_key','emails', etc.
            # We store title-ish hint in 'notes' via armored_prefix_hint match.
            # Not perfect, but better than hammering POST repeatedly.
            if armored_prefix_hint:
                if any(armored_prefix_hint in str(v) for v in k.values() if isinstance(v, (str, list, dict))):
                    notes.add("HINT-MATCH")
        return notes
    except Exception:
        return set()

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--config", default="src/config/secrets.yaml")
    ap.add_argument("--ssm-token", default="insizon-github-admin-token")
    ap.add_argument("--region", default="us-east-2")
    ap.add_argument("--dry-run", action="store_true")
    ap.add_argument("--skip-missing", action="store_true", help="Skip if key source is missing")
    ap.add_argument("--profile", default=None, help="AWS profile for SSM lookups")
    args = ap.parse_args()

    cfg = load_yaml(args.config) or {}
    tok = get_token(args.ssm_token, region=args.region, profile=args.profile)

    # secrets.yaml schema:
    # gpg_keys:
    #   - armored_key: file:private/gpg/user.pub.asc
    #   - armored_key: ssm:/org/gpg/armored_public_key
    #   - armored_key: literal:-----BEGIN PGP PUBLIC KEY BLOCK-----\n...
    keys = cfg.get("gpg_keys") or []
    for k in keys:
        ref = k["armored_key"]
        armored = _resolve_armored(ref, args.region, args.profile, dry_run=args.dry_run, skip_missing=args.skip_missing)
        if armored is None:
            continue

        # small idempotency hint: first 40 chars as a prefix marker
        hint = armored.strip().replace("\r","").splitlines()[0] if armored else ""
        if args.dry_run:
            print(f"DRY: add user GPG key (source={ref}, hint={hint[:40]!r})")
            continue

        # If best-effort says likely present, skip POST
        if _already_uploaded(tok, armored_prefix_hint=hint):
            print("SKIP: a GPG key with similar hint appears to be already uploaded")
            continue

        r = requests.post(f"{API}/user/gpg_keys", headers=_h(tok),
                          data=json.dumps({"armored_public_key": armored}))
        # Accept common "already exists"/validation responses gracefully
        if r.status_code in (201, 200):
            print("OK: user GPG key added")
        elif r.status_code in (409, 422):
            # 409 Conflict or 422 Unprocessable Entity typically means duplicate or invalid; surface minimal info
            msg = r.text.strip().replace("\n"," ")
            print(f"INFO: GPG add returned {r.status_code}: {msg}")
        else:
            raise SystemExit(f"GPG add failed: {r.status_code} {r.text}")

if __name__ == "__main__":
    sys.exit(main())
