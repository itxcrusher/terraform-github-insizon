#!/usr/bin/env bash
# Shared helpers and constants for shell commands.

set -euo pipefail

# ---- Terraform plugin cache (speeds up init massively)
export TF_PLUGIN_CACHE_DIR="${TF_PLUGIN_CACHE_DIR:-$HOME/.terraform.d/plugin-cache}"
mkdir -p "$TF_PLUGIN_CACHE_DIR"

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

  # Backend config path
  local backend_cfg_posix="$TF_ROOT/backend/${env}.s3.tfbackend"
  if [[ ! -f "$backend_cfg_posix" ]]; then
    echo "Error: backend config not found: $backend_cfg_posix"
    exit 1
  fi

  # Read region for SDK + prep optional backend args
  local backend_region
  backend_region="$(awk -F= '/^region[[:space:]]*=/{gsub(/^[^=]*=[[:space:]]*/,""); gsub(/[[:space:]]*/,""); gsub(/^"|"$/,""); print; exit}' "$backend_cfg_posix" 2>/dev/null || true)"
  export AWS_SDK_LOAD_CONFIG=1
  [[ -n "$backend_region" ]] && export AWS_DEFAULT_REGION="$backend_region"

  # LOCAL ONLY: pass aws_profile from tfvars as backend arg (CI will not set this)
  local tfvars_profile=""
  local extra_backend_args=()
  if [[ -z "${CODEBUILD_BUILD_ID:-}" ]]; then
    tfvars_profile="$(
      awk -F= '/^aws_profile[[:space:]]*=/{gsub(/^[^=]*=[[:space:]]*/,""); gsub(/[[:space:]]*/,""); gsub(/^"|"$/,""); print; exit}' \
      "$TF_ROOT/env/${env}.tfvars" 2>/dev/null || true
    )"
    if [[ -n "$tfvars_profile" ]]; then
      extra_backend_args+=( -backend-config="profile=${tfvars_profile}" )
    fi
  fi

  # Windows path shim for terraform.exe under Git Bash
  local backend_cfg_arg="$backend_cfg_posix"
  if command -v cygpath >/dev/null 2>&1; then
    case "${OSTYPE:-}" in
      msys*|cygwin*) backend_cfg_arg="$(cygpath -w "$backend_cfg_posix")" ;;
    esac
  fi

  # Re-init only when backend file hash changes or init missing
  local hash_cmd="" current_hash="" stored_hash="" stored_hash_file="$TF_ROOT/.terraform/backend.sha256"
  if command -v sha256sum >/dev/null 2>&1; then
    hash_cmd="sha256sum"
  elif command -v shasum >/dev/null 2>&1; then
    hash_cmd="shasum -a 256"
  fi
  if [[ -n "$hash_cmd" ]]; then
    current_hash="$($hash_cmd "$backend_cfg_posix" | awk '{print $1}')"
    [[ -f "$stored_hash_file" ]] && stored_hash="$(awk '{print $1}' "$stored_hash_file")"
  fi

  if [[ -n "${FORCE_TF_INIT:-}" ]] || [[ -z "$hash_cmd" ]] || [[ "$current_hash" != "$stored_hash" ]] || [[ ! -d "$TF_ROOT/.terraform" ]]; then
    echo "Running 'terraform init -reconfigure' (backend changed or missing init)."
    terraform init -backend-config="$backend_cfg_arg" "${extra_backend_args[@]}" -reconfigure
    if [[ -n "$hash_cmd" ]]; then
      mkdir -p "$TF_ROOT/.terraform"
      echo "$current_hash  $(basename "$backend_cfg_posix")" > "$stored_hash_file"
    fi
  else
    echo "Skipping 'terraform init' — backend unchanged."
  fi
}

# Common pre-flight: format and validate
tf_format_validate() {
  cd "$TF_ROOT"
  terraform fmt -recursive
  terraform validate
}
