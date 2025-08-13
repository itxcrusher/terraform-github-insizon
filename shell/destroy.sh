#!/usr/bin/env bash
# Destroy terraform resources for a given environment.
# Usage: bash destroy.sh <dev|qa|prod>
# A confirmation prompt is included to avoid accidental destruction.

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname "$0")" >/dev/null 2>&1 && pwd)"
# shellcheck source=common.sh
source "$SCRIPT_DIR/common.sh"

ENVIRONMENT="${1:-}"
require_env "$ENVIRONMENT"

read -r -p "Confirm destroy for environment '$ENVIRONMENT' (type 'destroy'): " CONFIRM
if [[ "$CONFIRM" != "destroy" ]]; then
  echo "Aborted."
  exit 1
fi

tf_backend_init "$ENVIRONMENT"
tf_format_validate

cd "$TF_ROOT"
terraform destroy -input=false -auto-approve
