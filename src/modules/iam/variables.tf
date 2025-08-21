variable "roles" {
  description = "Short-lived roles with inline policies."
  type = list(object({
    name                = string
    max_session_seconds = number
    policy_statements = list(object({
      actions   = list(string)
      resources = list(string)
    }))
  }))
}

variable "assume_principals" {
  description = "Who can assume these roles. Tighten to ARNs of users/roles in your org."
  type        = list(string)
}

variable "tags" {
  type = map(string)
}
