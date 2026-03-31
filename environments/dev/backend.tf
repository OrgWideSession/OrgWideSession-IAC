# Remote state configuration for the dev environment.
# State is stored in S3 and locked via DynamoDB to prevent concurrent applies.
#
# Important: The backend block does not support variable interpolation.
# The actual bucket and table names are injected via -backend-config flags
# at terraform init time (done in the GitHub Actions workflow).

terraform {
  backend "s3" {
    bucket         = "github-session-my-org-terraform-state"       # S3 bucket holding all state files
    key            = "dev/s3/terraform.tfstate"     # Dev-specific key — isolated from prod
    region         = "us-east-1"
    dynamodb_table = "github-session-my-org-terraform-locks"       # DynamoDB table for state locking
    encrypt        = true
  }
}