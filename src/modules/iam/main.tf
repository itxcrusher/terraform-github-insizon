data "aws_iam_policy_document" "assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "AWS"
      identifiers = var.assume_principals
    }
  }
}

resource "aws_iam_role" "role" {
  for_each             = { for r in var.roles : r.name => r }
  name                 = each.value.name
  assume_role_policy   = data.aws_iam_policy_document.assume.json
  max_session_duration = each.value.max_session_seconds
  tags                 = var.tags
}

data "aws_iam_policy_document" "inline" {
  for_each = { for r in var.roles : r.name => r }

  dynamic "statement" {
    for_each = each.value.policy_statements
    content {
      actions   = statement.value.actions
      resources = statement.value.resources
    }
  }
}

resource "aws_iam_policy" "policy" {
  for_each = data.aws_iam_policy_document.inline
  name     = "policy-${each.key}"
  policy   = each.value.json
}

resource "aws_iam_role_policy_attachment" "attach" {
  for_each   = aws_iam_role.role
  role       = each.value.name
  policy_arn = aws_iam_policy.policy[each.key].arn
}
