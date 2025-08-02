# variables.tf where you place all variables
# https://mrfreelancer9.medium.com/integrate-aws-s3-with-your-node-js-project-a-step-by-step-guide-f7f160ea8d29
# https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/cloudfront-limits.html



variable "app-names-list" {
  type = list(string)
  default = [
    "insizon-dev-keygroup1",
  ]
}

variable "app-environment" {
  type = string
}

variable "app_object" {
  type = object({
    ObjectId = string
    TenantId = string
  })
  default = {
    ObjectId = ""
    TenantId = ""
  }
}

variable "app-users" {
  type    = list(string)
  default = ["lscott-user", "tsmith-user", "insizon-app"]
}