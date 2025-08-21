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

# Validate environment input: dev | qa | prod, export TF_VAR_app_environment and AWS_PROFILE (local)
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

  # Make env available to Terraform (no tfvars needed)
  export TF_VAR_app_environment="$env"

  # LOCAL ONLY: export AWS_PROFILE from YAML so all downstream scripts inherit it
  if [[ -z "${CODEBUILD_BUILD_ID:-}" ]]; then
    if [[ -z "${AWS_PROFILE:-}" ]]; then
      local profile
      if profile="$(yaml_get_aws_profile)"; then
        if [[ -n "$profile" ]]; then
          export AWS_PROFILE="$profile"
          echo "Using AWS profile from config.yaml: $AWS_PROFILE"
        else
          echo "WARNING: aws.profile not found in src/config/config.yaml; using default AWS credentials." >&2
        fi
      else
        echo "WARNING: src/config/config.yaml not found; using default AWS credentials." >&2
      fi
    fi
  fi
}

# Read aws.profile from src/config/config.yaml (handles BOM + CRLF, top-level scoping)
yaml_get_aws_profile() {
  local cfg="$TF_ROOT/config/config.yaml"
  [[ -f "$cfg" ]] || return 1
  # strip BOM, strip CR, then awk within top-level 'aws:' block only
  sed '1s/^\xEF\xBB\xBF//' "$cfg" | tr -d '\r' | awk '
    /^[[:space:]]*aws:[[:space:]]*$/ { inaws=1; next }
    inaws && /^[^[:space:]]/ { inaws=0 }                 # left margin = new top-level key
    inaws && /^[[:space:]]*profile:[[:space:]]*/ {
      sub(/^[^:]*:[ \t]*/, "", $0)
      gsub(/^[ \t]+|[ \t]+$/, "", $0)
      print; exit
    }
  '
}

# Initialize Terraform backend for a given environment (no tfvars)
tf_backend_init() {
  local env="$1"

  "$SCRIPT_DIR/ensure_backend.sh" "$env"
  cd "$TF_ROOT"

  local backend_cfg_posix="$TF_ROOT/backend/${env}.s3.tfbackend"
  if [[ ! -f "$backend_cfg_posix" ]]; then
    echo "Error: backend config not found: $backend_cfg_posix"
    exit 1
  fi

  # Ensure region for AWS CLI/SDK
  local backend_region
  backend_region="$(awk -F= '/^region[[:space:]]*=/{gsub(/^[^=]*=[[:space:]]*/, ""); gsub(/[[:space:]]*/, ""); gsub(/^"|"$/, ""); print; exit}' "$backend_cfg_posix" 2>/dev/null || true)"
  export AWS_SDK_LOAD_CONFIG=1
  [[ -n "$backend_region" ]] && export AWS_DEFAULT_REGION="$backend_region"

  # Determine whether we must re-init
  local need_init="false"

  # 1) If .terraform is missing, we must init
  [[ ! -d ".terraform" ]] && need_init="true"

  # 2) If modules metadata is missing, we must init (modules.json is created by `terraform init`)
  [[ ! -f ".terraform/modules/modules.json" ]] && need_init="true"

  # 3) If backend config hash changed, we must reconfigure
  local hash_cmd="" current_backend_hash="" stored_backend_hash="" stored_backend_file="$TF_ROOT/.terraform/backend.sha256"
  if command -v sha256sum >/dev/null 2>&1; then
    hash_cmd="sha256sum"
  elif command -v shasum >/dev/null 2>&1; then
    hash_cmd="shasum -a 256"
  fi
  if [[ -n "$hash_cmd" ]]; then
    current_backend_hash="$($hash_cmd "$backend_cfg_posix" | awk '{print $1}')"
    [[ -f "$stored_backend_file" ]] && stored_backend_hash="$(awk '{print $1}' "$stored_backend_file")"
    [[ "$current_backend_hash" != "$stored_backend_hash" ]] && need_init="true"
  fi

  # 4) If Terraform root/module files changed, re-init to refresh modules & providers
  #    We hash all *.tf in src/ and module subdirs (cheap & reliable)
  local modules_hash_file="$TF_ROOT/.terraform/modules.sha256"
  local current_modules_hash=""
  if [[ -n "$hash_cmd" ]]; then
    # Guard against huge paths: find . -type f -name '*.tf' under src root
    # Use sort -z to get stable order and xargs -0 to feed to the hasher
    if command -v find >/dev/null 2>&1; then
      # shellcheck disable=SC2016
      current_modules_hash="$(
        find "$TF_ROOT" -type f -name '*.tf' -print0 \
        | sort -z \
        | xargs -0 $hash_cmd 2>/dev/null \
        | $hash_cmd | awk '{print $1}'
      )"
      local stored_modules_hash=""
      [[ -f "$modules_hash_file" ]] && stored_modules_hash="$(awk '{print $1}' "$modules_hash_file")"
      [[ "$current_modules_hash" != "$stored_modules_hash" ]] && need_init="true"
    fi
  fi

  # 5) Manual override
  [[ -n "${FORCE_TF_INIT:-}" ]] && need_init="true"

  if [[ "$need_init" == "true" ]]; then
    echo "Running 'terraform init -reconfigure'."
    terraform init -backend-config="$backend_cfg_posix" -reconfigure

    # Persist hashes for future runs
    if [[ -n "$hash_cmd" ]]; then
      mkdir -p "$TF_ROOT/.terraform"
      [[ -n "$current_backend_hash" ]] && echo "$current_backend_hash  $(basename "$backend_cfg_posix")" > "$stored_backend_file"
      [[ -n "$current_modules_hash" ]] && echo "$current_modules_hash  modules" > "$modules_hash_file"
    fi
  else
    echo "Skipping 'terraform init' — backend & modules unchanged."
  fi
}

# Common pre-flight: format and validate
tf_format_validate() {
  cd "$TF_ROOT"
  terraform fmt -recursive
  terraform validate
}
