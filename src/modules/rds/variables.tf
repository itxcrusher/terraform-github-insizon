variable "engine_version" { type = string }
variable "instance_class" { type = string }
variable "multi_az" { type = bool }
variable "allocated_storage" { type = number }
variable "backup_retention" { type = number }

variable "vpc_id" { type = string }
variable "subnet_ids" { type = list(string) }
variable "sg_ids" { type = list(string) }

variable "db_name" { type = string }
variable "username_ssm" { type = string } # SecureString path
variable "password_ssm" { type = string } # SecureString path

variable "tags" { type = map(string) }
