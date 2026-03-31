# Terraform + GitHub Actions: Unified Workflow Implementation Guide

> **Approach:** A single GitHub Actions workflow file handles both dev and prod deployments. The environment is selected dynamically based on which branch triggered the run.
>
> **Branch model:** `development` branch → dev environment | `main` branch → production environment
>
> **Naming convention:** All AWS resource names are automatically prefixed with the environment. `name_suffix = "orgwidesession-app-assets"` produces `dev-orgwidesession-app-assets` in dev and `prod-orgwidesession-app-assets` in prod.
>
> **Note:** The development branch in this repository is spelled `development` (missing an "e"). This is the actual branch name — use it exactly as shown throughout.

---

## Table of Contents

1. [Project Structure](#1-project-structure)
2. [Terraform Configuration](#2-terraform-configuration)
   - [2.1 Reusable S3 Module](#21-reusable-s3-module)
   - [2.2 Dev Environment](#22-dev-environment)
   - [2.3 Prod Environment](#23-prod-environment)
   - [2.4 Remote State Bootstrap](#24-remote-state-bootstrap-one-time-setup)
3. [The Unified GitHub Actions Workflow](#3-the-unified-github-actions-workflow)
   - [3.1 How Branch-Based Environment Selection Works](#31-how-branch-based-environment-selection-works)
   - [3.2 Workflow Structure Overview](#32-workflow-structure-overview)
   - [3.3 Complete Workflow YAML](#33-complete-workflow-yaml-githubworkflowsterraformyml)
   - [3.4 How Jobs Consume Setup Outputs](#34-how-jobs-consume-setup-outputs)
4. [Complete Beginner Deployment Guide](#4-complete-beginner-deployment-guide)
   - [4.1 What You Need Before Starting](#41-what-you-need-before-starting)
   - [4.2 Step 1 — Bootstrap Remote State (AWS)](#42-step-1--bootstrap-remote-state-aws)
   - [4.3 Step 2 — Configure GitHub Secrets](#43-step-2--configure-github-secrets)
   - [4.4 Step 3 — Create GitHub Environments](#44-step-3--create-github-environments)
   - [4.5 Step 4 — Set Branch Protection Rules](#45-step-4--set-branch-protection-rules)
   - [4.6 Step 5 — Deploy to Dev (First Run)](#46-step-5--deploy-to-dev-first-run)
   - [4.7 Step 6 — Deploy to Prod (First Run)](#47-step-6--deploy-to-prod-first-run)
   - [4.8 Verify in AWS Console](#48-verify-in-aws-console)
   - [4.9 Troubleshooting Common Errors](#49-troubleshooting-common-errors)
5. [End-to-End Deployment Flow](#5-end-to-end-deployment-flow)
6. [Unified vs Two-Workflow Comparison](#6-unified-vs-two-workflow-comparison)

---

## 1. Project Structure

```
OrgWideSession-IAC/               ← Repository root
│
├── modules/
│   └── s3/                       ← Reusable S3 module (shared across all environments)
│       ├── main.tf               ← S3 resources; constructs bucket name as <env>-<name_suffix>
│       ├── variables.tf          ← Inputs: environment, name_suffix, versioning_enabled, tags
│       └── outputs.tf            ← Outputs: bucket_id, bucket_arn, bucket_regional_domain
│
├── environments/
│   ├── dev/                      ← Dev root module — its own isolated state file
│   │   ├── backend.tf            ← Remote state at key: dev/s3/terraform.tfstate
│   │   ├── variables.tf          ← Variable declarations
│   │   ├── terraform.tfvars      ← Dev values (name_suffix, tags, versioning off)
│   │   ├── main.tf               ← Calls modules/s3 passing environment="dev"
│   │   └── outputs.tf            ← Exposes bucket details after apply
│   │
│   └── prod/                     ← Prod root module — completely separate state
│       ├── backend.tf            ← Remote state at key: prod/s3/terraform.tfstate
│       ├── variables.tf
│       ├── terraform.tfvars      ← Prod values (same name_suffix, versioning on)
│       ├── main.tf               ← Calls modules/s3 passing environment="prod"
│       └── outputs.tf
│
├── bootstrap/
│   └── main.tf                   ← One-time setup: creates state S3 bucket + DynamoDB lock table
│
├── .github/
│   └── workflows/
│       └── terraform.yml         ← Single unified workflow (handles both dev and prod)
│
├── TERRAFORM_CICD_GUIDE.md       ← Progressive learning reference
├── TERRAFORM_IMPLEMENTATION_GUIDE.md  ← This file
└── .gitignore
```

### Environment Prefix Convention

All resource names are constructed inside the module — callers only provide the suffix:

```
terraform.tfvars         module/main.tf              AWS resource name
────────────────         ──────────────              ────────────────
name_suffix =       →    local.bucket_name =    →    dev-orgwidesession-app-assets
"orgwidesession-         "${var.environment}-         (in dev environment)
 app-assets"             ${var.name_suffix}"
                                                      prod-orgwidesession-app-assets
                                                      (in prod environment)
```

This enforces consistent prefixing across all environments. A dev bucket can never accidentally be named `prod-*`.

---

## 2. Terraform Configuration

### 2.1 Reusable S3 Module

#### `modules/s3/variables.tf`

```hcl
# Defines the interface (inputs) of this module.
# Callers (environments/dev/main.tf, environments/prod/main.tf) provide these values.
#
# Naming convention: the final S3 bucket name is automatically constructed as:
#   <environment>-<name_suffix>
# Example: environment="dev", name_suffix="orgwidesession-app-assets"
#          → bucket name = "dev-orgwidesession-app-assets"

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
    error_message = "name_suffix must be lowercase alphanumeric and hyphens only, 3-57 characters."
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
```

#### `modules/s3/main.tf`

```hcl
# Creates an S3 bucket with AWS best-practice settings applied by default.
# Bucket name is constructed as: "<environment>-<name_suffix>"

locals {
  # Full bucket name with environment prefix enforced.
  # "dev"  + "orgwidesession-app-assets" → "dev-orgwidesession-app-assets"
  # "prod" + "orgwidesession-app-assets" → "prod-orgwidesession-app-assets"
  bucket_name = "${var.environment}-${var.name_suffix}"
}

resource "aws_s3_bucket" "this" {
  bucket = local.bucket_name

  tags = merge(var.tags, { Name = local.bucket_name })
}

# Block all public access — on by default.
resource "aws_s3_bucket_public_access_block" "this" {
  bucket = aws_s3_bucket.this.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Versioning — off in dev (saves cost), on in prod (enables recovery).
resource "aws_s3_bucket_versioning" "this" {
  bucket = aws_s3_bucket.this.id

  versioning_configuration {
    status = var.versioning_enabled ? "Enabled" : "Suspended"
  }
}

# Server-side encryption — always on regardless of environment.
resource "aws_s3_bucket_server_side_encryption_configuration" "this" {
  bucket = aws_s3_bucket.this.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
    bucket_key_enabled = true
  }
}

# Lifecycle rule — delete old object versions after 30 days.
resource "aws_s3_bucket_lifecycle_configuration" "this" {
  bucket     = aws_s3_bucket.this.id
  depends_on = [aws_s3_bucket_versioning.this]

  rule {
    id     = "expire-old-versions"
    status = "Enabled"

    noncurrent_version_expiration {
      noncurrent_days = 30
    }
  }
}
```

#### `modules/s3/outputs.tf`

```hcl
output "bucket_id" {
  description = "The bucket name (same as ID in S3)"
  value       = aws_s3_bucket.this.id
}

output "bucket_arn" {
  description = "Full ARN — use this in IAM policy documents"
  value       = aws_s3_bucket.this.arn
}

output "bucket_regional_domain" {
  description = "Regional domain name — use this for CloudFront origins"
  value       = aws_s3_bucket.this.bucket_regional_domain_name
}
```

---

### 2.2 Dev Environment

#### `environments/dev/backend.tf`

```hcl
# Remote state for dev environment.
# State bucket and table names are injected via -backend-config at init time
# (see the GitHub Actions workflow — the actual values come from GitHub Secrets).

terraform {
  backend "s3" {
    bucket         = "orgwidesession-terraform-state"   # Replace with your actual state bucket name
    key            = "dev/s3/terraform.tfstate"         # Dev-specific key — isolated from prod
    region         = "us-east-1"
    dynamodb_table = "orgwidesession-terraform-locks"   # Replace with your actual table name
    encrypt        = true
  }
}
```

#### `environments/dev/variables.tf`

```hcl
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
  description = "Base name suffix for resources. The environment is prepended: <environment>-<name_suffix>"
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
```

#### `environments/dev/terraform.tfvars`

```hcl
# Dev environment values.
# Do NOT include the environment prefix in name_suffix.
# The module automatically constructs: "dev-orgwidesession-app-assets"

environment        = "dev"
name_suffix        = "orgwidesession-app-assets"
versioning_enabled = false

tags = {
  Environment = "dev"
  Project     = "OrgWideSession"
  ManagedBy   = "Terraform"
  Owner       = "platform-team"
}
```

#### `environments/dev/main.tf`

```hcl
# Dev environment entry point.
# The module prepends environment="dev" to name_suffix to form the bucket name.

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

module "app_bucket" {
  source = "../../modules/s3"

  environment        = var.environment    # "dev" → bucket = "dev-<name_suffix>"
  name_suffix        = var.name_suffix
  versioning_enabled = var.versioning_enabled
  tags               = var.tags
}
```

#### `environments/dev/outputs.tf`

```hcl
output "bucket_id" {
  description = "Full name of the S3 bucket (includes environment prefix)"
  value       = module.app_bucket.bucket_id
}

output "bucket_arn" {
  description = "ARN of the S3 bucket — use this in IAM policies"
  value       = module.app_bucket.bucket_arn
}

output "bucket_regional_domain" {
  description = "Regional domain name — use this for CloudFront origins"
  value       = module.app_bucket.bucket_regional_domain
}
```

---

### 2.3 Prod Environment

#### `environments/prod/backend.tf`

```hcl
terraform {
  backend "s3" {
    bucket         = "orgwidesession-terraform-state"
    key            = "prod/s3/terraform.tfstate"        # Different key = completely isolated state
    region         = "us-east-1"
    dynamodb_table = "orgwidesession-terraform-locks"
    encrypt        = true
  }
}
```

#### `environments/prod/variables.tf`

```hcl
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
  description = "Base name suffix for resources. The environment is prepended: <environment>-<name_suffix>"
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
```

#### `environments/prod/terraform.tfvars`

```hcl
# Prod environment values.
# Do NOT include the environment prefix in name_suffix.
# The module automatically constructs: "prod-orgwidesession-app-assets"

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
```

#### `environments/prod/main.tf`

```hcl
# Prod environment entry point.
# The module prepends environment="prod" to name_suffix to form the bucket name.

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

module "app_bucket" {
  source = "../../modules/s3"

  environment        = var.environment    # "prod" → bucket = "prod-<name_suffix>"
  name_suffix        = var.name_suffix
  versioning_enabled = var.versioning_enabled
  tags               = var.tags
}
```

#### `environments/prod/outputs.tf`

```hcl
output "bucket_id" {
  description = "Full name of the S3 bucket (includes environment prefix)"
  value       = module.app_bucket.bucket_id
}

output "bucket_arn" {
  description = "ARN of the S3 bucket — use this in IAM policies"
  value       = module.app_bucket.bucket_arn
}

output "bucket_regional_domain" {
  description = "Regional domain name — use this for CloudFront origins"
  value       = module.app_bucket.bucket_regional_domain
}
```

---

### 2.4 Remote State Bootstrap (One-Time Setup)

Before any environment can store Terraform state in S3, the state bucket and DynamoDB lock table must exist. This one-time step is already done if the `bootstrap/` directory exists with a `terraform.tfstate`.

```hcl
# bootstrap/main.tf — Run ONCE manually to create the state backend resources.

provider "aws" {
  region = "us-east-1"
}

resource "aws_s3_bucket" "terraform_state" {
  bucket = "orgwidesession-terraform-state"   # Must be globally unique — adjust if taken

  lifecycle {
    prevent_destroy = true    # Never accidentally delete the bucket that holds all state
  }
}

resource "aws_s3_bucket_versioning" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id
  versioning_configuration {
    status = "Enabled"    # State versions let you recover from accidental corruption
  }
}

resource "aws_dynamodb_table" "terraform_locks" {
  name         = "orgwidesession-terraform-locks"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }
}
```

---

## 3. The Unified GitHub Actions Workflow

### 3.1 How Branch-Based Environment Selection Works

```
Push / PR to `development`              Push / PR to `main`
          │                                      │
          ▼                                      ▼
    setup job reads                        setup job reads
    github.ref_name                        github.ref_name
    = "development"                         = "main"
          │                                      │
          ▼                                      ▼
  environment = "dev"              environment  = "prod"
  working_dir = environments/dev   working_dir  = environments/prod
  artifact    = tfplan-dev         artifact     = tfplan-prod
          │                                      │
          ▼                                      ▼
  validate + plan + apply          validate + plan + apply
  (against dev infrastructure)     (against prod, with approval gate)
```

For **pull requests**, the setup job reads `github.base_ref` (the PR's target branch) instead of `github.ref_name`. This ensures a PR targeting `development` generates a dev plan, and a PR targeting `main` generates a prod plan.

---

### 3.2 Workflow Structure Overview

```
Job 1: setup        — Detect branch, export environment/working_dir/artifact_name
         │
         ▼
Job 2: validate     — terraform fmt -check + terraform validate
         │
         ▼
Job 3: plan         — terraform plan, upload artifact, post to PR
         │
         ▼
Job 4: apply        — Push events only; GitHub Environment approval gate; apply saved plan
```

---

### 3.3 Complete Workflow YAML (`.github/workflows/terraform.yml`)

```yaml
# terraform.yml — Unified Terraform CI/CD workflow.
#
# Branch-to-environment mapping:
#   development → dev  (environments/dev/)
#   main       → prod (environments/prod/)

name: "Terraform — Unified"

on:
  pull_request:
    branches:
      - main
      - development
    paths:
      - "environments/**"
      - "modules/**"

  push:
    branches:
      - main
      - development
    paths:
      - "environments/**"
      - "modules/**"

# One concurrency group per branch — prevents two applies running simultaneously.
concurrency:
  group: terraform-${{ github.ref_name }}
  cancel-in-progress: false

jobs:
  # ──────────────────────────────────────────────────────────
  # JOB 1: SETUP — Branch detection and environment mapping
  # ──────────────────────────────────────────────────────────
  setup:
    name: "Setup — Detect Environment"
    runs-on: ubuntu-latest

    outputs:
      environment:   ${{ steps.set-env.outputs.environment }}
      working_dir:   ${{ steps.set-env.outputs.working_dir }}
      artifact_name: ${{ steps.set-env.outputs.artifact_name }}

    steps:
      - name: Determine target environment from branch
        id: set-env
        run: |
          # For push events:        use github.ref_name (the branch being pushed to)
          # For pull_request events: use github.base_ref (the PR's target branch)
          if [ "${{ github.event_name }}" == "pull_request" ]; then
            BRANCH="${{ github.base_ref }}"
          else
            BRANCH="${{ github.ref_name }}"
          fi

          echo "Target branch: $BRANCH"

          if [ "$BRANCH" == "development" ]; then
            echo "environment=dev"                 >> $GITHUB_OUTPUT
            echo "working_dir=environments/dev"    >> $GITHUB_OUTPUT
            echo "artifact_name=tfplan-dev"        >> $GITHUB_OUTPUT
          elif [ "$BRANCH" == "main" ]; then
            echo "environment=prod"                >> $GITHUB_OUTPUT
            echo "working_dir=environments/prod"   >> $GITHUB_OUTPUT
            echo "artifact_name=tfplan-prod"       >> $GITHUB_OUTPUT
          else
            echo "ERROR: Unrecognised branch '$BRANCH'. Must be 'development' or 'main'."
            exit 1
          fi

  # ──────────────────────────────────────────────────────────
  # JOB 2: VALIDATE — Format check and syntax validation
  # ──────────────────────────────────────────────────────────
  validate:
    name: "Validate"
    runs-on: ubuntu-latest
    needs: setup

    env:
      # Select dev or prod credentials based on the environment output from setup.
      # GitHub Actions does not support dynamic secret names, so conditional expressions
      # are used as a workaround.
      AWS_ACCESS_KEY_ID: >-
        ${{ needs.setup.outputs.environment == 'dev'
            && secrets.AWS_ACCESS_KEY_ID_DEV
            || secrets.AWS_ACCESS_KEY_ID_PROD }}
      AWS_SECRET_ACCESS_KEY: >-
        ${{ needs.setup.outputs.environment == 'dev'
            && secrets.AWS_SECRET_ACCESS_KEY_DEV
            || secrets.AWS_SECRET_ACCESS_KEY_PROD }}
      AWS_DEFAULT_REGION: us-east-1

    steps:
      - name: Checkout repository
        uses: actions/checkout@v4

      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v3
        with:
          terraform_version: "1.7.0"

      - name: Terraform Init
        working-directory: ${{ needs.setup.outputs.working_dir }}
        run: |
          terraform init \
            -backend-config="bucket=${{ secrets.TF_BACKEND_BUCKET }}" \
            -backend-config="dynamodb_table=${{ secrets.TF_BACKEND_DYNAMODB_TABLE }}" \
            -input=false

      - name: Terraform Format Check
        working-directory: ${{ needs.setup.outputs.working_dir }}
        run: terraform fmt -check -recursive

      - name: Terraform Validate
        working-directory: ${{ needs.setup.outputs.working_dir }}
        run: terraform validate

  # ──────────────────────────────────────────────────────────
  # JOB 3: PLAN — Generate and save the execution plan
  # ──────────────────────────────────────────────────────────
  plan:
    name: "Plan"
    runs-on: ubuntu-latest
    needs: [setup, validate]

    env:
      AWS_ACCESS_KEY_ID: >-
        ${{ needs.setup.outputs.environment == 'dev'
            && secrets.AWS_ACCESS_KEY_ID_DEV
            || secrets.AWS_ACCESS_KEY_ID_PROD }}
      AWS_SECRET_ACCESS_KEY: >-
        ${{ needs.setup.outputs.environment == 'dev'
            && secrets.AWS_SECRET_ACCESS_KEY_DEV
            || secrets.AWS_SECRET_ACCESS_KEY_PROD }}
      AWS_DEFAULT_REGION: us-east-1

    steps:
      - name: Checkout repository
        uses: actions/checkout@v4

      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v3
        with:
          terraform_version: "1.7.0"

      - name: Terraform Init
        working-directory: ${{ needs.setup.outputs.working_dir }}
        run: |
          terraform init \
            -backend-config="bucket=${{ secrets.TF_BACKEND_BUCKET }}" \
            -backend-config="dynamodb_table=${{ secrets.TF_BACKEND_DYNAMODB_TABLE }}" \
            -input=false

      - name: Terraform Plan
        id: plan
        working-directory: ${{ needs.setup.outputs.working_dir }}
        run: terraform plan -out=tfplan -input=false

      - name: Upload Plan Artifact
        uses: actions/upload-artifact@v4
        with:
          name: ${{ needs.setup.outputs.artifact_name }}
          path: ${{ needs.setup.outputs.working_dir }}/tfplan
          retention-days: 1

      - name: Post Plan Output to PR
        if: github.event_name == 'pull_request'
        uses: actions/github-script@v7
        env:
          PLAN_OUTPUT: ${{ steps.plan.outputs.stdout }}
        with:
          script: |
            const env = "${{ needs.setup.outputs.environment }}".toUpperCase();
            const body = `### Terraform Plan — ${env} Environment
            \`\`\`hcl
            ${process.env.PLAN_OUTPUT}
            \`\`\`
            *Run: [${{ github.run_id }}](${{ github.server_url }}/${{ github.repository }}/actions/runs/${{ github.run_id }})*`;

            await github.rest.issues.createComment({
              issue_number: context.issue.number,
              owner: context.repo.owner,
              repo: context.repo.repo,
              body: body
            });

  # ──────────────────────────────────────────────────────────
  # JOB 4: APPLY — Execute the saved plan
  # ──────────────────────────────────────────────────────────
  apply:
    name: "Apply"
    runs-on: ubuntu-latest
    needs: [setup, plan]
    if: github.event_name == 'push'

    # Dynamic environment name — GitHub applies the correct approval rules per env.
    # "dev"  environment: optional approval (configure as needed)
    # "prod" environment: required reviewers must approve before apply runs
    environment:
      name: ${{ needs.setup.outputs.environment }}

    env:
      AWS_ACCESS_KEY_ID: >-
        ${{ needs.setup.outputs.environment == 'dev'
            && secrets.AWS_ACCESS_KEY_ID_DEV
            || secrets.AWS_ACCESS_KEY_ID_PROD }}
      AWS_SECRET_ACCESS_KEY: >-
        ${{ needs.setup.outputs.environment == 'dev'
            && secrets.AWS_SECRET_ACCESS_KEY_DEV
            || secrets.AWS_SECRET_ACCESS_KEY_PROD }}
      AWS_DEFAULT_REGION: us-east-1

    steps:
      - name: Checkout repository
        uses: actions/checkout@v4

      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v3
        with:
          terraform_version: "1.7.0"

      - name: Terraform Init
        working-directory: ${{ needs.setup.outputs.working_dir }}
        run: |
          terraform init \
            -backend-config="bucket=${{ secrets.TF_BACKEND_BUCKET }}" \
            -backend-config="dynamodb_table=${{ secrets.TF_BACKEND_DYNAMODB_TABLE }}" \
            -input=false

      - name: Download Plan Artifact
        uses: actions/download-artifact@v4
        with:
          name: ${{ needs.setup.outputs.artifact_name }}
          path: ${{ needs.setup.outputs.working_dir }}

      - name: Terraform Apply
        working-directory: ${{ needs.setup.outputs.working_dir }}
        run: terraform apply -input=false tfplan
```

---

### 3.4 How Jobs Consume Setup Outputs

The `setup` job writes three values to `$GITHUB_OUTPUT`. All downstream jobs reference them via `needs.setup.outputs.*`:

```
setup outputs
  ├── environment   → "dev" or "prod"
  ├── working_dir   → "environments/dev" or "environments/prod"
  └── artifact_name → "tfplan-dev" or "tfplan-prod"
        │
        ├── validate: working-directory, AWS credential selection
        ├── plan:     working-directory, artifact upload name, AWS credentials
        └── apply:    working-directory, artifact download name, environment gate, AWS credentials
```

**Why you cannot use dynamic secret names directly:**

GitHub Actions does not allow `secrets[variable_name]`. The workaround is a short-circuit conditional:

```yaml
AWS_ACCESS_KEY_ID: >-
  ${{ needs.setup.outputs.environment == 'dev'
      && secrets.AWS_ACCESS_KEY_ID_DEV
      || secrets.AWS_ACCESS_KEY_ID_PROD }}
```

If `environment == 'dev'` is true, the expression evaluates to `AWS_ACCESS_KEY_ID_DEV`. Otherwise it falls through to `AWS_ACCESS_KEY_ID_PROD`. **Both secrets must be created in the repository** — GitHub substitutes an empty string for missing secrets rather than failing, which would silently use wrong credentials.

---

## 4. Complete Beginner Deployment Guide

This section walks through every step required to go from a blank repository to working infrastructure deployed on AWS — including exactly where to click in GitHub and what values to enter.

**Time required:** approximately 45–60 minutes for a first-time setup.

---

### 4.1 What You Need Before Starting

Before touching anything, make sure you have:

| Requirement | How to get it | Notes |
|---|---|---|
| AWS account | [aws.amazon.com](https://aws.amazon.com) | Free tier is sufficient for this setup |
| AWS IAM credentials | AWS Console → IAM → Users → Your user → Security credentials → Create access key | Select "CLI" as the use case |
| Terraform CLI | See [TERRAFORM_CICD_GUIDE.md §1.2](./TERRAFORM_CICD_GUIDE.md#12-installing-terraform) | Version 1.5.0 or higher |
| AWS CLI | [AWS CLI install guide](https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2.html) | Run `aws configure` after install |
| Git | [git-scm.com](https://git-scm.com) | Any recent version |
| GitHub account | [github.com](https://github.com) | Must be a collaborator on `OrgWideSession-IAC` |
| This repository cloned locally | `git clone <repo-url>` | |

**Configure AWS CLI locally:**
```bash
aws configure
# AWS Access Key ID [None]: AKIAIOSFODNN7EXAMPLE
# AWS Secret Access Key [None]: wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY
# Default region name [None]: us-east-1
# Default output format [None]: json

# Verify it works:
aws sts get-caller-identity
# Should return your account ID, user ID, and ARN
```

---

### 4.2 Step 1 — Bootstrap Remote State (AWS)

This step creates the S3 bucket and DynamoDB table that store Terraform state. **Run this once from your local machine.** Skip if the `bootstrap/terraform.tfstate` file already exists and shows resources were created.

```bash
# Navigate to the bootstrap directory
cd OrgWideSession-IAC/bootstrap

# Initialize Terraform (uses local state — intentional for bootstrap)
terraform init

# Preview what will be created
terraform plan

# Create the resources (type "yes" when prompted)
terraform apply
```

Expected output:
```
Apply complete! Resources: 3 added, 0 changed, 0 destroyed.
```

This creates:
- S3 bucket: `orgwidesession-terraform-state` (stores all Terraform state files)
- DynamoDB table: `orgwidesession-terraform-locks` (prevents concurrent applies)

> **If the bucket name is already taken:** S3 bucket names are globally unique across all AWS accounts. If `orgwidesession-terraform-state` is taken, choose a different name and update it in:
> - `bootstrap/main.tf`
> - `environments/dev/backend.tf`
> - `environments/prod/backend.tf`
> - GitHub Secret `TF_BACKEND_BUCKET` (configured in the next step)

---

### 4.3 Step 2 — Configure GitHub Secrets

Secrets are encrypted values stored in GitHub that are injected as environment variables into workflow runs. **Credentials never appear in your code.**

#### Where to go

```
GitHub → Your repository (OrgWideSession-IAC)
  → Settings (top navigation tab)
    → Secrets and variables (left sidebar)
      → Actions
        → New repository secret (green button)
```

#### Secrets to create

Create all 6 secrets listed below. For each one:
1. Click **New repository secret**
2. Enter the **Name** exactly as shown (case-sensitive)
3. Paste the **Value**
4. Click **Add secret**

---

**Secret 1: `AWS_ACCESS_KEY_ID_DEV`**
- **Name:** `AWS_ACCESS_KEY_ID_DEV`
- **Value:** The Access Key ID from your dev IAM credentials
- **Example:** `AKIAIOSFODNN7EXAMPLE`
- **Used when:** Branch = `development` (dev deployments)

---

**Secret 2: `AWS_SECRET_ACCESS_KEY_DEV`**
- **Name:** `AWS_SECRET_ACCESS_KEY_DEV`
- **Value:** The Secret Access Key from your dev IAM credentials
- **Example:** `wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY`
- **Used when:** Branch = `development` (dev deployments)

---

**Secret 3: `AWS_ACCESS_KEY_ID_PROD`**
- **Name:** `AWS_ACCESS_KEY_ID_PROD`
- **Value:** The Access Key ID from your prod IAM credentials
- **Note:** For initial setup you can use the same credentials as dev. In production, use a separate IAM user with restricted permissions.
- **Used when:** Branch = `main` (prod deployments)

---

**Secret 4: `AWS_SECRET_ACCESS_KEY_PROD`**
- **Name:** `AWS_SECRET_ACCESS_KEY_PROD`
- **Value:** The Secret Access Key from your prod IAM credentials
- **Used when:** Branch = `main` (prod deployments)

---

**Secret 5: `TF_BACKEND_BUCKET`**
- **Name:** `TF_BACKEND_BUCKET`
- **Value:** `orgwidesession-terraform-state`
- **Note:** This is the name of the S3 bucket you created in Step 1. Change it if you used a different name.
- **Used when:** Every Terraform init (both environments)

---

**Secret 6: `TF_BACKEND_DYNAMODB_TABLE`**
- **Name:** `TF_BACKEND_DYNAMODB_TABLE`
- **Value:** `orgwidesession-terraform-locks`
- **Note:** This is the DynamoDB table you created in Step 1.
- **Used when:** Every Terraform init (both environments)

---

After creating all 6 secrets, your Secrets page should show:

```
Repository secrets (6)
  AWS_ACCESS_KEY_ID_DEV         Updated just now
  AWS_ACCESS_KEY_ID_PROD        Updated just now
  AWS_SECRET_ACCESS_KEY_DEV     Updated just now
  AWS_SECRET_ACCESS_KEY_PROD    Updated just now
  TF_BACKEND_BUCKET             Updated just now
  TF_BACKEND_DYNAMODB_TABLE     Updated just now
```

---

### 4.4 Step 3 — Create GitHub Environments

GitHub Environments allow you to attach approval requirements to specific deployment jobs. The `apply` job in the workflow uses `environment: name: dev` or `environment: name: prod` dynamically — GitHub matches this to the environment you configure here.

#### Where to go

```
GitHub → OrgWideSession-IAC repository
  → Settings
    → Environments (left sidebar)
      → New environment (button)
```

#### Create the `dev` environment

1. Click **New environment**
2. **Name:** `dev`
3. Click **Configure environment**
4. Under **Deployment branches and tags**, select **No restriction** (any branch can deploy to dev)
5. Leave **Required reviewers** empty (dev applies automatically after merge)
6. Click **Save protection rules**

#### Create the `prod` environment

1. Click **New environment**
2. **Name:** `prod`
3. Click **Configure environment**
4. Under **Required reviewers:**
   - Click **Add required reviewers**
   - Search for and add your team leads or senior engineers
   - At least one of these people must approve before the apply job runs
5. Under **Deployment branches and tags:**
   - Select **Selected branches and tags**
   - Click **Add deployment branch or tag rule**
   - Pattern: `main`
   - This ensures prod can only be deployed from the `main` branch
6. Click **Save protection rules**

> **What happens if prod has no required reviewers?** The apply job runs immediately after merge without any human approval — meaning infrastructure changes go live automatically. Always add required reviewers for prod before merging any changes to `main`.

---

### 4.5 Step 4 — Set Branch Protection Rules

Branch protection prevents direct pushes and enforces CI checks before merging.

#### Where to go

```
GitHub → OrgWideSession-IAC repository
  → Settings
    → Branches (left sidebar)
      → Add branch protection rule (button)
```

#### Protect `development`

1. **Branch name pattern:** `development`
2. Enable: **Require a pull request before merging**
   - Set "Required approvals" to `1`
3. Enable: **Require status checks to pass before merging**
   - Click **Add checks** and search for:
     - `Validate`
     - `Plan`
   - Enable **Require branches to be up to date before merging**
4. Click **Create**

#### Protect `main`

1. **Branch name pattern:** `main`
2. Enable: **Require a pull request before merging**
   - Set "Required approvals" to `1` (or more for prod)
3. Enable: **Require status checks to pass before merging**
   - Add: `Validate`, `Plan`
4. Enable: **Do not allow bypassing the above settings**
   - This enforces the rules even for repository administrators
5. Click **Create**

---

### 4.6 Step 5 — Deploy to Dev (First Run)

Now everything is configured. Follow these steps to trigger your first dev deployment.

**Step 5.1 — Verify you are on the `development` branch**
```bash
cd OrgWideSession-IAC
git checkout development
git pull origin development
```

**Step 5.2 — Create a feature branch**
```bash
git checkout -b feature/initial-dev-infrastructure
```

**Step 5.3 — Make a small change to trigger the pipeline**

Open `environments/dev/terraform.tfvars` and add a comment or tweak a tag value — any change triggers the CI pipeline:

```hcl
tags = {
  Environment = "dev"
  Project     = "OrgWideSession"
  ManagedBy   = "Terraform"
  Owner       = "platform-team"
  InitialDeploy = "true"       # ← add this line
}
```

**Step 5.4 — Commit and push**
```bash
git add environments/dev/terraform.tfvars
git commit -m "feat: initial dev infrastructure deployment"
git push origin feature/initial-dev-infrastructure
```

**Step 5.5 — Open a Pull Request**

1. Go to **GitHub → OrgWideSession-IAC → Pull requests → New pull request**
2. **Base branch:** `development`
3. **Compare branch:** `feature/initial-dev-infrastructure`
4. Click **Create pull request**

**Step 5.6 — Watch the CI pipeline run**

Go to the **Actions** tab. You will see "Terraform — Unified" running with three jobs:
- `Setup — Detect Environment` (reads branch = `development`, sets environment = `dev`)
- `Validate` (runs fmt check + validate against `environments/dev/`)
- `Plan` (runs terraform plan, posts output as a PR comment)

The PR comment will look like:
```
### Terraform Plan — DEV Environment
# aws_s3_bucket.this will be created
+ resource "aws_s3_bucket" "this" {
    + bucket = "dev-orgwidesession-app-assets"
    ...
  }

Plan: 5 to add, 0 to change, 0 to destroy.
```

**Step 5.7 — Review the plan and merge**

Review the plan comment. Confirm:
- Bucket name is `dev-orgwidesession-app-assets` (environment prefix is correct)
- Plan shows `5 to add` (bucket + public access block + versioning + encryption + lifecycle)
- No unexpected destroys

Get approval from a teammate, then merge the PR into `development`.

**Step 5.8 — Apply runs automatically**

After merge, GitHub triggers the workflow again on the push event. This time the `apply` job runs (it was skipped on the PR event). The dev GitHub Environment has no required reviewers so it applies immediately.

Watch it in **Actions → the latest run → apply job**. You should see:
```
Terraform Apply

aws_s3_bucket.this: Creating...
aws_s3_bucket.this: Creation complete after 2s [id=dev-orgwidesession-app-assets]
...

Apply complete! Resources: 5 added, 0 changed, 0 destroyed.
```

---

### 4.7 Step 6 — Deploy to Prod (First Run)

Prod deploys happen by merging `development` into `main`.

**Step 6.1 — Update prod configuration if needed**

Open `environments/prod/terraform.tfvars` and ensure values are correct for production. The `name_suffix` should match dev (the module + environment prefix ensures isolation):

```hcl
environment        = "prod"
name_suffix        = "orgwidesession-app-assets"   # Same suffix — different env prefix = different bucket
versioning_enabled = true
```

Commit and push this to `development` first (via PR), then follow Step 6.2.

**Step 6.2 — Open a PR from `development` to `main`**

1. Go to **Pull requests → New pull request**
2. **Base branch:** `main`
3. **Compare branch:** `development`
4. Title: `deploy: promote dev infrastructure to prod`
5. Click **Create pull request**

The CI pipeline runs again. The `setup` job reads `github.base_ref = "main"` and sets `environment = "prod"`. The plan runs against `environments/prod/` and posts a prod plan to the PR.

**Step 6.3 — Review the prod plan carefully**

The prod plan comment will show:
```
### Terraform Plan — PROD Environment
# aws_s3_bucket.this will be created
+ resource "aws_s3_bucket" "this" {
    + bucket = "prod-orgwidesession-app-assets"
    ...
  }

Plan: 5 to add, 0 to change, 0 to destroy.
```

Confirm the bucket name is `prod-orgwidesession-app-assets`. Check there are zero unexpected destroys.

**Step 6.4 — Merge the PR**

After review, merge the PR into `main`. The push event triggers the workflow.

**Step 6.5 — Approve the prod deployment**

The `apply` job starts but **pauses** at the prod environment gate. GitHub sends a notification to the required reviewers you configured in Step 3.

To approve:
1. Go to **Actions → the running workflow**
2. Click **Review deployments**
3. Check the box next to `prod`
4. Click **Approve and deploy**

The apply runs and creates:
- Bucket: `prod-orgwidesession-app-assets` (with versioning enabled, encryption on, public access blocked)

---

### 4.8 Verify in AWS Console

After each deployment, verify in AWS:

1. Open [AWS Console](https://console.aws.amazon.com) → **S3**
2. Search for `orgwidesession-app-assets`
3. You should see both buckets:
   - `dev-orgwidesession-app-assets`
   - `prod-orgwidesession-app-assets`
4. Click each bucket and check:
   - **Properties tab:** Server-side encryption = Enabled (AES-256)
   - **Permissions tab:** Block all public access = On (all four toggles)
   - **Management tab:** Lifecycle rules = expire-old-versions

**Check Terraform outputs locally:**
```bash
cd environments/dev
terraform output
# bucket_id              = "dev-orgwidesession-app-assets"
# bucket_arn             = "arn:aws:s3:::dev-orgwidesession-app-assets"
# bucket_regional_domain = "dev-orgwidesession-app-assets.s3.us-east-1.amazonaws.com"
```

---

### 4.9 Troubleshooting Common Errors

#### Error: `BucketAlreadyExists` or `BucketAlreadyOwnedByYou`

S3 bucket names are globally unique. Someone else already owns a bucket with that name.

**Fix:** Change `name_suffix` in `terraform.tfvars` to something unique to your organization. Update the bootstrap bucket name too if it was also taken.

---

#### Error: `Error acquiring the state lock`

```
Error: Error acquiring the state lock
Lock Info:
  ID: xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
```

Another Terraform process is running (or a previous run crashed without releasing the lock).

**Fix:** If no other process is running, manually delete the lock:
```bash
terraform force-unlock <lock-id-from-error-message>
```
In GitHub Actions, cancel any stuck workflow run first.

---

#### Error: `Error: No valid credential sources found`

Terraform cannot find AWS credentials.

**Fix — in CI:** Check that all 6 GitHub Secrets are created correctly and named exactly as specified. The secret names are case-sensitive.

**Fix — locally:** Run `aws configure` and verify with `aws sts get-caller-identity`.

---

#### Error: `terraform fmt` check fails in CI

```
Error: Files not formatted correctly. Run 'terraform fmt -recursive' to fix.
```

**Fix:** Run locally before committing:
```bash
terraform fmt -recursive
git add -A
git commit -m "fix: format terraform files"
git push
```

---

#### Error: `The specified backend does not match`

```
Error: Backend configuration changed
The previously-used backend configuration is now different.
```

The backend config in `backend.tf` changed. Terraform needs you to confirm the migration.

**Fix:** Run `terraform init -reconfigure` locally in the affected environment directory.

---

#### CI runs but no jobs appear for my push

The workflow has `paths` filters — it only triggers when files under `environments/**` or `modules/**` change. If you pushed a change to `README.md` or another file, no workflow runs.

**Fix:** Make any small change to a file under `environments/dev/` or `environments/prod/`.

---

## 5. End-to-End Deployment Flow

```
Developer           development branch          main branch          AWS
──────────          ─────────────────          ───────────          ────
    │                       │                       │                 │
    │  1. Create feature     │                       │                 │
    │     branch from       │                       │                 │
    │     development        │                       │                 │
    │                       │                       │                 │
    │  2. Make Terraform     │                       │                 │
    │     changes           │                       │                 │
    │                       │                       │                 │
    │  3. Open PR to ────────▶                      │                 │
    │     development        │                       │                 │
    │                       │  setup: env=dev       │                 │
    │                       │  validate + plan ─────────────────────────▶ Read dev state
    │◀──────────────────────│  plan posted to PR    │                 │
    │  (review plan)        │                       │                 │
    │                       │                       │                 │
    │  4. Merge PR ──────────▶                      │                 │
    │                       │  apply (no approval   │                 │
    │                       │  gate for dev) ────────────────────────────▶ dev-orgwidesession-app-assets
    │                       │                       │                 │   created in S3
    │                       │                       │                 │
    │  5. Open PR to ────────────────────────────────▶               │
    │     main              │                       │                 │
    │                       │                       │  setup: env=prod│
    │                       │                       │  validate + plan──▶ Read prod state
    │◀──────────────────────────────────────────────│  plan to PR     │
    │  (review prod plan)   │                       │                 │
    │                       │                       │                 │
    │  6. Merge PR ───────────────────────────────────▶              │
    │                       │                       │  apply PAUSED   │
    │                       │                       │  (waiting for   │
    │                       │                       │  prod approval) │
    │                       │                       │                 │
    │  7. Reviewer ───────────────────────────────────▶ APPROVE      │
    │     approves          │                       │                 │
    │                       │                       │  apply runs ────────▶ prod-orgwidesession-app-assets
    │                       │                       │                 │   created in S3
    └───────────────────────┴───────────────────────┴─────────────────┘
```

---

## 6. Unified vs Two-Workflow Comparison

| Aspect | Unified Workflow (this guide) | Two-Workflow Approach (TERRAFORM_CICD_GUIDE.md) |
|---|---|---|
| **Number of YAML files** | 1 (`terraform.yml`) | 2 (`terraform-dev.yml`, `terraform-prod.yml`) |
| **Code duplication** | None — shared logic in one place | ~80% of each file is identical |
| **Readability** | More complex — requires tracing job outputs | Simpler — each file is self-contained |
| **Branch model** | Branch = environment | Both envs deploy off `main` |
| **Path filtering** | Broad (`environments/**`) | Precise per env (`environments/dev/**`) |
| **Debugging** | Trace setup outputs | All values are explicit |
| **Adding environments** | One `elif` in setup job | One new complete workflow file |

**Use the unified workflow** when your branch model maps one branch per environment and you want to maintain a single YAML file.

**Use the two-workflow approach** when you want maximum explicitness, or when different environments need significantly different CI logic.

---

*For deep explanations of Terraform concepts, state management, and AWS authentication options, see [TERRAFORM_CICD_GUIDE.md](./TERRAFORM_CICD_GUIDE.md).*
