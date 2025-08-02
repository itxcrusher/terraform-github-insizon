# Providers 
# providers.ts is the file where you list and configure your providers to be use. Ex Aws, Azure, Gcp
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs
terraform {
  required_providers {
    github = {
      source  = "integrations/github"
      version = "~> 6.0"
    }
  }

  required_version = ">= 0.13"
}

# Configure the GitHub Provider
provider "github" {}

# Add a user to the organization
# resource "github_membership" "membership_for_user_x" {
  
# }