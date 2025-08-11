variable "aws_region" {
  description = "AWS region for resource deployment"
  type        = string
}

variable "aws_profile" {
  description = "AWS named profile for authentication"
  type        = string
}

variable "github_token" {
  description = "GitHub personal access token for GitHub provider"
  type        = string
}
