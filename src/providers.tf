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
  region  = var.aws_region
  profile = var.aws_profile
}

# GitHub Provider configuration
provider "github" {
  token = var.github_token
}
