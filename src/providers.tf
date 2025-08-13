terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    github = {
      source  = "integrations/github"
      version = "~> 6.0"
    }
  }

  required_version = ">= 1.3"
}

# AWS Provider configuration
provider "aws" {
  region = var.aws_region
  # Use local named profile if provided; otherwise rely on the CodeBuild role
  profile = length(var.aws_profile) > 0 ? var.aws_profile : null
}

# GitHub Provider configuration
provider "github" {
  owner = var.github_owner
  token = local.effective_github_token
}
