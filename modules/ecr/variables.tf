variable "environment" {
  description = "Deployment environment — used as the prefix for all resource names"
  type        = string
  validation {
    condition     = contains(["dev", "prod"], var.environment)
    error_message = "Environment must be one of: dev, prod."
  }
}

variable "name_suffix" {
  description = "Base name suffix for the ECR repository. Full name: <environment>-<name_suffix>"
  type        = string
}

variable "image_retention_count" {
  description = "Number of tagged images to keep. Older images are deleted automatically."
  type        = number
  default     = 10
}

variable "tags" {
  description = "Tags applied to all resources in this module"
  type        = map(string)
  default     = {}
}
