#!/usr/bin/env bash
# Ensures the Terraform S3 backend bucket and DynamoDB lock table exist.
# Reads settings from src/backend/<env>.s3.tfbackend
# Idempotent: safe to run repeatedly.

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname "$0")" >/dev/null 2>&1 && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TF_ROOT="$REPO_ROOT/src"

# Never let AWS CLI page output
export AWS_PAGER=""
export AWS_CLI_AUTO_PROMPT=off

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

# Parse a key from the tfbackend file (simple key = value format)
parse_tfbackend() {
  local file="$1"
  local key="$2"
  # Extract the value after key =, trim quotes and whitespace.
  awk -v k="^${key}[[:space:]]*=" '
    $0 ~ k {
      sub(/^[^=]*=[[:space:]]*/, "", $0)
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", $0)
      gsub(/^"/, "", $0); gsub(/"$/, "", $0)
      print $0
      exit
    }' "$file"
}

ensure_s3_bucket() {
  local bucket="$1"
  local region="$2"

  # Does the bucket exist?
  if aws s3api head-bucket --bucket "$bucket" 2>/dev/null; then
    echo "S3 bucket '$bucket' already exists."
  else
    echo "Creating S3 bucket '$bucket' in region '$region'..."
    if [[ "$region" == "us-east-2" ]]; then
      aws s3api create-bucket --bucket "$bucket" --region "$region"
    else
      aws s3api create-bucket --bucket "$bucket" --region "$region" \
        --create-bucket-configuration LocationConstraint="$region"
    fi

    echo "Blocking public access on bucket '$bucket'..."
    aws s3api put-public-access-block \
      --bucket "$bucket" \
      --public-access-block-configuration \
      BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true

    echo "Enabling versioning on bucket '$bucket'..."
    aws s3api put-bucket-versioning \
      --bucket "$bucket" \
      --versioning-configuration Status=Enabled

    echo "Enabling default encryption (AES256) on bucket '$bucket'..."
    aws s3api put-bucket-encryption \
      --bucket "$bucket" \
      --server-side-encryption-configuration \
      '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"}}]}'
  fi
}

ensure_dynamodb_table() {
  local table="$1"
  local region="$2"

  if aws dynamodb describe-table --table-name "$table" --region "$region" >/dev/null 2>&1; then
    echo "DynamoDB table '$table' already exists."
  else
    echo "Creating DynamoDB table '$table' in region '$region'..."
    aws dynamodb create-table \
      --table-name "$table" \
      --attribute-definitions AttributeName=LockID,AttributeType=S \
      --key-schema AttributeName=LockID,KeyType=HASH \
      --billing-mode PAY_PER_REQUEST \
      --region "$region"

    echo "Waiting for DynamoDB table '$table' to become ACTIVE..."
    aws dynamodb wait table-exists --table-name "$table" --region "$region"
  fi
}

main() {
  local env="${1:-}"
  require_env "$env"

  local tfb_file="$TF_ROOT/backend/${env}.s3.tfbackend"
  if [[ ! -f "$tfb_file" ]]; then
    echo "Error: backend config file not found: $tfb_file"
    exit 1
  fi

  # Read backend settings
  local bucket region ddb_table profile
  bucket="$(parse_tfbackend "$tfb_file" "bucket")"
  region="$(parse_tfbackend "$tfb_file" "region")"
  ddb_table="$(parse_tfbackend "$tfb_file" "dynamodb_table")"
  profile="$(parse_tfbackend "$tfb_file" "profile")"

  if [[ -z "$bucket" || -z "$region" ]]; then
    echo "Error: 'bucket' and 'region' must be defined in $tfb_file"
    exit 1
  fi

  # Honor profile in tfbackend if set, but do not override an explicitly provided AWS_PROFILE.
  if [[ -n "${profile:-}" && -z "${AWS_PROFILE:-}" ]]; then
    export AWS_PROFILE="$profile"
  fi

  # Ensure required tools
  if ! command -v aws >/dev/null 2>&1; then
    echo "Error: aws CLI not found in PATH."
    exit 1
  fi

  # Ensure resources
  ensure_s3_bucket "$bucket" "$region"
  if [[ -n "$ddb_table" ]]; then
    ensure_dynamodb_table "$ddb_table" "$region"
  fi

  echo "Backend prerequisites verified for environment '$env'."
}

main "$@"
