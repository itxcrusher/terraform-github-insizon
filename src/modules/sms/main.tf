# Account-level SNS SMS preferences
resource "aws_sns_sms_preferences" "this" {
  count = length(var.preferences) == 0 ? 0 : 1

  default_sender_id                     = try(var.preferences.default_sender_id, null)
  monthly_spend_limit                   = try(var.preferences.monthly_spend_limit, null)
  default_sms_type                      = try(var.preferences.default_sms_type, null)
  delivery_status_iam_role_arn          = try(var.preferences.delivery_status_iam_role_arn, null)
  delivery_status_success_sampling_rate = try(var.preferences.delivery_status_success_sampling_rate, null)
  usage_report_s3_bucket                = try(var.preferences.usage_report_s3_bucket, null)
}

# Topics
resource "aws_sns_topic" "topic" {
  for_each     = { for t in var.topics : t.name => t }
  name         = each.value.name
  display_name = try(each.value.display_name, null)
  tags         = merge(var.tags, try(each.value.tags, {}))
}

resource "aws_sns_topic_policy" "topic_policy" {
  for_each = { for t in var.topics : t.name => t if try(t.policy_json, null) != null }
  arn      = aws_sns_topic.topic[each.key].arn
  policy   = each.value.policy_json
}

# Pinpoint (optional)
resource "aws_pinpoint_app" "app" {
  count = var.pinpoint.enable ? 1 : 0
  name  = try(var.pinpoint.application_name, "sms-app")
  tags  = var.tags
}

resource "aws_pinpoint_sms_channel" "channel" {
  count          = var.pinpoint.enable ? 1 : 0
  application_id = aws_pinpoint_app.app[0].application_id
  enabled        = true
}
