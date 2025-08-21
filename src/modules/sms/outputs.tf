output "sns_topic_arns" {
  value       = { for k, v in aws_sns_topic.topic : k => v.arn }
  description = "Created SNS topic ARNs."
}

output "pinpoint_application_id" {
  value       = try(aws_pinpoint_app.app[0].application_id, null)
  description = "Pinpoint app ID if enabled."
}
