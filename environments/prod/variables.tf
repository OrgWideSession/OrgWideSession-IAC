variable "aws_region" {
  description = "AWS region to deploy resources into"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Environment name — automatically prepended to all resource names as a prefix"
  type        = string
}

variable "name_suffix" {
  description = "Base name suffix for resources. The environment is prepended automatically: <environment>-<name_suffix>"
  type        = string
}

variable "tags" {
  description = "Map of tags applied to all resources"
  type        = map(string)
  default     = {}
}

# ── S3 ────────────────────────────────────────────────────────────
variable "versioning_enabled" {
  description = "Whether to enable S3 object versioning"
  type        = bool
  default     = false
}

# ── ECR ───────────────────────────────────────────────────────────
variable "image_retention_count" {
  description = "Number of tagged ECR images to keep before pruning"
  type        = number
  default     = 10
}

# ── ECS ───────────────────────────────────────────────────────────
variable "vpc_id" {
  description = "VPC ID where ECS tasks will run"
  type        = string
}

variable "subnet_ids" {
  description = "Subnet IDs for ECS tasks. Use public subnets when assign_public_ip = true."
  type        = list(string)
}

variable "assign_public_ip" {
  description = "Assign a public IP to Fargate tasks (true for public subnets without a NAT gateway)"
  type        = bool
  default     = true
}

variable "ecs_cpu" {
  description = "Fargate task CPU units"
  type        = number
  default     = 512
}

variable "ecs_memory" {
  description = "Fargate task memory in MiB"
  type        = number
  default     = 1024
}

variable "desired_count" {
  description = "Number of ECS tasks to keep running"
  type        = number
  default     = 1
}

variable "container_environment" {
  description = "Non-sensitive environment variables injected into the container"
  type        = map(string)
  default     = {}
}

variable "secrets_manager_arn" {
  description = "ARN of the Secrets Manager secret containing all sensitive app configuration as JSON"
  type        = string
}

variable "secret_keys" {
  description = "Keys to extract from the Secrets Manager secret and inject as container environment variables"
  type        = list(string)
  default     = []
}
