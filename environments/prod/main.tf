# Prod environment entry point.
# Calls the shared S3 module with prod-specific variable values.
# The module prepends var.environment to var.name_suffix to form the bucket name.

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Credentials are read from environment variables:
#   AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY, AWS_DEFAULT_REGION
# Never hardcode credentials here.
provider "aws" {
  region = var.aws_region
}

module "app_bucket" {
  source = "../../modules/s3"

  environment        = var.environment    # "prod" → bucket name will be "prod-<name_suffix>"
  name_suffix        = var.name_suffix
  versioning_enabled = var.versioning_enabled
  tags               = var.tags
}
