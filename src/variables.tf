variable "app_environment" {
  description = "Application environment (e.g., prod, qa)"
  type        = string
}

variable "aws_region" {
  description = "AWS region for resource deployment"
  type        = string
}

variable "aws_profile" {
  description = "AWS named profile for authentication"
  type        = string
  default     = ""
}

variable "github_owner" {
  description = "GitHub org or username"
  type        = string
}

variable "github_token" {
  description = "GitHub personal access token for GitHub provider"
  type        = string
  default     = ""
}
