#!/usr/bin/env python3
import argparse, sys, requests
from _common import load_yaml, get_token, gh_client
from github.GithubException import GithubException

API = "https://api.github.com"
H = {"Accept": "application/vnd.github+json", "X-GitHub-Api-Version": "2022-11-28"}

def _h(tok):
    return {"Authorization": f"Bearer {tok}", **H}

def invite_user_rest(org_login, token, invitee_id=None, email=None, role="direct_member"):
    """
    POST /orgs/{org}/invitations
    Scopes: admin:org
    Body can include either invitee_id OR email
    """
    url = f"{API}/orgs/{org_login}/invitations"
    payload = {"role": role}
    if invitee_id is not None:
        payload["invitee_id"] = int(invitee_id)
    if email:
        payload["email"] = email

    r = requests.post(url, headers=_h(token), json=payload)
    if r.status_code == 201:
        return True, "invited"
    if r.status_code == 422:
        return False, f"already invited/member ({r.text.strip()})"
    return False, f"{r.status_code} {r.text}"

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--owner", required=True)
    ap.add_argument("--config", default="src/config/users.yaml")
    ap.add_argument("--ssm-token", default="insizon-github-admin-token")
    ap.add_argument("--region", default="us-east-2")
    ap.add_argument("--dry-run", action="store_true")
    ap.add_argument("--profile", default=None)
    args = ap.parse_args()

    cfg = load_yaml(args.config)

    if args.dry_run:
        for u in cfg.get("users", []):
            who = u.get("username") or u.get("email")
            role = u.get("role","direct_member")
            print(f"DRY: invite {who} as {role}")
            if u.get("username"):
                for t in u.get("teams", []):
                    print(f"DRY: add {u['username']} to team {t} (after acceptance)")
            elif u.get("teams"):
                print(f"INFO: email-only invite; re-run after acceptance to add to teams: {u['teams']}")
        sys.exit(0)

    token = get_token(args.ssm_token, region=args.region, profile=args.profile, dry_run=False)
    gh, org = gh_client(args.owner, token)

    # normalize role values from YAML → GitHub API expected values
    role_map = {
        "member": "direct_member",
        "direct_member": "direct_member",
        "admin": "admin",
        "owner": "admin",  # closest org-level analog
        "billing_manager": "billing_manager",
    }

    for u in cfg.get("users", []):
        username = u.get("username")
        email = u.get("email")
        role_in = (u.get("role") or "direct_member").strip().lower()
        role = role_map.get(role_in, "direct_member")
        team_slugs = u.get("teams", [])

        invitee_id = None
        user_obj = None
        if username:
            try:
                user_obj = gh.get_user(username)
                invitee_id = user_obj.id
            except GithubException as e:
                print(f"WARN: could not resolve username {username}: {e.data if hasattr(e,'data') else e}. Will try email if provided.")

        ok, msg = invite_user_rest(org.login, token, invitee_id=invitee_id, email=email, role=role)
        target = username or email
        if ok:
            print(f"OK: invitation sent to {target}")
        else:
            print(f"INFO: invite for {target}: {msg}")

        # Add to teams only when we have a username (best-effort; may fail until they accept)
        if username and team_slugs:
            if user_obj is None:
                try:
                    user_obj = gh.get_user(username)
                except GithubException:
                    user_obj = None
            for tslug in team_slugs:
                try:
                    team = org.get_team_by_slug(tslug)
                    if user_obj:
                        team.add_membership(user_obj)  # defaults to member
                        print(f"OK: added {username} to team {tslug}")
                    else:
                        print(f"INFO: cannot add {username} to {tslug} yet (no user object). Re-run after acceptance.")
                except GithubException as e:
                    print(f"INFO: add to team queued/failed for {username} -> {tslug}: {e.data if hasattr(e,'data') else e}")
        elif team_slugs and not username:
            print(f"INFO: email-only invite; re-run users.py after acceptance to add to teams: {team_slugs}")

if __name__ == "__main__":
    sys.exit(main())
