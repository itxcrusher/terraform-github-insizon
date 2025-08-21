locals {
  rules = var.rules
}

resource "aws_s3_bucket_lifecycle_configuration" "this" {
  for_each = { for r in local.rules : "${r.bucket}:${r.prefix}" => r }

  bucket = each.value.bucket

  rule {
    id     = "glacier-${replace(each.value.prefix, "/", "-")}"
    status = "Enabled"

    filter { prefix = each.value.prefix }

    dynamic "transition" {
      for_each = try([each.value.to_ir_after], [])
      content {
        days          = transition.value
        storage_class = "GLACIER_IR"
      }
    }
    dynamic "transition" {
      for_each = try([each.value.to_fr_after], [])
      content {
        days          = transition.value
        storage_class = "GLACIER"
      }
    }
    dynamic "transition" {
      for_each = try([each.value.to_da_after], [])
      content {
        days          = transition.value
        storage_class = "DEEP_ARCHIVE"
      }
    }

    dynamic "expiration" {
      for_each = try([each.value.expire_after], [])
      content { days = expiration.value }
    }
  }
}
