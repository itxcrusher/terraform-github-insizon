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

echo "Applying Terraform changes for environment '$ENVIRONMENT'..."
terraform apply -input=false -auto-approve
