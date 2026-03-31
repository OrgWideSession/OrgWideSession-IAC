# Values this module exposes to its callers.
# Reference as: module.app_bucket.bucket_arn, etc.

output "bucket_id" {
  description = "The bucket name (same as ID in S3)"
  value       = aws_s3_bucket.this.id
}

output "bucket_arn" {
  description = "Full ARN — use this in IAM policy documents"
  value       = aws_s3_bucket.this.arn
}

output "bucket_regional_domain" {
  description = "Regional domain name — use this for CloudFront origins"
  value       = aws_s3_bucket.this.bucket_regional_domain_name
}