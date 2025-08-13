# src/locals.tf
# This file defines local variables used in the Terraform configuration.

data "aws_caller_identity" "current" {}

# SSM fetch when no token provided
data "aws_ssm_parameter" "github_token" {
  count = var.github_token == "" ? 1 : 0
  name  = "insizon-github-token"
  with_decryption  = true
}

locals {
  account_id             = data.aws_caller_identity.current.account_id
  name_prefix            = "tf-github"
  project_name           = "${local.name_prefix}-${var.app_environment}"
  effective_github_token = var.github_token != "" ? var.github_token : try(data.aws_ssm_parameter.github_token[0].value, "")
  tags = {
    owner       = var.github_owner,
    managed_by  = "terraform",
    environment = var.app_environment,
    project     = "terraform-github"
  }
  codebuild_envs = {
    dev  = true
    qa   = false
    prod = true
  }
}
