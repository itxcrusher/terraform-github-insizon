#!/usr/bin/env bash
# Ensures the Terraform S3 backend bucket and DynamoDB lock table exist.
# Reads settings from: src/backend/<env>.s3.tfbackend
# Idempotent: safe to run repeatedly. CI-safe (no profile required).

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname "$0")" >/dev/null 2>&1 && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TF_ROOT="$REPO_ROOT/src"

export AWS_PAGER=""
export AWS_CLI_AUTO_PROMPT=off

require_env() {
  local env="${1:-}"; [[ -n "$env" ]] || { echo "Error: env required (dev|qa|prod)"; exit 1; }
  case "$env" in dev|qa|prod) ;; *) echo "Error: invalid env '$env'"; exit 1 ;; esac
}

# Parse "key = value" lines in *.tfbackend
parse_tfbackend() {
  local file="$1" key="$2"
  awk -v k="^${key}[[:space:]]*=" '
    $0 ~ k {
      sub(/^[^=]*=[[:space:]]*/, "", $0)
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", $0)
      gsub(/^"/, "", $0); gsub(/"$/, "", $0)
      print $0; exit
    }' "$file"
}

ensure_s3_bucket() {
  local bucket="$1" region="$2"
  local msg rc

  set +e
  msg="$(aws s3api head-bucket --bucket "$bucket" 2>&1)"
  rc=$?
  set -e

  if [[ $rc -eq 0 ]]; then
    echo "S3 bucket '$bucket' already exists and is accessible."
    return 0
  fi

  if echo "$msg" | grep -qiE 'PermanentRedirect|AuthorizationHeaderMalformed|301'; then
    echo "Bucket '$bucket' exists (different region). Skipping creation."
    return 2   # signal: access/location problem
  fi

  if echo "$msg" | grep -qiE '403|AccessDenied'; then
    echo "Bucket '$bucket' exists but is not accessible with current credentials (403)."
    echo "Not creating; verify permissions/profile if you expect access."
    return 2   # signal: access problem
  fi

  if echo "$msg" | grep -qiE '404|Not ?Found|NoSuchBucket'; then
    echo "Bucket '$bucket' not found. Creating in region '$region'..."
    if [[ "$region" == "us-east-1" ]]; then
      aws s3api create-bucket --bucket "$bucket" --region "$region"
    else
      aws s3api create-bucket --bucket "$bucket" --region "$region" \
        --create-bucket-configuration LocationConstraint="$region"
    fi
    echo "Blocking public access on '$bucket'..."
    aws s3api put-public-access-block --bucket "$bucket" \
      --public-access-block-configuration BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true
    echo "Enabling versioning on '$bucket'..."
    aws s3api put-bucket-versioning --bucket "$bucket" --versioning-configuration Status=Enabled
    echo "Enabling default encryption (AES256) on '$bucket'..."
    aws s3api put-bucket-encryption --bucket "$bucket" \
      --server-side-encryption-configuration '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"}}]}'
    return 0
  fi

  echo "head-bucket failed for '$bucket':"
  echo "$msg"
  return 2
}


ensure_dynamodb_table() {
  local table="$1" region="$2"
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
  local env="${1:-}"; require_env "$env"

  local tfb_file="$TF_ROOT/backend/${env}.s3.tfbackend"
  [[ -f "$tfb_file" ]] || { echo "Error: backend config not found: $tfb_file"; exit 1; }

  local bucket region ddb_table
  bucket="$(parse_tfbackend "$tfb_file" "bucket")"
  region="$(parse_tfbackend "$tfb_file" "region")"
  ddb_table="$(parse_tfbackend "$tfb_file" "dynamodb_table")"

  [[ -n "$bucket" && -n "$region" ]] || { echo "Error: bucket/region must be defined."; exit 1; }

  # Make the AWS SDK/CLI read shared config and use the correct region
  export AWS_SDK_LOAD_CONFIG=1
  export AWS_DEFAULT_REGION="$region"

  # LOCAL ONLY: set AWS_PROFILE from config.yaml if not set and not in CodeBuild
  if [[ -z "${CODEBUILD_BUILD_ID:-}" && -z "${AWS_PROFILE:-}" ]]; then
    local cfg="$TF_ROOT/config/config.yaml"
    if [[ -f "$cfg" ]]; then
      local profile
      profile="$(awk '
        $1 ~ /^aws:/ { inaws=1; next }
        inaws && $1 ~ /^profile:/ {
          gsub(/profile:[[:space:]]*/, "", $0)
          gsub(/^[[:space:]]+|[[:space:]]+$/, "", $0)
          print $0; exit
        }
        inaws && $1 ~ /^[^[:space:]]/ { inaws=0 }
      ' "$cfg")"
      if [[ -n "$profile" ]]; then
        export AWS_PROFILE="$profile"
      fi
    fi
  fi

  command -v aws >/dev/null 2>&1 || { echo "Error: aws CLI not found."; exit 1; }

  # Ensure S3 bucket; skip DDB if S3 access looks wrong to avoid cross-account creates
  ensure_s3_bucket "$bucket" "$region"
  case $? in
    0)
      # S3 is accessible/created -> proceed to DDB
      if [[ -n "$ddb_table" ]]; then
        ensure_dynamodb_table "$ddb_table" "$region"
      fi
      echo "Backend prerequisites verified for env '$env'."
      ;;
    2)
      # Access/region problem -> do NOT touch DDB, exit clearly
      echo "Skipping DynamoDB ensure because S3 access is not confirmed for the current credentials."
      echo "Tip: run 'aws sts get-caller-identity' and confirm your aws_profile/role & account."
      exit 1
      ;;
    *)
      exit 1
      ;;
  esac
}

main "$@"
