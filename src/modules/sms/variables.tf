variable "preferences" {
  description = "Account-level SNS SMS preferences."
  type = object({
    default_sender_id                     = optional(string)
    monthly_spend_limit                   = optional(string) # AWS expects string; e.g., "50"
    default_sms_type                      = optional(string) # "Transactional" or "Promotional"
    delivery_status_iam_role_arn          = optional(string)
    delivery_status_success_sampling_rate = optional(string) # "0".."100"
    usage_report_s3_bucket                = optional(string)
  })
}

variable "topics" {
  description = "SNS topics to create for publishing SMS notifications."
  type = list(object({
    name         = string
    display_name = optional(string)
    policy_json  = optional(string)
    tags         = optional(map(string))
  }))
}

variable "pinpoint" {
  description = "Optional Pinpoint app + SMS channel."
  type = object({
    enable           = bool
    application_name = optional(string)
  })
}

variable "tags" {
  type        = map(string)
  description = "Common tags."
}
