

# Trust for CodeBuild
data "aws_iam_policy_document" "assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["codebuild.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "role" {
  name               = "${var.project_name}-role"
  assume_role_policy = data.aws_iam_policy_document.assume.json
  tags               = var.tags
}

# Inline policy: logs, S3 backend, Dynamo lock, SSM params, KMS decrypt
data "aws_iam_policy_document" "inline" {
  statement {
    sid       = "Logs"
    actions   = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents", "logs:DescribeLogStreams"]
    resources = ["*"]
  }

  statement {
    sid     = "S3Backend"
    actions = ["s3:GetObject", "s3:GetObjectVersion", "s3:PutObject", "s3:ListBucket", "s3:GetBucketLocation"]
    resources = [
      "arn:aws:s3:::${var.backend_bucket}",
      "arn:aws:s3:::${var.backend_bucket}/*",
    ]
  }

  # Access for CodeBuild S3 cache bucket
  statement {
    sid = "S3Cache"
    actions = [
      "s3:ListBucket",
      "s3:GetBucketAcl",
      "s3:GetBucketCors",
      "s3:GetBucketLocation",
      "s3:GetBucketPolicy",
      "s3:GetBucketPolicyStatus",
      "s3:GetBucketVersioning",
      "s3:GetBucketWebsite",
      "s3:GetBucketTagging",
      "s3:GetBucketLogging",
      "s3:GetBucketOwnershipControls",
      "s3:GetEncryptionConfiguration",
      "s3:GetLifecycleConfiguration",
      "s3:GetBucketPublicAccessBlock"
    ]
    resources = [
      aws_s3_bucket.cb_cache.arn
    ]
  }

  statement {
    sid     = "S3CacheObjects"
    actions = ["s3:GetObject", "s3:PutObject", "s3:GetObjectVersion", "s3:DeleteObject"]
    resources = [
      "${aws_s3_bucket.cb_cache.arn}/*"
    ]
  }

  statement {
    sid       = "DynamoLock"
    actions   = ["dynamodb:GetItem", "dynamodb:PutItem", "dynamodb:DeleteItem", "dynamodb:DescribeTable"]
    resources = ["arn:aws:dynamodb:${var.region}:${var.account_id}:table/${var.backend_lock_table_name}"]
  }

  statement {
    sid       = "SSMParams"
    actions   = ["ssm:GetParameter", "ssm:GetParameters", "ssm:GetParametersByPath"]
    resources = ["arn:aws:ssm:${var.region}:${var.account_id}:parameter/${var.github_token_param}"]
  }

  # If the SSM parameter is SecureString, allow decrypt otherwise delete the KMS statement entirely.
  # Using * simplifies AWS-managed key resolution.
  statement {
    sid       = "KmsDecryptForSSM"
    actions   = ["kms:Decrypt"]
    resources = ["*"]
  }

  # Allow reading/updating the CodeBuild role itself (this module's role)
  statement {
    sid = "IamRoleSelfManage"
    actions = [
      "iam:GetRole",
      "iam:UpdateAssumeRolePolicy",
      "iam:PutRolePolicy",
      "iam:DeleteRolePolicy",
      "iam:AttachRolePolicy",
      "iam:DetachRolePolicy",
      "iam:ListRolePolicies",
      "iam:ListAttachedRolePolicies",
      "iam:PassRole",
      "iam:UpdateRole"
    ]
    resources = [
      "arn:aws:iam::${var.account_id}:role/${var.project_name}-role"
    ]
  }

  # Allow managing the inline/customer-managed policy this module creates/attaches
  statement {
    sid = "IamPolicyManage"
    actions = [
      "iam:GetPolicy",
      "iam:GetPolicyVersion",
      "iam:CreatePolicy",
      "iam:CreatePolicyVersion",
      "iam:DeletePolicyVersion",
      "iam:DeletePolicy",
      "iam:ListPolicyVersions"
    ]
    # match the policy created by this module (or any with our name_prefix if you prefer)
    resources = [
      "arn:aws:iam::${var.account_id}:policy/${var.project_name}-policy",
      "arn:aws:iam::${var.account_id}:policy/${var.name_prefix}*"
    ]
  }

  # Allow CodeBuild project reads/updates used by the provider
  statement {
    sid = "CodeBuildProjectManage"
    actions = [
      "codebuild:BatchGetProjects",
      "codebuild:CreateProject",
      "codebuild:UpdateProject",
      "codebuild:DeleteProject"
    ]
    resources = [
      "arn:aws:codebuild:${var.region}:${var.account_id}:project/${var.project_name}"
    ]
  }

  # Source credentials management (PAT linkage)
  statement {
    sid = "CodeBuildSourceCreds"
    actions = [
      "codebuild:ImportSourceCredentials",
      "codebuild:ListSourceCredentials",
      "codebuild:DeleteSourceCredentials"
    ]
    resources = ["*"]
  }

  # The provider tries to read bucket policy on the cache bucket
  statement {
    sid = "S3CacheBucketPolicyRead"
    actions = [
      "s3:GetBucketPolicy",
      "s3:PutBucketPolicy"
    ]
    resources = [
      "arn:aws:s3:::${var.project_name}-cache-${var.account_id}-${var.region}"
    ]
  }

  # Terraform often needs to introspect caller identity
  statement {
    sid       = "STSMisc"
    actions   = ["sts:GetCallerIdentity"]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "policy" {
  name   = "${var.project_name}-policy"
  policy = data.aws_iam_policy_document.inline.json
  tags   = var.tags
}

resource "aws_iam_role_policy_attachment" "attach" {
  role       = aws_iam_role.role.name
  policy_arn = aws_iam_policy.policy.arn
}

resource "aws_s3_bucket" "cb_cache" {
  bucket        = "${var.project_name}-cache-${var.account_id}-${var.region}"
  force_destroy = true
  tags          = var.tags
}

# Register credential so CodeBuild can authenticate to GitHub
resource "aws_codebuild_source_credential" "github_pat" {
  auth_type   = "PERSONAL_ACCESS_TOKEN"
  server_type = "GITHUB"
  token       = var.github_token
}

resource "aws_codebuild_project" "project" {
  name         = var.project_name
  description  = "Terraform build for ${var.env}"
  service_role = aws_iam_role.role.arn
  tags         = var.tags

  artifacts { type = "NO_ARTIFACTS" }

  environment {
    compute_type    = var.compute_type
    image           = var.image
    type            = "LINUX_CONTAINER"
    privileged_mode = false

    # Let buildspec know which env it is, and whether to apply
    environment_variable {
      name  = "ENV"
      value = var.env
    }
    environment_variable {
      name  = "APPLY"
      value = var.apply ? "true" : "false"
    }
  }

  # No connected GitHub source — connect via console
  source {
    type                = "GITHUB"
    location            = var.repo_url
    git_clone_depth     = 1
    buildspec           = var.buildspec_path
    report_build_status = true

    # Uses the PAT registered by aws_codebuild_source_credential
    auth {
      resource = aws_codebuild_source_credential.github_pat.arn
      type     = "OAUTH"
    }
  }

  logs_config {
    cloudwatch_logs {
      group_name  = "/codebuild/${var.project_name}"
      stream_name = "build"
    }
  }
  cache {
    type     = "S3"
    location = aws_s3_bucket.cb_cache.bucket
  }
}

resource "aws_codebuild_webhook" "this" {
  project_name = aws_codebuild_project.project.name
  build_type   = "BUILD"

  filter_group {
    filter {
      type    = "EVENT"
      pattern = "PUSH"
    }
    filter {
      type    = "HEAD_REF"
      pattern = "refs/heads/${var.github_branch}" # for multi branch strategy select the branch according to environment (var.env)
    }
  }
}
