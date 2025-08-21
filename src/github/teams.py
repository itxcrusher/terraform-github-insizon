#!/usr/bin/env python3
import argparse, sys
from _common import load_yaml, get_token, gh_client
from github.GithubException import GithubException

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--owner", required=True)
    ap.add_argument("--config", default="src/config/teams.yaml")
    ap.add_argument("--ssm-token", default="insizon-github-admin-token")
    ap.add_argument("--region", default="us-east-2")
    ap.add_argument("--dry-run", action="store_true")
    ap.add_argument("--profile", default=None)
    args = ap.parse_args()

    cfg = load_yaml(args.config)

    if args.dry_run:
        for t in cfg.get("teams", []):
            name = t["name"]
            print(f"DRY: create team {name}")
            for m in t.get("maintainers", []):
                print(f"DRY: set {m} as maintainer in {name}")
            for m in t.get("members", []):
                print(f"DRY: add {m} as member in {name}")
            for r in t.get("repos", []):
                print(f"DRY: grant {r.get('permission','pull')} on {r['name']} to {name}")
        sys.exit(0)

    token = get_token(args.ssm_token, region=args.region, profile=args.profile, dry_run=False)
    gh, org = gh_client(args.owner, token)

    for t in cfg.get("teams", []):
        name = t["name"]
        try:
            team = org.get_team_by_slug(name)
        except Exception:
            team = None

        if not team:
            team = org.create_team(name, privacy=t.get("privacy","closed"))
            print(f"OK: team created {name}")

        # Maintainers
        for m in t.get("maintainers", []):
            try:
                user_obj = gh.get_user(m)
                team.add_membership(user_obj, role="maintainer")
                print(f"OK: {m} set as maintainer in {name}")
            except GithubException as e:
                print(f"WARN: maintainer add failed {m} -> {name}: {e.data if hasattr(e,'data') else e}")
            except AssertionError:
                print(f"WARN: PyGithub expected a user object for maintainer {m}")

        # Members
        for m in t.get("members", []):
            try:
                user_obj = gh.get_user(m)
                team.add_membership(user_obj, role="member")
                print(f"OK: {m} added to {name}")
            except GithubException as e:
                print(f"WARN: member add failed {m} -> {name}: {e.data if hasattr(e,'data') else e}")
            except AssertionError:
                print(f"WARN: PyGithub expected a user object for member {m}")

        # Repo permissions
        for r in t.get("repos", []):
            repo = org.get_repo(r["name"])
            perm = r.get("permission","pull")
            try:
                # attach then set permission (idempotent)
                team.add_to_repos(repo)
            except Exception:
                pass
            team.update_team_repository(repo, permission=perm)
            print(f"OK: {name} -> {repo.name} ({perm})")

if __name__ == "__main__":
    sys.exit(main())
