#!/usr/bin/env bash
# Shared helpers and constants for shell commands.

set -euo pipefail

# Disable AWS CLI pager and auto-prompt so commands never block
export AWS_PAGER=""
export AWS_CLI_AUTO_PROMPT=off

# Resolve paths
SCRIPT_DIR="$(cd -- "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TF_ROOT="$REPO_ROOT/src"

# Validate environment input: dev | qa | prod
require_env() {
  local env="${1:-}"
  if [[ -z "$env" ]]; then
    echo "Error: environment is required (dev | qa | prod)"
    exit 1
  fi
  case "$env" in
    dev|qa|prod) ;;
    *) echo "Error: invalid environment '$env' (use dev | qa | prod)"; exit 1 ;;
  esac
}

# Initialize Terraform backend for a given environment.
tf_backend_init() {
  local env="$1"
  require_env "$env"

  # Ensure the remote backend infra exists before initializing Terraform.
  "$SCRIPT_DIR/ensure_backend.sh" "$env"

  cd "$TF_ROOT"

  # Build absolute POSIX path to the backend config
  local backend_cfg_posix="$TF_ROOT/backend/${env}.s3.tfbackend"
  if [[ ! -f "$backend_cfg_posix" ]]; then
    echo "Error: backend config not found: $backend_cfg_posix"
    exit 1
  fi

  # Convert to Windows path for terraform.exe when running under Git Bash on Windows
  local backend_cfg_arg="$backend_cfg_posix"
  if command -v cygpath >/dev/null 2>&1; then
    case "${OSTYPE:-}" in
      msys*|cygwin*)
        backend_cfg_arg="$(cygpath -w "$backend_cfg_posix")"
        ;;
    esac
  fi

  echo "Using backend config file: $backend_cfg_arg"

  rm -rf .terraform
  terraform init -backend-config="$backend_cfg_arg" -reconfigure
}

# Common pre-flight: format and validate
tf_format_validate() {
  cd "$TF_ROOT"
  terraform fmt -recursive
  terraform validate
}
