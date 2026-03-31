# Prod environment values.
# These values are committed to source control — no secrets here.
# AWS credentials come from environment variables or GitHub Secrets.
#
# Note: Do NOT include the environment prefix in name_suffix.
# The module automatically constructs the full name as: "prod-<name_suffix>"
# Example: name_suffix = "orgwidesession-app-assets" → bucket = "prod-orgwidesession-app-assets"

environment        = "prod"
name_suffix        = "orgwidesession-app-assets"
versioning_enabled = true                          # On in prod for point-in-time recovery

tags = {
  Environment = "prod"
  Project     = "OrgWideSession"
  ManagedBy   = "Terraform"
  Owner       = "platform-team"
  CostCenter  = "engineering"
}
