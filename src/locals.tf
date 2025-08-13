# Load config from YAML once
locals {
  cfg = yamldecode(file("${path.module}/config/config.yaml")) # file: src/config/config.yaml
}

# Caller identity
data "aws_caller_identity" "current" {}

# fetch PAT from SSM using key from config
data "aws_ssm_parameter" "github_token" {
  name            = local.cfg.github.github_token_param
  with_decryption = true
}

locals {
  account_id = data.aws_caller_identity.current.account_id

  # Codebuild name prefix & project
  name_prefix  = local.cfg.codebuild.name_prefix
  project_name = "${local.name_prefix}-${var.app_environment}"

  github_token = data.aws_ssm_parameter.github_token.value

  tags = merge(
    {
      environment = var.app_environment
      owner       = local.cfg.github.owner
      managed_by  = "terraform"
      project     = try(local.cfg.aws.project, "terraform-github")
    },
    try(local.cfg.tags, {})
  )

  # Apply gating
  apply_flag = contains(try(local.cfg.codebuild.apply_envs, []), var.app_environment)
}
