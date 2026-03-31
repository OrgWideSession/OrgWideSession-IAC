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

variable "versioning_enabled" {
  description = "Whether to enable S3 object versioning"
  type        = bool
  default     = false
}

variable "tags" {
  description = "Map of tags applied to all resources"
  type        = map(string)
  default     = {}
}
