output "bucket_id" {
  description = "Name of the S3 bucket"
  value       = module.app_bucket.bucket_id
}

output "bucket_arn" {
  description = "ARN of the S3 bucket — use this in IAM policies"
  value       = module.app_bucket.bucket_arn
}

output "bucket_regional_domain" {
  description = "Regional domain name — use this for CloudFront origins"
  value       = module.app_bucket.bucket_regional_domain
}