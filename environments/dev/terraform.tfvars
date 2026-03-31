# Dev environment values.
# These values are committed to source control — no secrets here.
# AWS credentials come from environment variables or GitHub Secrets.
#
# Do NOT include the environment prefix in name_suffix.
# The module automatically constructs the full name as: "dev-<name_suffix>"

environment = "dev"

# Off in dev to avoid storage overhead
versioning_enabled = false

name_suffix = "orgwidesession-app-assets"

tags = {
  Environment   = "dev"
  InitialDeploy = "true"
  ManagedBy     = "Terraform"
  Owner         = "platform-team"
  Project       = "OrgWideSession"
}
