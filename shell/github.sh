#!/usr/bin/env bash
set -euo pipefail

# ---- paths
SCRIPT_DIR="$(cd -- "$(dirname "$0")" >/dev/null 2>&1 && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
AUTO_CFG="$ROOT/src/config/automation.yaml"
PY="$ROOT/src/github"

# ---- pick Python (prefer repo venv)
if [[ -x "$ROOT/.venv/Scripts/python.exe" ]]; then
  PYTHON="$ROOT/.venv/Scripts/python.exe"         # Windows venv
elif [[ -x "$ROOT/.venv/bin/python" ]]; then
  PYTHON="$ROOT/.venv/bin/python"                  # Linux/macOS venv
else
  PYTHON="$(command -v python || command -v py -3 || true)"
fi
if [[ -z "${PYTHON:-}" ]]; then
  echo "ERROR: Could not find a Python interpreter." >&2
  exit 1
fi

# ---- read values from automation.yaml
yq_val() { # read simple or nested keys; warn when yq missing and nested requested
  local key="$1" ; local file="$2"
  if command -v yq >/dev/null 2>&1; then
    yq -r ".$key" "$file"
    return
  fi
  # naive fallback: only supports single-segment keys
  if [[ "$key" == *.* ]]; then
    echo "WARN: 'yq' not installed; cannot read nested key '$key' from $file. Using empty/default." >&2
    echo ""
  else
    awk -v k="$key" 'BEGIN{FS=": *"} $1==k {print $2}' "$file" | tr -d '"' | tr -d "'"
  fi
}

PROFILE="$(yq_val aws_profile "$AUTO_CFG")"
OWNER="$(yq_val owner "$AUTO_CFG")"
REGION="$(yq_val region "$AUTO_CFG")"
SSM_TOKEN="$(yq_val ssm_token "$AUTO_CFG" || echo "")"

REPOS_CFG="$(yq_val 'configs.repos'   "$AUTO_CFG" || echo "src/config/repos.yaml")"
TEAMS_CFG="$(yq_val 'configs.teams'   "$AUTO_CFG" || echo "src/config/teams.yaml")"
USERS_CFG="$(yq_val 'configs.users'   "$AUTO_CFG" || echo "src/config/users.yaml")"
SECRETS_CFG="$(yq_val 'configs.secrets' "$AUTO_CFG" || echo "src/config/secrets.yaml")"
DUMP_DIR="$(yq_val 'configs.dump'     "$AUTO_CFG" || echo "private/github_secrets")"

usage() {
  cat <<EOF
GitHub Automation

Usage:
  $0 dry-run             # simulate repos, secrets, keys, org hooks, teams, users, gpg
  $0 bootstrap           # run all live (repos -> secrets -> keys -> org hooks -> teams -> users -> gpg)

  $0 repos    [--live]   # only repos
  $0 secrets  [--live]   # org+repo+env secrets
  $0 keys     [--live]   # deploy keys
  $0 orghooks [--live]   # org webhooks
  $0 teams    [--live]
  $0 users    [--live]
  $0 gpg      [--live]

Notes:
- In live mode, secrets/keys/orghooks/gpg accept --skip-missing (wired by default in bootstrap).
- Dry-run never touches SSM/files and does not write dumps.
EOF
}

is_live() { [[ "${1:-}" == "--live" || "${1:-}" == "true" ]]; }

# run with venv python; add --dry-run automatically when not live
pyrun_or_dry() {
  local live="$1"; shift
  if is_live "$live"; then
    "$PYTHON" "$@"
  else
    "$PYTHON" "$@" --dry-run
  fi
}

