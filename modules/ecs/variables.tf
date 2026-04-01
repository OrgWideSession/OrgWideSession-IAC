variable "environment" {
  description = "Deployment environment — used as the prefix for all resource names"
  type        = string
  validation {
    condition     = contains(["dev", "prod"], var.environment)
    error_message = "Environment must be one of: dev, prod."
  }
}

variable "name_suffix" {
  description = "Base name suffix for ECS resources. Full name: <environment>-<name_suffix>"
  type        = string
}

# ── Networking ────────────────────────────────────────────────────
variable "vpc_id" {
  description = "ID of the VPC where the ECS service will run"
  type        = string
}

variable "subnet_ids" {
  description = "List of subnet IDs for ECS tasks. Use public subnets when assign_public_ip = true."
  type        = list(string)
}

variable "assign_public_ip" {
  description = "Assign a public IP to each Fargate task. Set true when tasks are in public subnets with no NAT gateway."
  type        = bool
  default     = true
}

variable "allowed_ingress_cidrs" {
  description = "CIDR blocks allowed to reach the container port. Defaults to anywhere."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

# ── Container ─────────────────────────────────────────────────────
variable "container_image" {
  description = "Full Docker image URI to deploy. Example: 123456789012.dkr.ecr.us-east-1.amazonaws.com/dev-orgwidesession-be:latest"
  type        = string
}

variable "container_port" {
  description = "Port the container listens on"
  type        = number
  default     = 8000
}

variable "cpu" {
  description = "Fargate task CPU units (256, 512, 1024, 2048, 4096)"
  type        = number
  default     = 512
}

variable "memory" {
  description = "Fargate task memory in MiB (must be compatible with cpu value)"
  type        = number
  default     = 1024
}

variable "desired_count" {
  description = "Number of ECS tasks to run"
  type        = number
  default     = 1
}

# ── Environment variables (non-sensitive, baked into task definition) ──
variable "container_environment" {
  description = "Map of non-sensitive environment variables injected into the container"
  type        = map(string)
  default     = {}
}

# ── Secrets from AWS Secrets Manager ──────────────────────────────
# Store all sensitive configuration in a single Secrets Manager secret as a
# flat JSON object: { "DATABASE_URL": "...", "CLIENT_ID": "...", ... }
# The ECS execution role will pull each key listed in secret_keys at task start.
variable "secrets_manager_arn" {
  description = "ARN of the AWS Secrets Manager secret that holds all sensitive app configuration as JSON key-value pairs"
  type        = string
}

variable "secret_keys" {
  description = "Keys to extract from the Secrets Manager secret and inject as environment variables (uppercased)"
  type        = list(string)
  default     = []
}

# ── Health check ──────────────────────────────────────────────────
variable "health_check_path" {
  description = "HTTP path used for the container health check"
  type        = string
  default     = "/docs"
}

variable "health_check_start_period" {
  description = "Seconds ECS waits before starting health checks. Set high enough for migrations to complete."
  type        = number
  default     = 60
}

variable "tags" {
  description = "Tags applied to all resources in this module"
  type        = map(string)
  default     = {}
}
