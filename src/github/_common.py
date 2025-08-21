import os, sys, yaml
from github import Github
import boto3
from botocore.exceptions import ClientError

def load_yaml(path):
    with open(path, 'r', encoding='utf-8') as f:
        return yaml.safe_load(f) or {}

def get_token(ssm_name=None, region="us-east-2", profile=None, dry_run=False):
    """
    Returns a token for live calls.
    In dry-run, if no env token is set, returns a dummy string without touching SSM.
    """
    # Prefer env var
    token = os.getenv("GITHUB_TOKEN") or os.getenv("GH_TOKEN")
    if token:
        return token

    if dry_run:
        # Do not touch SSM in dry-run; return a placeholder
        return "DRY-RUN"

    # Live mode: optionally use a profile and fetch from SSM
    if profile:
        boto3.setup_default_session(profile_name=profile, region_name=region)
    else:
        boto3.setup_default_session(region_name=region)

    if not ssm_name:
        raise RuntimeError("No token provided: set GITHUB_TOKEN/GH_TOKEN or supply --ssm-token")

    ssm = boto3.client("ssm", region_name=region)
    try:
        resp = ssm.get_parameter(Name=ssm_name, WithDecryption=True)
        return resp["Parameter"]["Value"]
    except ClientError as e:
        if e.response.get("Error", {}).get("Code") == "ParameterNotFound":
            raise SystemExit(
                f"ERROR: SSM param '{ssm_name}' not found in region '{region}'.\n"
                f"Fix: aws ssm put-parameter --name {ssm_name} --type SecureString --value <PAT> --overwrite --region {region}\n"
                f"Or set env var GITHUB_TOKEN (or GH_TOKEN) for a quick test."
            )
        raise

def gh_client(owner, token):
    gh = Github(login_or_token=token, per_page=100)
    org = gh.get_organization(owner)
    return gh, org
