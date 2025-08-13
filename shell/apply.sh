#!/usr/bin/env bash
# Run terraform apply for a given environment.
# Usage: bash apply.sh <dev|qa|prod>

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname "$0")" >/dev/null 2>&1 && pwd)"
# shellcheck source=common.sh
source "$SCRIPT_DIR/common.sh"

ENVIRONMENT="${1:-}"
require_env "$ENVIRONMENT"

tf_backend_init "$ENVIRONMENT"
tf_format_validate

VARS_FILE="$TF_ROOT/env/${ENVIRONMENT}.tfvars"
[[ -f "$VARS_FILE" ]] || { echo "Missing $VARS_FILE"; exit 1; }
echo "Applying Terraform changes for environment '$ENVIRONMENT'..."
terraform apply -var-file="$VARS_FILE" -auto-approve
