# Defines the interface (inputs) of this module.
# Callers (environments/dev/main.tf, environments/prod/main.tf) provide these values.
#
# Naming convention: the final S3 bucket name is automatically constructed as:
#   <environment>-<name_suffix>
# Example: environment="dev", name_suffix="orgwidesession-app-assets"
#          → bucket name = "dev-orgwidesession-app-assets"
#
# This enforces consistent environment prefixing — no caller can forget to add the prefix.

variable "environment" {
  description = "Deployment environment — used as the prefix for all resource names"
  type        = string

  validation {
    condition     = contains(["dev", "prod"], var.environment)
    error_message = "Environment must be one of: dev, prod."
  }
}

variable "name_suffix" {
  description = "Base name suffix for the S3 bucket. The environment is automatically prepended: <environment>-<name_suffix>"
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9\\-]{1,55}[a-z0-9]$", var.name_suffix))
    error_message = "name_suffix must be lowercase alphanumeric and hyphens only, 3-57 characters (environment prefix uses up to 5 characters of the 63-character bucket name limit)."
  }
}

variable "versioning_enabled" {
  description = "Enable S3 object versioning (recommended true for prod)"
  type        = bool
  default     = false
}

variable "tags" {
  description = "Tags to apply to all resources in this module"
  type        = map(string)
  default     = {}
}
