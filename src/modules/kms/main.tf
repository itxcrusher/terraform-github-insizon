resource "aws_kms_key" "this" {
  description             = "Insizon CMK"
  enable_key_rotation     = true
  rotation_period_in_days = var.rotation_days
  tags                    = var.tags
}

resource "aws_kms_alias" "this" {
  name          = var.alias_name
  target_key_id = aws_kms_key.this.key_id
}
