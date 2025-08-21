output "configured_buckets" {
  value       = distinct([for k, v in aws_s3_bucket_lifecycle_configuration.this : v.bucket])
  description = "Buckets that received lifecycle configurations."
}
