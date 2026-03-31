# Dev environment values.
# These values are committed to source control — no secrets here.
# AWS credentials come from environment variables or GitHub Secrets.
#
# Note: Do NOT include the environment prefix in name_suffix.
# The module automatically constructs the full name as: "dev-<name_suffix>"
# Example: name_suffix = "orgwidesession-app-assets" → bucket = "dev-orgwidesession-app-assets"

environment        = "dev"
name_suffix        = "orgwidesession-app-assets"
versioning_enabled = false                         # Off in dev to avoid storage overhead

tags = {
  Environment = "dev"
  Project     = "OrgWideSession"
  ManagedBy   = "Terraform"
  Owner       = "platform-team"
  InitialDeploy = "true"
}
