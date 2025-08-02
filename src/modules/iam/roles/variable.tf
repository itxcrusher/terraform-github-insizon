




# users_from_yaml_map = { jane = [ "readonly", "auditor" ], lauro = [ "readonly"] }
variable "iamRoles_object" {
  type = object({
    users_from_yaml_map = any
    aws_iam_user        = any
  })
}