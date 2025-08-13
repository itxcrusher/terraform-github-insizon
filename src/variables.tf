variable "app_environment" {
  description = "Application environment (dev|qa|prod)"
  type        = string
  validation {
    condition     = contains(["dev", "qa", "prod"], var.app_environment)
    error_message = "app_environment must be one of: dev, qa, prod."
  }
}
