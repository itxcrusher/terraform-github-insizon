variable "alias_name" { type = string }    # e.g., "alias/insizon-kms"
variable "rotation_days" { type = number } # 90–365 typical
variable "tags" { type = map(string) }
