



locals {
  # Filter by Type -> You will see all the policy names listed here
  # https://us-east-1.console.aws.amazon.com/iam/home?region=us-east-2#/policies
  role_policies = {
    readonly = [
      "ReadOnlyAccess"
    ]
    admin = [
      "AdministratorAccess"
    ]
    auditor = [
      "SecurityAudit"
    ]
    developer = [
      "AmazonS3ReadOnlyAccess",
      "AmazonRDSFullAccess",
      "AmazonDynamoDBFullAccess",
      "AmazonSESFullAccess"
    ]
    backend_app = [
      "CloudFrontFullAccess",
      "AmazonGlacierFullAccess",
      "AmazonS3FullAccess",
      "AmazonGlacierFullAccess",
      "AmazonSESFullAccess",
      "AmazonSNSFullAccess"
    ]
  }

  # Convert role_policies list to list of objects
  # { policy = "AmazonS3ReadOnlyAccess", role = "developer"}, 
  # { policy = "AmazonRDSFullAccess", role = "developer"}
  role_policies_list = flatten([
    for role, polices in local.role_policies : [
      for policy in polices : {
        role   = role
        policy = policy
      }
    ]
  ])
}


# Get AWS accountId of the user currently running terraform
data "aws_caller_identity" "current" {}

# We must iterate over the existing roles and create a different assumg role policy for each of them
# In each role policy, add under identifies add only the users that have that specific listed in their role list
data "aws_iam_policy_document" "assume_role_policy" {
  for_each = toset(keys(local.role_policies))
  statement {
    # Can assume role
    actions = ["sts:AssumeRole"]

    principals {
      type = "AWS"
      # Who can assume roles
      # Account -
      # Role - admin, developer, readonly, etc
      identifiers = [
        for username in keys(var.iamRoles_object.aws_iam_user) : "arn:aws:iam::${data.aws_caller_identity.current.account_id}:user/${username}"
        if contains(var.iamRoles_object.users_from_yaml_map[username], each.value)
      ]
    }
  }
}


# Assign role to user
resource "aws_iam_role" "roles" {
  for_each = toset(keys(local.role_policies))

  name               = each.key
  assume_role_policy = data.aws_iam_policy_document.assume_role_policy[each.value].json
}

# Get each Aws policy action
data "aws_iam_policy" "managed_policies" {
  for_each = toset(local.role_policies_list[*].policy)
  arn      = "arn:aws:iam::aws:policy/${each.value}"
}


# Finally step connect policies to roles
# Attach policies to role
resource "aws_iam_role_policy_attachment" "role_policy_attachment" {
  count      = length(local.role_policies_list)
  role       = aws_iam_role.roles[local.role_policies_list[count.index].role].name
  policy_arn = data.aws_iam_policy.managed_policies[local.role_policies_list[count.index].policy].arn
}