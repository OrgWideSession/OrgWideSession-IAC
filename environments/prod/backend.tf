# Remote state configuration for the prod environment.
# State is stored in S3 and locked via DynamoDB to prevent concurrent applies.
#
# The backend block does not support variable interpolation.
# Bucket and table names are injected via -backend-config flags at terraform init
# time — see the GitHub Actions workflow (TF_BACKEND_BUCKET / TF_BACKEND_DYNAMODB_TABLE secrets).

terraform {
  backend "s3" {
    # S3 bucket that holds all Terraform state files (created by bootstrap/)
    bucket = "github-session-my-org-terraform-state"

    # Prod-specific key — different from dev (dev uses dev/s3/terraform.tfstate)
    key = "prod/s3/terraform.tfstate"

    region = "us-east-1"

    # DynamoDB table that provides state locking (prevents concurrent applies)
    dynamodb_table = "github-session-my-org-terraform-locks"

    # Encrypt state at rest — always enable this
    encrypt = true
  }
}
