#!/usr/bin/env bash
# Initialize Terraform backend for the specified environment.
# Usage: bash backend_init.sh <dev|qa|prod>

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname "$0")" >/dev/null 2>&1 && pwd)"
# shellcheck source=common.sh
source "$SCRIPT_DIR/common.sh"

ENVIRONMENT="${1:-}"
require_env "$ENVIRONMENT"

tf_backend_init "$ENVIRONMENT"
echo "Backend initialized for environment: $ENVIRONMENT"
