#!/usr/bin/env bash
# Format Terraform code in the repository.

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname "$0")" >/dev/null 2>&1 && pwd)"
# shellcheck source=common.sh
source "$SCRIPT_DIR/common.sh"

cd "$TF_ROOT"
terraform fmt -recursive
echo "Formatting complete."
