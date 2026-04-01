# Dev environment values.
# These values are committed to source control — no secrets here.
# AWS credentials come from environment variables or GitHub Secrets.
#
# Do NOT include the environment prefix in name_suffix.
# The module automatically constructs the full name as: "dev-<name_suffix>"

environment = "dev"
name_suffix = "orgwidesession-be"

tags = {
  Environment   = "dev"
  InitialDeploy = "true"
  ManagedBy     = "Terraform"
  Owner         = "platform-team"
  Project       = "OrgWideSession"
}

# ── S3 ────────────────────────────────────────────────────────────
versioning_enabled = false

# ── ECR ───────────────────────────────────────────────────────────
image_retention_count = 10

# ── ECS — Networking ──────────────────────────────────────────────
# Fill in your VPC and public subnet IDs.
# Find these in the AWS console: VPC → Your VPCs / Subnets
vpc_id           = "<YOUR_VPC_ID>"
subnet_ids       = ["<SUBNET_ID_1>", "<SUBNET_ID_2>"]
assign_public_ip = true

# ── ECS — Compute ─────────────────────────────────────────────────
ecs_cpu       = 512
ecs_memory    = 1024
desired_count = 1

# ── ECS — Non-sensitive container environment variables ───────────
container_environment = {
  PORT             = "8000"
  APP_NAME         = "ORGSESSION API"
  DEBUG            = "false"
  DEV_MODE         = "false"
  BYPASS_TOKEN     = "false"
  TIMEZONE         = "Asia/Kolkata"
  USE_ACTUAL_EMAIL = "true"
}

# ── ECS — Secrets Manager ─────────────────────────────────────────
# Create a single Secrets Manager secret containing all sensitive config as JSON:
#   {
#     "database_url":     "postgresql://user:pass@host:5432/dbname",
#     "client_id":        "...",
#     "tenant_id":        "...",
#     "openid_config_url":"...",
#     "valid_audience":   "...",
#     "valid_issuer":     "...",
#     "qr_secret_key":    "...",
#     "client_secret":    "...",
#     "email_redirect_url":"...",
#     "from_address":     "...",
#     "app_base_url":     "...",
#     "aws_access_key_id":"...",
#     "aws_secret_access_key":"...",
#     "s3_bucket_name":   "..."
#   }
# Then paste the secret ARN below (found in Secrets Manager console).
secrets_manager_arn = "<ARN_OF_YOUR_SECRETS_MANAGER_SECRET>"

# Keys to extract from the secret above (must exactly match JSON keys).
secret_keys = [
  "database_url",
  "client_id",
  "tenant_id",
  "openid_config_url",
  "valid_audience",
  "valid_issuer",
  "qr_secret_key",
  "client_secret",
  "email_redirect_url",
  "from_address",
  "app_base_url",
  "aws_access_key_id",
  "aws_secret_access_key",
  "s3_bucket_name",
]
