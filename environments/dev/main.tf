# Dev environment entry point.
# Manages all dev infrastructure: S3 assets bucket, ECR repository, ECS Fargate service.
# Resource names are prefixed "dev-" via the shared module convention.

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

  environment        = var.environment
  name_suffix        = var.name_suffix
  versioning_enabled = var.versioning_enabled
  tags               = var.tags
}

module "ecr" {
  source = "../../modules/ecr"

  environment           = var.environment
  name_suffix           = var.name_suffix
  image_retention_count = var.image_retention_count
  tags                  = var.tags
}

module "ecs" {
  source = "../../modules/ecs"

  environment  = var.environment
  name_suffix  = var.name_suffix
  tags         = var.tags

  # Networking — fill subnet_ids and vpc_id in terraform.tfvars
  vpc_id           = var.vpc_id
  subnet_ids       = var.subnet_ids
  assign_public_ip = var.assign_public_ip

  # Container — image comes from the ECR repo created above
  container_image = "${module.ecr.repository_url}:latest"
  ecs_cpu         = var.ecs_cpu
  ecs_memory      = var.ecs_memory
  desired_count   = var.desired_count

  # Non-sensitive config baked into the task definition
  container_environment = var.container_environment

  # Sensitive config pulled from Secrets Manager at task start
  secrets_manager_arn = var.secrets_manager_arn
  secret_keys         = var.secret_keys
}
