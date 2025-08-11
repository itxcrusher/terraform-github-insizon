#!/usr/bin/env bash
# Run terraform plan for a given environment.
# Usage: bash plan.sh <dev|qa|prod>

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname "$0")" >/dev/null 2>&1 && pwd)"
# shellcheck source=common.sh
source "$SCRIPT_DIR/common.sh"

ENVIRONMENT="${1:-}"
require_env "$ENVIRONMENT"

tf_backend_init "$ENVIRONMENT"
tf_format_validate

cd "$TF_ROOT"
terraform plan -var-file="./env/${ENVIRONMENT}.tfvars"
