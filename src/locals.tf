/** =============================================================================
 * Insizon Terraform — Locals and Shared Data Sources
 * -----------------------------------------------------------------------------
 * - Loads YAML config into `local.cfg`
 * - Centralizes common tags, account info, CI apply gating
 * - Implements "highestLevel" module gating per environment
 * =========================================================================== */

# Load config (YAML) into a Terraform-friendly map.
locals {
  # Path is relative to this module (src/)
  cfg = yamldecode(file("${path.module}/config/config.yaml"))
}

# Identify current AWS account (for tagging, ARNs, CodeBuild role policies, etc.)
data "aws_caller_identity" "current" {}

# Fetch GitHub token (PAT) from SSM SecureString specified in config
data "aws_ssm_parameter" "github_token" {
  name            = local.cfg.github.github_token_param
  with_decryption = true
}

# Core, reusable locals
locals {
  # AWS
  account_id = data.aws_caller_identity.current.account_id

  # Naming
  name_prefix  = local.cfg.codebuild.name_prefix
  project_name = "${local.name_prefix}-${var.app_environment}"

  # Credentials
  github_token = data.aws_ssm_parameter.github_token.value

  # Standardized tags across all resources
  tags = merge(
    {
      environment = var.app_environment
      owner       = local.cfg.github.owner
      managed_by  = "terraform"
      project     = try(local.cfg.aws.project, "terraform-github")
    },
    try(local.cfg.tags, {})
  )

  # CI apply gating (only envs listed in codebuild.apply_envs will auto-apply)
  apply_flag = contains(try(local.cfg.codebuild.apply_envs, []), var.app_environment)

  # -------------- Highest-Level Gating (feature flags per env) ----------------
  highest = try(local.cfg.highestLevel, {})
  env     = var.app_environment

  # `local.allow.<module>` → true if current env is listed under highestLevel.<module>
  allow = {
    glacier     = contains(try(local.highest["glacier"], []), local.env)
    sms         = contains(try(local.highest["sms"], []), local.env)
    rds         = contains(try(local.highest["rds"], []), local.env)
    kms         = contains(try(local.highest["kms"], []), local.env)
    temp_access = contains(try(local.highest["temp_access"], []), local.env)
  }
}
