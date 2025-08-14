terraform {
  required_version = ">= 1.3"

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
}

# AWS
provider "aws" {
  region = local.cfg.aws.region
  # profile = try(local.cfg.aws.profile, null)
}

# GitHub
provider "github" {
  owner = local.cfg.github.owner
  token = local.github_token
}
