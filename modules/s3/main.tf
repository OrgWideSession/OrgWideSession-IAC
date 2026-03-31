# Creates an S3 bucket with AWS best-practice settings applied by default.
# Security and compliance settings are non-optional; behavior tuning uses variables.
#
# Bucket name is constructed as: "<environment>-<name_suffix>"
# This ensures the environment prefix is always present and consistent.

locals {
  # Construct the full bucket name with environment prefix.
  # Example: "dev-orgwidesession-app-assets" or "prod-orgwidesession-app-assets"
  bucket_name = "${var.environment}-${var.name_suffix}"
}

resource "aws_s3_bucket" "this" {
  bucket = local.bucket_name

  tags = merge(var.tags, { Name = local.bucket_name })
}

# Block all public access — on by default.
# The vast majority of S3 buckets should never be publicly accessible.
resource "aws_s3_bucket_public_access_block" "this" {
  bucket = aws_s3_bucket.this.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Versioning — off in dev (saves cost), on in prod (enables recovery).
resource "aws_s3_bucket_versioning" "this" {
  bucket = aws_s3_bucket.this.id

  versioning_configuration {
    status = var.versioning_enabled ? "Enabled" : "Suspended"
  }
}

# Server-side encryption — always on regardless of environment.
resource "aws_s3_bucket_server_side_encryption_configuration" "this" {
  bucket = aws_s3_bucket.this.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
    bucket_key_enabled = true
  }
}

# Lifecycle rule — clean up old object versions automatically.
# Only meaningful when versioning is enabled; safe to define when suspended.
resource "aws_s3_bucket_lifecycle_configuration" "this" {
  bucket     = aws_s3_bucket.this.id
  depends_on = [aws_s3_bucket_versioning.this]

  rule {
    id     = "expire-old-versions"
    status = "Enabled"

    # filter is required by the AWS provider (even when the rule applies to all objects).
    # An empty filter block means: apply this rule to every object in the bucket.
    filter {}

    noncurrent_version_expiration {
      noncurrent_days = 30   # Increase for prod if longer recovery windows are needed
    }
  }
}