case "${1:-}" in
  dry-run)
    "$PYTHON" "$PY/repos.py"    --owner "$OWNER" --profile "$PROFILE" --region "$REGION" --ssm-token "$SSM_TOKEN" --config "$REPOS_CFG"     --dry-run
    "$PYTHON" "$PY/secrets.py"  --owner "$OWNER" --profile "$PROFILE" --region "$REGION" --ssm-token "$SSM_TOKEN" --config "$SECRETS_CFG"  --dump-dir "$DUMP_DIR" --dry-run
    "$PYTHON" "$PY/ssh_keys.py" --owner "$OWNER" --profile "$PROFILE" --region "$REGION" --ssm-token "$SSM_TOKEN" --config "$SECRETS_CFG"  --dry-run
    "$PYTHON" "$PY/org.py"      --owner "$OWNER" --profile "$PROFILE" --region "$REGION" --ssm-token "$SSM_TOKEN" --config "$SECRETS_CFG"  --dry-run
    "$PYTHON" "$PY/teams.py"    --owner "$OWNER" --profile "$PROFILE" --region "$REGION" --ssm-token "$SSM_TOKEN" --config "$TEAMS_CFG"    --dry-run
    "$PYTHON" "$PY/users.py"    --owner "$OWNER" --profile "$PROFILE" --region "$REGION" --ssm-token "$SSM_TOKEN" --config "$USERS_CFG"    --dry-run
    "$PYTHON" "$PY/gpg.py"      --profile "$PROFILE" --region "$REGION" --ssm-token "$SSM_TOKEN" --config "$SECRETS_CFG"                   --dry-run
    ;;

  bootstrap)
    pyrun_or_dry true "$PY/repos.py"    --owner "$OWNER" --profile "$PROFILE" --region "$REGION" --ssm-token "$SSM_TOKEN" --config "$REPOS_CFG"
    pyrun_or_dry true "$PY/secrets.py"  --owner "$OWNER" --profile "$PROFILE" --region "$REGION" --ssm-token "$SSM_TOKEN" --config "$SECRETS_CFG" --dump-dir "$DUMP_DIR" --skip-missing
    pyrun_or_dry true "$PY/ssh_keys.py" --owner "$OWNER" --profile "$PROFILE" --region "$REGION" --ssm-token "$SSM_TOKEN" --config "$SECRETS_CFG" --skip-missing
    pyrun_or_dry true "$PY/org.py"      --owner "$OWNER" --profile "$PROFILE" --region "$REGION" --ssm-token "$SSM_TOKEN" --config "$SECRETS_CFG" --skip-missing
    pyrun_or_dry true "$PY/teams.py"    --owner "$OWNER" --profile "$PROFILE" --region "$REGION" --ssm-token "$SSM_TOKEN" --config "$TEAMS_CFG"
    pyrun_or_dry true "$PY/users.py"    --owner "$OWNER" --profile "$PROFILE" --region "$REGION" --ssm-token "$SSM_TOKEN" --config "$USERS_CFG"
    pyrun_or_dry true "$PY/gpg.py"      --profile "$PROFILE" --region "$REGION" --ssm-token "$SSM_TOKEN" --config "$SECRETS_CFG" --skip-missing
    ;;

  repos)
    pyrun_or_dry "${2:-}" "$PY/repos.py"    --owner "$OWNER" --profile "$PROFILE" --region "$REGION" --ssm-token "$SSM_TOKEN" --config "$REPOS_CFG" --allow-unprotect
    ;;

  secrets)
    # if live, append --skip-missing so absent SSM/file refs don't abort the run
    if is_live "${2:-}"; then
      "$PYTHON" "$PY/secrets.py" --owner "$OWNER" --profile "$PROFILE" --region "$REGION" --ssm-token "$SSM_TOKEN" --config "$SECRETS_CFG" --dump-dir "$DUMP_DIR" --skip-missing
    else
      "$PYTHON" "$PY/secrets.py" --owner "$OWNER" --profile "$PROFILE" --region "$REGION" --ssm-token "$SSM_TOKEN" --config "$SECRETS_CFG" --dump-dir "$DUMP_DIR" --dry-run
    fi
    ;;

  keys)
    if is_live "${2:-}"; then
      "$PYTHON" "$PY/ssh_keys.py" --owner "$OWNER" --profile "$PROFILE" --region "$REGION" --ssm-token "$SSM_TOKEN" --config "$SECRETS_CFG" --skip-missing
    else
      "$PYTHON" "$PY/ssh_keys.py" --owner "$OWNER" --profile "$PROFILE" --region "$REGION" --ssm-token "$SSM_TOKEN" --config "$SECRETS_CFG" --dry-run
    fi
    ;;

  orghooks)
    if is_live "${2:-}"; then
      "$PYTHON" "$PY/org.py" --owner "$OWNER" --profile "$PROFILE" --region "$REGION" --ssm-token "$SSM_TOKEN" --config "$SECRETS_CFG" --skip-missing
    else
      "$PYTHON" "$PY/org.py" --owner "$OWNER" --profile "$PROFILE" --region "$REGION" --ssm-token "$SSM_TOKEN" --config "$SECRETS_CFG" --dry-run
    fi
    ;;

  teams)
    pyrun_or_dry "${2:-}" "$PY/teams.py"    --owner "$OWNER" --profile "$PROFILE" --region "$REGION" --ssm-token "$SSM_TOKEN" --config "$TEAMS_CFG"
    ;;

  users)
    pyrun_or_dry "${2:-}" "$PY/users.py"    --owner "$OWNER" --profile "$PROFILE" --region "$REGION" --ssm-token "$SSM_TOKEN" --config "$USERS_CFG"
    ;;

  gpg)
    if is_live "${2:-}"; then
      "$PYTHON" "$PY/gpg.py" --profile "$PROFILE" --region "$REGION" --ssm-token "$SSM_TOKEN" --config "$SECRETS_CFG" --skip-missing
    else
      "$PYTHON" "$PY/gpg.py" --profile "$PROFILE" --region "$REGION" --ssm-token "$SSM_TOKEN" --config "$SECRETS_CFG" --dry-run
    fi
    ;;

  *)
    usage; exit 1 ;;
esac
