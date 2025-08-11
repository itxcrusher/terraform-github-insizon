#!/usr/bin/env bash
# Print a terraform output for a given environment.
# Usage: bash output.sh <dev|qa|prod> [output_name]
# If output_name is omitted, prints all outputs (non-raw).

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname "$0")" >/dev/null 2>&1 && pwd)"
# shellcheck source=common.sh
source "$SCRIPT_DIR/common.sh"

ENVIRONMENT="${1:-}"
OUTPUT_NAME="${2:-}"

require_env "$ENVIRONMENT"

tf_backend_init "$ENVIRONMENT"

cd "$TF_ROOT"
if [[ -z "$OUTPUT_NAME" ]]; then
  terraform output
else
  terraform output -raw "$OUTPUT_NAME"
fi
