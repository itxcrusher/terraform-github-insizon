





variable "users_object" {
  type = object({
    UserName = string
  })
}


# Define the list of policy ARNs to attach
variable "policy_arns" {
  description = "List of IAM policy ARNs to attach to the user"
  type        = list(string)
  default = [
    "arn:aws:iam::aws:policy/AmazonS3FullAccess",
    "arn:aws:iam::aws:policy/AmazonEC2FullAccess"
  ]
}