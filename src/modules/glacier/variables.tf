variable "rules" {
  description = "Lifecycle rules per bucket/prefix with optional transitions."
  type = list(object({
    bucket       = string
    prefix       = string
    to_ir_after  = optional(number) # days to Glacier Instant Retrieval
    to_fr_after  = optional(number) # days to Glacier Flexible Retrieval
    to_da_after  = optional(number) # days to Deep Archive
    expire_after = optional(number) # days to expire objects
  }))
}

variable "tags" {
  type        = map(string)
  description = "Tags applied where supported."
}
