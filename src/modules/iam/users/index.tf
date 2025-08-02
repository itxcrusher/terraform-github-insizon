


# users_from_yaml - Read users yaml file

# Resource to create all Aws users listed in user-roles.yaml file
# for_each - Get all users
# Output
# + arn           = (known after apply)
# + force_destroy = false
# + id            = (known after apply)
# + name          = "lauro"
# + path          = "/"
# + tags_all      = (known after apply)
# + unique_id     = (known after apply)
resource "aws_iam_user" "main" {
  name = var.users_object.UserName
}


# Resource to assign a password to newly create Aws users
# Needed in order for users to login for the first time
# Note - Read the password from the aws-state-.tfstate file for each user
# Use the vscode built in aws extension in view in s3 bucket
# Output
# + encrypted_password      = (known after apply)
# + id                      = (known after apply)
# + key_fingerprint         = (known after apply)
# + password                = (sensitive value)
# + password_length         = 8
# + password_reset_required = true
# + user                    = "lauro"
resource "aws_iam_user_login_profile" "main" {
  user = aws_iam_user.main.name

  # Min length of password
  password_length         = 20
  password_reset_required = false

  # Will only effect new users not existing after creating users
  lifecycle {
    ignore_changes = [
      password_length,
      password_reset_required,
      pgp_key
    ]
  }
}


# Resource to set When the password will expire
# max_password_age - int 30d, 365
# allow_users_to_change_password - (Optional) Whether to allow users to change their own password
# hard_expiry - (Optional) Whether users are prevented from setting a new password after their password has expired (i.e., require administrator reset)
# max_password_age - (Optional) The number of days that an user password is valid.
# minimum_password_length - (Optional) Minimum length to require for user passwords.
# password_reuse_prevention - (Optional) The number of previous passwords that users are prevented from reusing.
# require_lowercase_characters - (Optional) Whether to require lowercase characters for user passwords.
# require_numbers - (Optional) Whether to require numbers for user passwords.
# require_symbols - (Optional) Whether to require symbols for user passwords.
# require_uppercase_characters - (Optional) Whether to require uppercase characters for user passwords.
resource "aws_iam_account_password_policy" "main" {
  max_password_age               = 365
  allow_users_to_change_password = true
  hard_expiry                    = true
  minimum_password_length        = 12
  password_reuse_prevention      = 20
  require_lowercase_characters   = true
  require_uppercase_characters   = true
  require_numbers                = true
  require_symbols                = true
}


###################################################
# Create access key ID and secret key 
resource "aws_iam_access_key" "main" {
  user = aws_iam_user.main.name
}

locals {
  Aws_AccessKeys_to_csv = "access_key,secret_key,login_password\n${aws_iam_access_key.main.id},${aws_iam_access_key.main.secret},${aws_iam_user_login_profile.main.password}"
}

#https://achinthabandaranaike.medium.com/how-to-deploy-aws-iam-users-user-groups-policies-and-roles-using-terraform-7dd853404dc0
resource "local_file" "user_account_keys" {
  content  = local.Aws_AccessKeys_to_csv
  filename = "${path.module}/../../../../private/iam_access_keys/${var.users_object.UserName}-keys.csv"
}


##########################################
# Resource to create User Group
resource "aws_iam_group" "main" {
  name = "${aws_iam_user.main.name}-developers"
}

resource "aws_iam_group_membership" "achintha_membership" {
  name  = aws_iam_user.main.name
  users = [aws_iam_user.main.name]
  group = aws_iam_group.main.name
}

#############################################
# Attach each policy to the IAM user
resource "aws_iam_group_policy_attachment" "policy-s3" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
  group      = aws_iam_group.main.name
}

resource "aws_iam_group_policy_attachment" "policy-dynamodb" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonDynamoDBFullAccess"
  group      = aws_iam_group.main.name
}

resource "aws_iam_group_policy_attachment" "policy-cloudfront" {
  policy_arn = "arn:aws:iam::aws:policy/CloudFrontFullAccess"
  group      = aws_iam_group.main.name
}

resource "aws_iam_group_policy_attachment" "policy-ses" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonSESFullAccess"
  group      = aws_iam_group.main.name
}

resource "aws_iam_group_policy_attachment" "policy-sns" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonSNSFullAccess"
  group      = aws_iam_group.main.name
}


# module "Role_module" {
#   source = "../roles"

#   iamRoles_object = {
#     Users_from_yaml_map = local.users_from_yaml_map
#     aws_iam_user      = aws_iam_user.main
#   }
# }