# Terraform + GitHub Actions: From Zero to Production
## A Progressive Learning Guide for AWS Infrastructure as Code

> **Audience:** Developers with no prior Terraform experience through to teams building production CI/CD pipelines.
>
> **Progression:** Beginner → Intermediate → Advanced → Production-grade
>
> **Scope:** S3-based AWS infrastructure managed with Terraform, automated via GitHub Actions CI/CD, for the `OrgWideSession-IAC` repository.

---

## Table of Contents

1. [Part 1: Foundations — Your First Terraform Configuration](#part-1-foundations--your-first-terraform-configuration)
   - [1.1 What is Terraform and Why Use It?](#11-what-is-terraform-and-why-use-it)
   - [1.2 Installing Terraform](#12-installing-terraform)
   - [1.3 Core Concepts](#13-core-concepts)
   - [1.4 Core Commands](#14-core-commands)
   - [1.5 Your First Configuration (Hands-On)](#15-your-first-configuration-hands-on)
   - [1.6 Understanding Plan Output](#16-understanding-plan-output)

2. [Part 2: Structuring a Real Project — Modules and Environments](#part-2-structuring-a-real-project--modules-and-environments)
   - [2.1 Why Structure Matters](#21-why-structure-matters)
   - [2.2 Project Layout](#22-project-layout)
   - [2.3 Reusable Modules — The Building Blocks](#23-reusable-modules--the-building-blocks)
   - [2.4 Environment Configurations (Dev and Prod)](#24-environment-configurations-dev-and-prod)
   - [2.5 Environment Design Decisions](#25-environment-design-decisions)

3. [Part 3: State Management — Terraform's Memory](#part-3-state-management--terraforms-memory)
   - [3.1 What is State and Why Does It Matter?](#31-what-is-state-and-why-does-it-matter)
   - [3.2 Local State vs Remote State](#32-local-state-vs-remote-state)
   - [3.3 Remote State with S3 + DynamoDB](#33-remote-state-with-s3--dynamodb)
   - [3.4 State Isolation Per Environment](#34-state-isolation-per-environment)
   - [3.5 Common State Operations](#35-common-state-operations)

4. [Part 4: Deploying to AWS — S3 in Context](#part-4-deploying-to-aws--s3-in-context)
   - [4.1 Why S3 as Our Primary Example](#41-why-s3-as-our-primary-example)
   - [4.2 AWS Authentication for Terraform](#42-aws-authentication-for-terraform)
   - [4.3 The S3 Module Deep Dive](#43-the-s3-module-deep-dive)

5. [Part 5: Automating with GitHub Actions CI/CD](#part-5-automating-with-github-actions-cicd)
   - [5.1 Why Automate Terraform?](#51-why-automate-terraform)
   - [5.2 GitHub Secrets Configuration](#52-github-secrets-configuration)
   - [5.3 Dev Environment Workflow](#53-dev-environment-workflow-terraform-devyml)
   - [5.4 Prod Environment Workflow](#54-prod-environment-workflow-terraform-prodyml)
   - [5.5 Drift Detection Workflow](#55-drift-detection-workflow)

6. [Part 6: The Complete Lifecycle — End to End](#part-6-the-complete-lifecycle--end-to-end)
   - [6.1 From Code to Infrastructure (Flow Diagram)](#61-from-code-to-infrastructure-flow-diagram)
   - [6.2 Key Decision Points](#62-key-decision-points)
   - [6.3 Developer Workflow Checklist](#63-developer-workflow-checklist)

7. [Part 7: Best Practices, Pitfalls, and Reference](#part-7-best-practices-pitfalls-and-reference)
   - [7.1 Safe Deployment Practices](#71-safe-deployment-practices)
   - [7.2 Common Pitfalls](#72-common-pitfalls)
   - [7.3 Code Review Checklist for Terraform PRs](#73-code-review-checklist-for-terraform-prs)
   - [7.4 Quick Reference: Local Commands](#74-quick-reference-local-commands)
   - [7.5 Glossary](#75-glossary)

---

# Part 1: Foundations — Your First Terraform Configuration

> **Level:** Beginner
> **Goal:** Understand what Terraform is, install it, learn the core concepts, and deploy your first real resource to AWS.

---

## 1.1 What is Terraform and Why Use It?

### What

Terraform is an open-source **Infrastructure as Code (IaC)** tool created by HashiCorp. It lets you describe your infrastructure — servers, databases, storage buckets, networking rules — in configuration files, and then automatically creates, updates, or deletes that infrastructure to match your description.

The configuration language is called **HCL (HashiCorp Configuration Language)**. It is declarative: you describe the *desired end state*, not the steps to get there. Terraform figures out the steps.

### Why

Before IaC tools like Terraform, infrastructure was managed by clicking around in the AWS Console (or running manual CLI commands). This approach has serious problems:

| Problem | Manual Console | Terraform |
|---|---|---|
| **Reproducibility** | Hard to recreate exactly | Config file creates identical infrastructure every time |
| **Auditability** | No record of who changed what | Every change is a git commit |
| **Team collaboration** | "It works on my account" | Shared, version-controlled configuration |
| **Disaster recovery** | Rebuilding from memory | Run `terraform apply` and infrastructure is restored |
| **Drift** | Easy to make undocumented changes | Declare desired state; Terraform enforces it |

### How it connects to OrgWideSession

OrgWideSession is a suite of three separate GitHub repositories: `OrgWideSession-BE` (Python/FastAPI backend), `OrgWideSession-FE` (React/TypeScript frontend), and `OrgWideSession-IAC` (this repository). Each repository has its own GitHub Actions CI/CD pipeline. Terraform lives in `OrgWideSession-IAC` and manages the AWS infrastructure underneath — S3 buckets for file storage, future resources like RDS databases or ECS services — that the other two applications run on.

Think of it this way: **GitHub Actions in `OrgWideSession-BE` and `OrgWideSession-FE` ship application code; Terraform in `OrgWideSession-IAC` provisions the AWS cloud resources those applications run on.**

---

## 1.2 Installing Terraform

### Install Terraform

**Windows (Chocolatey — recommended):**
```powershell
choco install terraform
```

**Windows (manual):**
1. Download the ZIP from the [Terraform releases page](https://developer.hashicorp.com/terraform/downloads)
2. Extract `terraform.exe`
3. Move it to a directory in your `PATH` (e.g., `C:\tools\`)

**macOS (Homebrew):**
```bash
brew tap hashicorp/tap
brew install hashicorp/tap/terraform
```

**Linux (Ubuntu/Debian):**
```bash
wget -O- https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt update && sudo apt install terraform
```

**Verify the installation:**
```bash
terraform -version
# Expected output: Terraform v1.x.x
```

### Install and Configure the AWS CLI

Terraform uses the AWS CLI's credential chain to authenticate with AWS.

```bash
# Install AWS CLI (macOS/Linux)
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip && sudo ./aws/install

# Configure with your IAM credentials
aws configure
# AWS Access Key ID [None]: AKIAIOSFODNN7EXAMPLE
# AWS Secret Access Key [None]: wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY
# Default region name [None]: us-east-1
# Default output format [None]: json

# Verify
aws sts get-caller-identity
```

> **Where to get credentials:** In the AWS Console, go to IAM → Users → Your user → Security credentials → Create access key. Use "CLI" as the use case.

---

## 1.3 Core Concepts

Before writing any Terraform code, you need to understand five foundational concepts. Each one builds on the previous.

---

### Providers

**What:** A provider is a plugin that connects Terraform to a specific cloud or service API. The AWS provider translates your HCL config into AWS API calls (CreateBucket, PutBucketPolicy, etc.).

**Why:** Terraform itself is cloud-agnostic — it is a generic engine. Providers contain all the cloud-specific knowledge. The same Terraform workflow works whether you are deploying to AWS, Azure, GCP, or even GitHub or Datadog.

**How:**
```hcl
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"   # Official AWS provider on the Terraform Registry
      version = "~> 5.0"         # Allow any 5.x.x version
    }
  }
}

provider "aws" {
  region = "us-east-1"   # Credentials come from the AWS CLI config or environment variables
}
```

When you run `terraform init`, Terraform downloads the specified provider plugin into the `.terraform/` directory.

---

### Resources

**What:** A resource is the fundamental building block — it represents a single piece of infrastructure. One `resource` block = one AWS object (one S3 bucket, one EC2 instance, one IAM role, etc.).

**Why:** Resources are how you tell Terraform what to create. The resource type (e.g., `aws_s3_bucket`) determines which AWS service API is called.

**How:**
```hcl
# Syntax: resource "<TYPE>" "<LOCAL_NAME>" { ... }
# TYPE comes from the provider (aws_s3_bucket is from the AWS provider)
# LOCAL_NAME is how you reference this resource within your Terraform code

resource "aws_s3_bucket" "my_bucket" {
  bucket = "my-org-unique-bucket-name"   # The actual AWS resource name
}
```

After applying, you can reference this bucket's ID in other resources with `aws_s3_bucket.my_bucket.id`.

---

### Variables

**What:** Variables are inputs that make your configuration reusable and environment-aware. Instead of hardcoding `"my-org-app-assets-dev"` everywhere, you declare a variable and pass the value in.

**Why:** Without variables, you would need a separate configuration file for every environment. Variables let one configuration serve dev, staging, and prod by just changing the input values.

**How — declare in `variables.tf`:**
```hcl
variable "bucket_name" {
  description = "Globally unique name for the S3 bucket"
  type        = string
  # No default — caller must always provide this
}

variable "environment" {
  description = "Deployment environment"
  type        = string
  default     = "dev"   # If caller doesn't provide it, "dev" is used
}
```

**How — supply values (three ways):**
```bash
# Way 1: terraform.tfvars file (most common)
# bucket_name = "my-org-app-assets-dev"

# Way 2: -var flag at the command line
terraform apply -var="bucket_name=my-org-app-assets-dev"

# Way 3: Environment variable (TF_VAR_ prefix)
export TF_VAR_bucket_name="my-org-app-assets-dev"
```

---

### Outputs

**What:** Outputs are values that Terraform exposes after a successful `apply`. They are like the "return values" of your configuration.

**Why:** You often need to know what Terraform created — the bucket's ARN to put in an IAM policy, a server's IP address to update a DNS record, a database endpoint to pass to an application. Outputs surface these values.

**How:**
```hcl
output "bucket_arn" {
  description = "ARN of the bucket — use this in IAM policies"
  value       = aws_s3_bucket.my_bucket.arn
}
```

After `terraform apply`, you see:
```
Outputs:
bucket_arn = "arn:aws:s3:::my-org-unique-bucket-name"
```

You can also retrieve outputs later: `terraform output bucket_arn`

---

### State

**What:** Terraform's state is a file (`terraform.tfstate`) that records everything Terraform has created. It maps your configuration's resource names to the real AWS resource IDs.

**Why:** Without state, Terraform would not know what already exists. Every `apply` would try to create everything from scratch. State is what allows Terraform to calculate the *difference* between what exists and what you want — and only make the necessary changes.

**How it works conceptually:**
```
Your config  ──→  terraform plan  ←──  Current state file
(desired)                              (what exists)
                     │
                     ▼
              Shows the diff:
              + resources to create
              ~ resources to modify
              - resources to destroy
                     │
              terraform apply
                     │
                     ▼
              Executes the diff
              Updates state file
```

> **Important:** State is sensitive — it may contain secrets. Never commit `terraform.tfstate` to git. See Part 3 for the full deep dive on state management.

---

### Data Sources (Brief Introduction)

**What:** Data sources let you read information about existing infrastructure that Terraform does not manage. They are read-only lookups.

**Why:** Sometimes you need to reference a resource that was created outside of Terraform (by another team, another tool, or manually). Data sources let you look it up without taking ownership of it.

**How:**
```hcl
# Look up the current AWS account ID without hardcoding it
data "aws_caller_identity" "current" {}

output "account_id" {
  value = data.aws_caller_identity.current.account_id
}
```

Data sources are not required for the beginner walkthrough — they are introduced here so the terminology is familiar when you encounter them.

---

## 1.4 Core Commands

These are the six commands you will use every day. Understand what each does, when to use it, and what it does NOT do.

---

### Command Lifecycle

```
terraform init
    │
    ▼
terraform plan      ◄── Safe, read-only. Run this as many times as you want.
    │
    ▼
terraform apply     ◄── Modifies real infrastructure. Always review the plan first.
    │
    ▼
terraform destroy   ◄── Destroys everything. Rarely used in production.
```

---

### `terraform init`

**What it does:** Downloads providers, initializes the backend (configures where state is stored), and installs any modules referenced in the config.

**Analogy:** Like `npm install` — it prepares the environment to run your code.

**When to run it:** Once when you first clone a project, and again whenever you:
- Add or change a provider
- Change the backend configuration
- Add a new module

```bash
terraform init

# Output (abbreviated):
# Initializing the backend...
# Initializing provider plugins...
# - Finding hashicorp/aws versions matching "~> 5.0"...
# - Installing hashicorp/aws v5.31.0...
# Terraform has been successfully initialized!
```

---

### `terraform plan`

**What it does:** Connects to AWS, reads current state, compares it to your config, and shows a diff of what would change — without changing anything.

**Analogy:** Like a code review before merging — you see every change before it happens.

**When to run it:** Before every apply. Also run it frequently during development to catch mistakes early.

```bash
terraform plan

# Shows: resources to add (+), modify (~), or destroy (-)
# Plan: 3 to add, 0 to change, 0 to destroy.
```

---

### `terraform apply`

**What it does:** Executes the changes shown by `plan`. Prompts for confirmation (unless `-auto-approve` is passed).

**When to run it:** After reviewing the plan and confirming the changes are correct.

```bash
terraform apply

# Terraform shows the plan again, then asks:
# Do you want to perform these actions?
#   Terraform will perform the actions described above.
#   Only 'yes' will be accepted to approve.
#
# Enter a value: yes
```

> **Rule:** Never use `-auto-approve` locally when working against prod. Use it only in CI/CD pipelines where the plan has already been reviewed.

---

### `terraform destroy`

**What it does:** Destroys all resources managed by the current configuration in the current directory.

**When to run it:** When tearing down a temporary environment (dev sandbox, test environment). Almost never in production.

```bash
terraform destroy

# Shows everything that will be deleted, then asks:
# Do you really want to destroy all resources?
# Enter a value: yes
```

> **Warning:** This is irreversible for most resource types. Always double-check you are in the correct directory before running destroy.

---

### `terraform fmt`

**What it does:** Automatically formats all `.tf` files in the current directory to canonical HCL style (consistent indentation, alignment).

**When to run it:** Before committing code. Can also run with `-recursive` to format subdirectories.

```bash
terraform fmt -recursive
```

---

### `terraform validate`

**What it does:** Checks the configuration for syntax errors and internal consistency. Does NOT connect to AWS — it only reads the config files.

**When to run it:** During development to catch typos and errors fast, before running `plan`.

```bash
terraform validate
# Success! The configuration is valid.
```

---

## 1.5 Your First Configuration (Hands-On)

Let's write a minimal Terraform configuration that creates an S3 bucket in AWS. You will follow each step, understand every line, and end with a real resource deployed (then cleaned up).

> **Note:** This intentionally simple config puts everything in one file. In Part 2, you will refactor this into a production-ready structure with modules and environments.

### Step 1: Create a Working Directory

```bash
mkdir terraform-first-steps
cd terraform-first-steps
```

### Step 2: Create `main.tf`

Create a file called `main.tf` with this content:

```hcl
# main.tf — A minimal Terraform configuration.
# This is the simplest possible Terraform file that creates a real AWS resource.

# The terraform block configures Terraform itself (not AWS).
# required_providers tells Terraform which plugins to download.
terraform {
  required_version = ">= 1.5.0"   # Ensure we have a recent-enough Terraform binary

  required_providers {
    aws = {
      source  = "hashicorp/aws"   # Download from registry.terraform.io/hashicorp/aws
      version = "~> 5.0"         # Use any 5.x release (not 4.x, not 6.x)
    }
  }
}

# The provider block configures the AWS provider.
# Terraform reads credentials from:
#   1. AWS_ACCESS_KEY_ID / AWS_SECRET_ACCESS_KEY environment variables
#   2. ~/.aws/credentials (set by `aws configure`)
# Never hardcode credentials here.
provider "aws" {
  region = "us-east-1"
}

# The resource block creates an S3 bucket.
# "aws_s3_bucket" is the resource type (from the AWS provider).
# "my_first_bucket" is a local name — used only within this config.
resource "aws_s3_bucket" "my_first_bucket" {
  # bucket = the actual name on AWS. Must be globally unique across ALL AWS accounts.
  # Replace "your-name" with something unique to you.
  bucket = "terraform-first-steps-your-name-2024"

  # Tags are key-value metadata attached to AWS resources.
  # Good practice: always tag who manages the resource and why.
  tags = {
    Name      = "My First Terraform Bucket"
    ManagedBy = "Terraform"
  }
}

# An output exposes a value after apply completes.
# Useful for seeing what was created without digging through AWS Console.
output "bucket_name" {
  description = "The name of the S3 bucket that was created"
  value       = aws_s3_bucket.my_first_bucket.id
}

output "bucket_arn" {
  description = "The ARN of the bucket — needed for IAM policies"
  value       = aws_s3_bucket.my_first_bucket.arn
}
```

### Step 3: Initialize

```bash
terraform init
```

Terraform downloads the AWS provider plugin into `.terraform/`. You should see:
```
Terraform has been successfully initialized!
```

### Step 4: Plan

```bash
terraform plan
```

Terraform connects to AWS (using your credentials), checks what exists, and shows what it will create:
```
Terraform will perform the following actions:

  # aws_s3_bucket.my_first_bucket will be created
  + resource "aws_s3_bucket" "my_first_bucket" {
      + bucket = "terraform-first-steps-your-name-2024"
      + tags   = {
          + "ManagedBy" = "Terraform"
          + "Name"      = "My First Terraform Bucket"
        }
      ...
    }

Plan: 1 to add, 0 to change, 0 to destroy.
```

Read this output carefully. The `+` prefix means "will be created."

### Step 5: Apply

```bash
terraform apply
```

Terraform shows the plan again and asks for confirmation. Type `yes`:
```
Do you want to perform these actions?
  Enter a value: yes

aws_s3_bucket.my_first_bucket: Creating...
aws_s3_bucket.my_first_bucket: Creation complete after 2s

Apply complete! Resources: 1 added, 0 changed, 0 destroyed.

Outputs:
bucket_arn  = "arn:aws:s3:::terraform-first-steps-your-name-2024"
bucket_name = "terraform-first-steps-your-name-2024"
```

**Verify:** Open the AWS Console → S3 → you should see your bucket.

Notice that a `terraform.tfstate` file was created in your directory. This is Terraform's state file — it records that it created this bucket.

### Step 6: Make a Change

Edit `main.tf` and add a tag:
```hcl
tags = {
  Name        = "My First Terraform Bucket"
  ManagedBy   = "Terraform"
  Environment = "learning"   # ← new tag
}
```

Run `terraform plan` again:
```
  ~ resource "aws_s3_bucket" "my_first_bucket" {
        id     = "terraform-first-steps-your-name-2024"
      ~ tags   = {
          + "Environment" = "learning"
            # (2 unchanged elements hidden)
        }
    }

Plan: 0 to add, 1 to change, 0 to destroy.
```

The `~` prefix means "will be modified." Apply to make the change.

### Step 7: Destroy (Cleanup)

When done, clean up:
```bash
terraform destroy
```

Type `yes`. Terraform deletes the bucket and removes it from state.

> **What you learned:** Terraform follows a consistent init → plan → apply cycle for every change. The plan is always shown before anything is executed.

---

## 1.6 Understanding Plan Output

The plan output uses three symbols that tell you exactly what will happen:

| Symbol | Meaning | Risk |
|--------|---------|------|
| `+` | Resource will be **created** | Low |
| `~` | Resource will be **modified in-place** | Medium |
| `-` | Resource will be **destroyed** | High |
| `-/+` | Resource will be **destroyed and recreated** | High — causes downtime |

### Sample Plan Output Explained

```
Terraform will perform the following actions:

  # aws_s3_bucket.app_bucket will be created
  + resource "aws_s3_bucket" "app_bucket" {
      + bucket                      = "my-org-app-assets-dev"
      + id                          = (known after apply)    # ← not known yet
      + arn                         = (known after apply)
      + tags                        = {
          + "Environment" = "dev"
          + "ManagedBy"   = "Terraform"
        }
    }

  # aws_s3_bucket_versioning.app_bucket will be created
  + resource "aws_s3_bucket_versioning" "app_bucket" {
      ...
    }

Plan: 4 to add, 0 to change, 0 to destroy.
```

**Reading guidelines:**

- `(known after apply)` — AWS generates this value (like a bucket ARN); Terraform cannot know it until creation.
- Values showing no change are hidden by default; use `terraform plan -no-color | grep -v "#"` to see all attributes.
- **Always search the plan output for the word "destroy"** — any `-` lines deserve careful scrutiny.

> **Golden rule:** If you see `-` (destroy) or `-/+` (destroy + recreate) for a resource you did not intend to delete, **stop and investigate** before applying.

---

# Part 2: Structuring a Real Project — Modules and Environments

> **Level:** Intermediate
> **Goal:** Refactor from a single-file config into a production-grade structure that supports multiple environments, reusable components, and team collaboration.

---

## 2.1 Why Structure Matters

The single-file configuration from Part 1 works fine for one person experimenting. But it breaks down quickly in the real world:

**Problem 1 — Multiple environments:** You need dev and prod. You could copy-paste the entire file, but now changes need to be made in two places. When they drift apart, bugs happen.

**Problem 2 — Team collaboration:** Multiple engineers working on the same config need a predictable structure. Without one, every engineer organizes files differently.

**Problem 3 — DRY violations:** If you have three S3 buckets with the same configuration (encryption, public access block, versioning), repeating those 40 lines three times is error-prone. One missed update = inconsistency.

**Problem 4 — Blast radius:** A mistake in the dev config should not be able to accidentally affect prod infrastructure. With a flat structure, a wrong directory can cause catastrophic outcomes.

The solution is a **module + environment structure**: shared logic lives in modules, environment-specific values live in environment folders. Each environment has completely isolated state.

---

## 2.2 Project Layout

```
OrgWideSession-IAC/
├── modules/
│   └── s3/                        # Reusable S3 module — called by each environment
│       ├── main.tf                # S3 resource definitions
│       ├── variables.tf           # Input variables the module accepts
│       └── outputs.tf             # Values the module exposes to callers
│
├── environments/
│   ├── dev/                       # Dev environment root — has its own state
│   │   ├── main.tf                # Calls the s3 module with dev-specific values
│   │   ├── variables.tf           # Declares variables for dev
│   │   ├── terraform.tfvars       # Dev-specific variable values (bucket names, tags, etc.)
│   │   ├── outputs.tf             # Outputs surfaced after dev apply
│   │   └── backend.tf             # Dev remote state config (S3 + DynamoDB lock)
│   │
│   └── prod/                      # Prod environment root — completely separate state
│       ├── main.tf
│       ├── variables.tf
│       ├── terraform.tfvars
│       ├── outputs.tf
│       └── backend.tf
│
├── .github/
│   └── workflows/
│       ├── terraform-dev.yml      # CI/CD pipeline for dev environment
│       └── terraform-prod.yml     # CI/CD pipeline for prod environment
│
└── TERRAFORM_CICD_GUIDE.md        # This file
```

**Why this layout?**

- Each environment folder is its own Terraform **root module** — it has its own `backend.tf` and therefore its own **isolated state file**.
- The `modules/s3/` folder contains only reusable logic — no environment-specific values.
- GitHub Actions workflows are split per environment so `dev` and `prod` deployments are independent and have different approval gates.

---

## 2.3 Reusable Modules — The Building Blocks

### What is a Module?

A module is a directory containing Terraform configuration files. When another configuration calls it with `module "name" { source = "..." }`, Terraform treats it as a reusable component — like a function that accepts input variables and returns output values.

```
Caller (environments/dev/main.tf)
    │
    │  passes variables:
    │  - bucket_name = "my-org-app-assets-dev"
    │  - environment = "dev"
    │  - versioning_enabled = false
    ▼
Module (modules/s3/)
    │
    │  creates resources:
    │  - aws_s3_bucket
    │  - aws_s3_bucket_public_access_block
    │  - aws_s3_bucket_versioning
    │  - aws_s3_bucket_server_side_encryption_configuration
    │  - aws_s3_bucket_lifecycle_configuration
    │
    │  returns outputs:
    │  - bucket_id
    │  - bucket_arn
    │  - bucket_regional_domain
    ▼
Caller receives outputs: module.app_bucket.bucket_arn
```

### Why use Modules?

- **DRY:** Define the S3 configuration once. Call it from dev, prod, and any future environment.
- **Tested once, trusted everywhere:** A module with validation rules catches bad inputs regardless of which environment calls it.
- **Clear interface:** The module's `variables.tf` is its public API. Callers do not need to understand the internals.

---

### `modules/s3/variables.tf`

```hcl
# variables.tf — Defines the interface (API) of this module.
# Callers (dev/main.tf, prod/main.tf) must provide these values.

variable "bucket_name" {
  description = "Globally unique name for the S3 bucket"
  type        = string

  # Validation rule — S3 bucket names must be lowercase, no underscores
  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9\\-]{1,61}[a-z0-9]$", var.bucket_name))
    error_message = "Bucket name must be lowercase alphanumeric and hyphens only, 3-63 chars."
  }
}

variable "environment" {
  description = "Deployment environment (dev, prod)"
  type        = string

  validation {
    condition     = contains(["dev", "prod"], var.environment)
    error_message = "Environment must be one of: dev, prod."
  }
}

variable "versioning_enabled" {
  description = "Enable S3 object versioning"
  type        = bool
  default     = false
}

variable "tags" {
  description = "Tags to apply to the bucket"
  type        = map(string)
  default     = {}
}
```

---

### `modules/s3/main.tf`

```hcl
# main.tf — Defines the S3 bucket and its configuration.
# All AWS best-practice settings are applied here; callers only tune behavior via variables.

# The bucket itself — the foundational resource.
resource "aws_s3_bucket" "this" {
  bucket = var.bucket_name   # Must be globally unique across all AWS accounts

  tags = merge(
    var.tags,
    { Name = var.bucket_name }  # Always tag Name for console clarity
  )
}

# Block all public access — enabled by default for security.
# Override only if this is a public static website bucket.
resource "aws_s3_bucket_public_access_block" "this" {
  bucket = aws_s3_bucket.this.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Versioning — controlled by var.versioning_enabled.
# In prod, versioning protects against accidental deletes and enables point-in-time recovery.
resource "aws_s3_bucket_versioning" "this" {
  bucket = aws_s3_bucket.this.id

  versioning_configuration {
    # Ternary: if versioning_enabled is true, use "Enabled", otherwise "Suspended"
    status = var.versioning_enabled ? "Enabled" : "Suspended"
  }
}

# Server-side encryption — always enabled regardless of environment.
# Uses AWS-managed keys (SSE-S3). Switch to aws:kms for stricter key control.
resource "aws_s3_bucket_server_side_encryption_configuration" "this" {
  bucket = aws_s3_bucket.this.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"   # SSE-S3 (AWS-managed keys)
    }
    bucket_key_enabled = true    # Reduces KMS request costs if you later switch to KMS
  }
}

# Lifecycle rule — automatically clean up non-current (old) versions.
# Only meaningful when versioning is enabled; still safe to define when suspended.
resource "aws_s3_bucket_lifecycle_configuration" "this" {
  bucket = aws_s3_bucket.this.id

  # Dependency: lifecycle rules require versioning to be configured first
  depends_on = [aws_s3_bucket_versioning.this]

  rule {
    id     = "expire-old-versions"
    status = "Enabled"

    # After 30 days, old (non-current) versions are deleted.
    # In dev you can lower this; in prod raise it for longer recovery windows.
    noncurrent_version_expiration {
      noncurrent_days = 30
    }
  }
}
```

---

### `modules/s3/outputs.tf`

```hcl
# outputs.tf — Values this module exposes to its callers.
# Callers reference these as: module.app_bucket.bucket_id, etc.

output "bucket_id" {
  description = "The bucket name (same as ID in S3)"
  value       = aws_s3_bucket.this.id
}

output "bucket_arn" {
  description = "Full ARN of the bucket — used in IAM policy documents"
  value       = aws_s3_bucket.this.arn
}

output "bucket_regional_domain" {
  description = "Regional domain name — used as CloudFront origin domain"
  value       = aws_s3_bucket.this.bucket_regional_domain_name
}
```

---

## 2.4 Environment Configurations (Dev and Prod)

Each environment folder (`environments/dev/`, `environments/prod/`) is a **root module** — a self-contained Terraform configuration. It calls the shared `modules/s3/` module and passes environment-specific values.

The pattern: **define the infrastructure shape in the module; provide the environment-specific values in the caller.**

---

### `environments/dev/backend.tf`

```hcl
# backend.tf — Remote state configuration for the dev environment.
#
# Terraform state is stored in an S3 bucket and locked via DynamoDB.
# This prevents two engineers (or two CI runs) from applying simultaneously.
#
# IMPORTANT: The backend block does NOT support variables — all values must be
# literals or supplied via `-backend-config` flags at `terraform init` time.

terraform {
  backend "s3" {
    bucket         = "my-org-terraform-state"          # S3 bucket that holds all state files
    key            = "dev/s3/terraform.tfstate"        # Path within the bucket — unique per env
    region         = "us-east-1"                       # Region where the state bucket lives
    dynamodb_table = "my-org-terraform-locks"          # DynamoDB table for state locking
    encrypt        = true                              # Encrypt state at rest (always enable this)
  }
}
```

### `environments/prod/backend.tf`

```hcl
terraform {
  backend "s3" {
    bucket         = "my-org-terraform-state"
    key            = "prod/s3/terraform.tfstate"       # Different key = separate, isolated state
    region         = "us-east-1"
    dynamodb_table = "my-org-terraform-locks"
    encrypt        = true
  }
}
```

> **State isolation rule:** `dev` and `prod` always have different `key` values. This means a `terraform destroy` in `dev` has zero effect on `prod` state.

---

### `environments/dev/variables.tf`

```hcl
# variables.tf — Declares what variables this environment accepts.
# Actual values live in terraform.tfvars (never hardcoded here).

variable "aws_region" {
  description = "AWS region to deploy resources into"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Environment name — used in resource names and tags"
  type        = string
}

variable "bucket_name" {
  description = "Name of the S3 bucket to create"
  type        = string
}

variable "versioning_enabled" {
  description = "Whether to enable S3 object versioning"
  type        = bool
  default     = false   # Off by default; prod overrides this to true
}

variable "tags" {
  description = "Map of tags applied to all resources"
  type        = map(string)
  default     = {}
}
```

---

### `environments/dev/terraform.tfvars`

```hcl
# terraform.tfvars — Dev environment values.
# This file is committed to source control (no secrets here).
# Secrets (AWS credentials) come from environment variables or GitHub Secrets.

environment        = "dev"
bucket_name        = "my-org-app-assets-dev"      # Always suffix with env name
versioning_enabled = false                         # Dev doesn't need versioning overhead

tags = {
  Environment = "dev"
  Project     = "OrgWideSession"
  ManagedBy   = "Terraform"
  Owner       = "platform-team"
}
```

### `environments/prod/terraform.tfvars`

```hcl
environment        = "prod"
bucket_name        = "my-org-app-assets-prod"     # Separate bucket, separate lifecycle
versioning_enabled = true                          # Prod requires versioning for safety

tags = {
  Environment = "prod"
  Project     = "OrgWideSession"
  ManagedBy   = "Terraform"
  Owner       = "platform-team"
  CostCenter  = "engineering"
}
```

**Key differences between dev and prod tfvars:**

| Setting             | Dev                          | Prod                          |
|---------------------|------------------------------|-------------------------------|
| `bucket_name`       | `...-dev` suffix             | `...-prod` suffix             |
| `versioning_enabled`| `false`                      | `true`                        |
| Tags                | Minimal                      | Includes `CostCenter`         |

---

### `environments/dev/main.tf`

```hcl
# main.tf — Dev environment entry point.
# This file calls the reusable s3 module and passes dev-specific variable values.

terraform {
  required_version = ">= 1.5.0"   # Enforce minimum Terraform version

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"           # Pin to major version; allows patch/minor upgrades
    }
  }
}

# Provider block — credentials come from environment variables:
# AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY, AWS_SESSION_TOKEN
# Never hardcode credentials here.
provider "aws" {
  region = var.aws_region
}

# Call the reusable S3 module with dev-specific values.
# The module lives in ../../modules/s3 — a relative path from this file.
module "app_bucket" {
  source = "../../modules/s3"

  bucket_name        = var.bucket_name
  environment        = var.environment
  versioning_enabled = var.versioning_enabled
  tags               = var.tags
}
```

### `environments/prod/main.tf`

```hcl
# Identical structure to dev/main.tf — only the variable values differ (from tfvars).
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

  bucket_name        = var.bucket_name
  environment        = var.environment
  versioning_enabled = var.versioning_enabled
  tags               = var.tags
}
```

---

### `environments/dev/outputs.tf`

```hcl
# outputs.tf — Values surfaced after terraform apply completes.
# Useful for referencing resources in other systems or pipelines.

output "bucket_id" {
  description = "The name of the S3 bucket"
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

## 2.5 Environment Design Decisions

### Folder-Based Environments vs Terraform Workspaces

This guide uses **folder-based environments**. Here is an honest comparison:

| Aspect                        | Folder-Based Environments           | Terraform Workspaces                |
|-------------------------------|--------------------------------------|--------------------------------------|
| **State isolation**           | Complete — separate backend keys     | Partial — same backend, different workspace prefix |
| **Configuration differences** | Full freedom (different tfvars)      | Same code, only workspace name changes |
| **Backend config per env**    | Yes — each env has its own `backend.tf` | No — single backend, workspace-keyed |
| **Accidental cross-env apply**| Impossible (wrong directory = error) | Possible if you forget to switch workspace |
| **CI/CD clarity**             | Each pipeline targets one folder     | Pipeline must manage workspace state |
| **Recommended for**           | Production systems, strict isolation | Multiple near-identical ephemeral envs |

**Recommendation:** Use folder-based environments for `dev` / `prod` separation. Use workspaces only for ephemeral feature/test environments (e.g., per-PR preview environments).

### How Variable Overriding Works

When you run `terraform apply` in `environments/dev/`, Terraform automatically loads `terraform.tfvars` from the same directory. You can also pass extra values:

```bash
# Use default terraform.tfvars
terraform apply

# Override a single variable at runtime (useful in CI)
terraform apply -var="bucket_name=my-org-app-assets-dev-override"

# Point to a different tfvars file
terraform apply -var-file="custom.tfvars"
```

**Variable precedence (lowest → highest):**
1. `default` in `variables.tf`
2. `terraform.tfvars`
3. `*.auto.tfvars`
4. `-var-file` flag
5. `-var` flag
6. Environment variable `TF_VAR_<name>`

---

# Part 3: State Management — Terraform's Memory

> **Level:** Intermediate → Advanced
> **Goal:** Understand state deeply enough to manage it safely in a team environment.

---

## 3.1 What is State and Why Does It Matter?

### Terraform's Memory

When Terraform creates a resource, it records that resource's details in a state file (`terraform.tfstate`). This JSON file is Terraform's database — it maps your config's resource names to the actual AWS resource IDs and attributes.

```json
{
  "resources": [
    {
      "type": "aws_s3_bucket",
      "name": "this",
      "instances": [
        {
          "attributes": {
            "id": "my-org-app-assets-dev",
            "arn": "arn:aws:s3:::my-org-app-assets-dev",
            "bucket": "my-org-app-assets-dev",
            ...
          }
        }
      ]
    }
  ]
}
```

### Why State is Essential

Without state, Terraform would have no memory of what it created. On every `apply`, it would try to create everything from scratch — duplicating resources and causing conflicts.

With state, Terraform can:
1. **Calculate diffs:** Compare desired config against known state to determine what changed.
2. **Track dependencies:** Know to delete a bucket before deleting the IAM policy that references it.
3. **Map config names to real IDs:** Your config says `aws_s3_bucket.this` — state knows that maps to `arn:aws:s3:::my-org-app-assets-dev`.

### What Happens When State is Lost?

If `terraform.tfstate` is deleted, Terraform thinks no resources exist. The next `apply` will try to create everything — but most resources (like S3 buckets with unique names) already exist in AWS. This causes errors and leaves **orphaned resources** — AWS resources that Terraform no longer tracks and therefore cannot manage or destroy.

> Recovery requires using `terraform import` to re-map existing AWS resources back into state. This is tedious and error-prone. **Protect your state file.**

---

## 3.2 Local State vs Remote State

By default, Terraform stores state locally in `terraform.tfstate`. This is fine for solo experimentation but dangerous in teams.

| Aspect | Local State | Remote State (S3) |
|--------|------------|------------------|
| **Location** | `terraform.tfstate` in your project directory | S3 bucket, shared by the team |
| **Team collaboration** | Each engineer has their own copy — diverges immediately | Single authoritative source |
| **State locking** | No locking — two concurrent applies = corruption | DynamoDB lock table prevents concurrent applies |
| **Durability** | Lost if your laptop dies or you `git clean -fd` | S3 durability: 99.999999999% (11 nines) |
| **Versioning** | No history | S3 versioning enabled — recover previous state |
| **Secrets in state** | On your local disk (risky) | Encrypted in S3 with `encrypt = true` |
| **CI/CD compatible** | No — each runner gets fresh environment | Yes — all runners read from the same S3 bucket |

**Conclusion:** Local state is only acceptable for learning and solo experimentation. Any shared or production workflow requires remote state.

---

## 3.3 Remote State with S3 + DynamoDB

### One-Time Bootstrap

Before the main Terraform project can use S3 for remote state, someone must create the S3 bucket and DynamoDB table. This is a chicken-and-egg problem: you need state storage before you can store state. The solution is a minimal bootstrap configuration run once with local state.

```hcl
# bootstrap/main.tf — Run this ONCE to create the state backend resources.
# After applying, move to using the environments/ folder structure.

resource "aws_s3_bucket" "terraform_state" {
  bucket = "my-org-terraform-state"   # Must be globally unique

  # Prevent accidental deletion of this bucket — it holds all your state
  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_s3_bucket_versioning" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id
  versioning_configuration {
    status = "Enabled"   # Versioning lets you recover from state corruption
  }
}

resource "aws_dynamodb_table" "terraform_locks" {
  name         = "my-org-terraform-locks"
  billing_mode = "PAY_PER_REQUEST"   # No capacity planning needed
  hash_key     = "LockID"            # Required attribute name for Terraform locking

  attribute {
    name = "LockID"
    type = "S"
  }
}
```

Run this with local state:
```bash
cd bootstrap/
terraform init    # No backend configured — uses local state
terraform apply
# State bucket and DynamoDB table now exist in AWS.
# You can now use them as the backend for environments/dev/ and environments/prod/
```

### How Locking Works

1. `terraform apply` starts → writes a lock record to DynamoDB with the runner's identity
2. Any concurrent `terraform apply` attempt → reads the lock → exits with error: "Error acquiring the state lock"
3. Apply completes → lock record is deleted
4. If apply crashes mid-run → lock remains → manually delete with `terraform force-unlock <lock-id>`

The lock prevents the most dangerous Terraform scenario: two engineers (or two CI runs) applying simultaneously, which can corrupt state and leave infrastructure in an inconsistent state.

---

## 3.4 State Isolation Per Environment

Every environment must have its own state file. The `key` value in `backend.tf` is what separates them:

```
S3 bucket: my-org-terraform-state/
├── dev/s3/terraform.tfstate     ← dev environment state
└── prod/s3/terraform.tfstate    ← prod environment state
```

| Practice | Implementation |
|---|---|
| Separate state file per env | Different `key` in `backend.tf` for each env folder |
| Separate AWS accounts per env | Different `AWS_ACCESS_KEY_ID` secrets per environment |
| No cross-env state references | Each env is fully self-contained, no `terraform_remote_state` data sources between dev/prod |
| State encryption | `encrypt = true` in backend config |

**Why isolation is critical — a cautionary scenario:**

Imagine dev and prod share the same state file. A developer runs `terraform destroy` in their local dev environment. Terraform reads the shared state, sees both dev and prod resources, and destroys all of them — including prod. Game over.

With isolated state files, a `terraform destroy` in `environments/dev/` only reads the dev state file. Prod is invisible and unreachable from that directory.

---

## 3.5 Common State Operations

These commands are less common day-to-day but critical to know for troubleshooting.

### `terraform state list` — See what Terraform tracks

```bash
terraform state list
# module.app_bucket.aws_s3_bucket.this
# module.app_bucket.aws_s3_bucket_public_access_block.this
# module.app_bucket.aws_s3_bucket_versioning.this
```

**When to use:** Diagnosing why a plan shows unexpected changes. Verifying a resource was created.

### `terraform state show` — Inspect a specific resource

```bash
terraform state show module.app_bucket.aws_s3_bucket.this
# Shows all attributes: id, arn, bucket, tags, etc.
```

**When to use:** Seeing exactly what Terraform knows about a resource, including values only known after apply.

### `terraform state rm` — Remove a resource from state (without destroying it in AWS)

```bash
terraform state rm module.app_bucket.aws_s3_bucket.this
```

**When to use:** You want to stop managing a resource with Terraform without deleting it from AWS. After removing it from state, Terraform will no longer track it — but the bucket still exists. Warning: if you run `apply` again without removing the resource from config, Terraform will try to recreate it (and may fail if the name is already taken).

### `terraform import` — Adopt an existing AWS resource into state

```bash
terraform import module.app_bucket.aws_s3_bucket.this my-existing-bucket-name
```

**When to use:** A resource was created manually (or by another tool) and you want Terraform to manage it going forward. You must first write the corresponding `resource` block in your config.

### `terraform state mv` — Rename a resource in state

```bash
terraform state mv module.old_bucket.aws_s3_bucket.this module.new_bucket.aws_s3_bucket.this
```

**When to use:** You renamed a module or resource in your config. Without this, Terraform would destroy the old and create a new one. `state mv` tells Terraform "same resource, new name."

### `terraform output` — Read outputs without running apply

```bash
terraform output
terraform output bucket_arn    # Get a specific output value
```

**When to use:** Retrieving output values for use in scripts or manual operations after an apply.

---

# Part 4: Deploying to AWS — S3 in Context

> **Level:** Intermediate
> **Goal:** Understand why S3 is a good learning example and how to authenticate Terraform with AWS securely.

---

## 4.1 Why S3 as Our Primary Example

S3 is the most universally used AWS service — nearly every application touches it. For infrastructure learning, it is ideal because:

1. **It demonstrates all core Terraform patterns:** One logical resource (a bucket) requires five separate AWS API resource types (bucket, public access block, versioning, encryption, lifecycle). You see how Terraform manages resource dependencies.

2. **It has meaningful configuration choices:** Versioning on or off, encryption algorithm, public access settings — these are real decisions with real consequences. Not a toy example.

3. **It is safe to experiment with:** Creating and destroying S3 buckets is fast, cheap (a few cents or free in the free tier), and has no side effects on other services.

4. **It connects to OrgWideSession:** The `OrgWideSession-BE` FastAPI backend may need S3 for:
   - Storing uploaded files (session materials, QR codes)
   - Hosting static assets
   - Storing deployment artifacts from the GitHub Actions build pipeline in `OrgWideSession-BE`
   - Terraform state storage for this very IAC project

The S3 module in `modules/s3/` is a pattern you will reuse: create it once with all best practices baked in, then call it with different variable values for each use case.

---

## 4.2 AWS Authentication for Terraform

### What NOT to Do

```hcl
# NEVER do this — credentials in code = security incident
provider "aws" {
  access_key = "AKIAIOSFODNN7EXAMPLE"
  secret_key = "wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY"
}
```

Hardcoded credentials in code get committed to git, exposed in logs, and shared with anyone who clones the repo. AWS actively scans public GitHub repositories for credentials and will notify you — but the damage is often already done.

### Option 0: Local Development (AWS CLI Profile)

For running Terraform locally, use the credentials configured with `aws configure`. Terraform automatically reads from `~/.aws/credentials`:

```bash
# Set up a named profile (recommended for multiple accounts)
aws configure --profile orgwide-dev
# AWS Access Key ID: ...
# AWS Secret Access Key: ...
# Default region: us-east-1

# Tell Terraform to use this profile
export AWS_PROFILE=orgwide-dev
terraform plan
```

Or use environment variables (useful in scripts):
```bash
export AWS_ACCESS_KEY_ID="AKIAIOSFODNN7EXAMPLE"
export AWS_SECRET_ACCESS_KEY="wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY"
export AWS_DEFAULT_REGION="us-east-1"
terraform plan
```

### Option 1: GitHub Secrets (Good for Getting Started)

Store `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY` in GitHub Secrets. They appear as environment variables in workflows.

**Setup:**
1. Repository → Settings → Secrets and variables → Actions → New repository secret
2. Add `AWS_ACCESS_KEY_ID_DEV` and `AWS_SECRET_ACCESS_KEY_DEV` for dev deployments
3. Add `AWS_ACCESS_KEY_ID_PROD` and `AWS_SECRET_ACCESS_KEY_PROD` for prod deployments

**In the workflow:**
```yaml
env:
  AWS_ACCESS_KEY_ID: ${{ secrets.AWS_ACCESS_KEY_ID_DEV }}
  AWS_SECRET_ACCESS_KEY: ${{ secrets.AWS_SECRET_ACCESS_KEY_DEV }}
```

**Best practices for this approach:**
- Create separate IAM users for dev and prod (principle of least privilege)
- Grant only the permissions Terraform actually needs (S3:CreateBucket, S3:PutBucketPolicy, etc.)
- Rotate keys regularly
- Never use root account credentials

### Option 2: OIDC with IAM Roles (Recommended for Production)

OIDC eliminates long-lived access keys entirely. GitHub requests a short-lived token from AWS per workflow run. There are no static credentials to rotate, leak, or compromise.

```yaml
# In your workflow, replace credential secrets with OIDC:
permissions:
  id-token: write    # Required for OIDC
  contents: read

- name: Configure AWS Credentials via OIDC
  uses: aws-actions/configure-aws-credentials@v4
  with:
    role-to-assume: arn:aws:iam::123456789012:role/github-actions-terraform-dev
    aws-region: us-east-1
    # No access key / secret key needed — GitHub and AWS exchange OIDC tokens
```

The IAM role trust policy on AWS side:
```json
{
  "Effect": "Allow",
  "Principal": {
    "Federated": "arn:aws:iam::123456789012:oidc-provider/token.actions.githubusercontent.com"
  },
  "Action": "sts:AssumeRoleWithWebIdentity",
  "Condition": {
    "StringEquals": {
      "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
    },
    "StringLike": {
      "token.actions.githubusercontent.com:sub": "repo:your-org/your-repo:environment:dev"
    }
  }
}
```

---

## 4.3 The S3 Module Deep Dive

The `modules/s3/main.tf` (shown in full in Section 2.3) contains five resource blocks. Each one reflects an AWS best practice. Here is the rationale for each decision:

**`aws_s3_bucket` — The bucket itself**
S3 bucket names are globally unique across all AWS accounts and all regions. Choose names that are clearly scoped to your organization and environment: `my-org-app-assets-dev`. Never use names like `test-bucket` that conflict with others.

**`aws_s3_bucket_public_access_block` — Block all public access**
By default, this module blocks all public access. The vast majority of S3 buckets should never be public. The exceptions (public static websites, CloudFront origins with OAC) are explicit opt-ins. Defaulting to private prevents accidental data exposure — a common cause of cloud security incidents.

**`aws_s3_bucket_versioning` — Object versioning**
Versioning keeps a history of every object version. In prod (`versioning_enabled = true`), this provides:
- Point-in-time recovery from accidental deletes
- Rollback to previous file versions
- Audit trail for compliance

In dev (`versioning_enabled = false`), versioning is disabled to avoid storage cost overhead from frequent test uploads.

**`aws_s3_bucket_server_side_encryption_configuration` — Encryption at rest**
Enabled unconditionally — there is no environment where unencrypted storage is acceptable. `AES256` (SSE-S3) uses AWS-managed keys. For stricter compliance requirements, switch to `aws:kms` and provide a customer-managed key.

**`aws_s3_bucket_lifecycle_configuration` — Automatic cleanup**
When versioning is enabled, old versions accumulate indefinitely (and cost money). This lifecycle rule automatically deletes non-current versions after 30 days. Tune `noncurrent_days` per environment: lower in dev (7 days), higher in prod (90 days) for longer recovery windows.

The `depends_on = [aws_s3_bucket_versioning.this]` is critical — AWS requires versioning to be configured before lifecycle rules can reference non-current versions.

---

# Part 5: Automating with GitHub Actions CI/CD

> **Level:** Advanced
> **Goal:** Build a complete CI/CD pipeline that validates, plans, and applies Terraform changes automatically and safely.

---

## 5.1 Why Automate Terraform?

Running Terraform manually has the same problems as deploying application code manually:

- **No audit trail:** Who applied this change and when? What was in the plan?
- **Environment inconsistency:** "It worked on my machine" — because you had different provider versions, different state, different credentials.
- **No review gate:** Any developer with AWS credentials can apply anything, any time.
- **No concurrent-apply protection:** Two engineers applying simultaneously corrupts state.

CI/CD solves all of these:

| Problem | CI/CD Solution |
|---|---|
| No audit trail | GitHub Actions log every run with timestamps, actors, and full output |
| Environment inconsistency | Pinned Terraform version, fresh runner, consistent environment variables |
| No review gate | Plan runs on PR; apply only triggers after merge (human review required) |
| Concurrent apply | `concurrency` group ensures only one apply runs at a time |

The workflow for OrgWideSession infrastructure mirrors how the `OrgWideSession-BE` and `OrgWideSession-FE` repositories deploy via their own GitHub Actions pipelines — but for infrastructure instead of application code. All three repositories use GitHub Actions as their CI/CD platform.

---

## 5.2 GitHub Secrets Configuration

Before any workflow runs, configure these secrets in your GitHub repository:

**Repository → Settings → Secrets and variables → Actions → New repository secret**

| Secret Name                      | Value                                          | Used In              |
|----------------------------------|------------------------------------------------|----------------------|
| `AWS_ACCESS_KEY_ID_DEV`          | IAM access key for dev deployments             | `terraform-dev.yml`  |
| `AWS_SECRET_ACCESS_KEY_DEV`      | IAM secret key for dev deployments             | `terraform-dev.yml`  |
| `AWS_ACCESS_KEY_ID_PROD`         | IAM access key for prod deployments            | `terraform-prod.yml` |
| `AWS_SECRET_ACCESS_KEY_PROD`     | IAM secret key for prod deployments            | `terraform-prod.yml` |
| `TF_BACKEND_BUCKET`              | S3 bucket name for Terraform state             | Both                 |
| `TF_BACKEND_DYNAMODB_TABLE`      | DynamoDB table name for state locking          | Both                 |

> **Better alternative for prod:** Use GitHub's OIDC integration with AWS IAM roles (no long-lived keys). See Section 4.2 for implementation details.

---

## 5.3 Dev Environment Workflow (`terraform-dev.yml`)

### Workflow Anatomy

The dev workflow has three jobs that run in sequence:

```
[Push to main or PR targeting main]
         │
         ▼
┌─────────────────┐
│  Job 1: Validate │  ← Runs on every trigger
│  - terraform fmt │    Fast, no AWS calls needed
│  - terraform validate │
└────────┬────────┘
         │ (on success)
         ▼
┌─────────────────┐
│  Job 2: Plan     │  ← Runs on every trigger
│  - terraform init│    Reads AWS state
│  - terraform plan│    Saves plan as artifact
│  - Post to PR    │    Posts readable diff to PR
└────────┬────────┘
         │ (on success)
         ▼
┌─────────────────┐
│  Job 3: Apply    │  ← Runs ONLY on push to main
│  - Downloads plan│    Uses saved (reviewed) plan
│  - terraform apply   Requires "dev" env approval
└─────────────────┘
```

```yaml
# terraform-dev.yml
#
# Triggers:
#   - Pull Request targeting main: runs fmt, validate, plan (read-only, safe)
#   - Push to main: runs fmt, validate, plan, then apply (writes infrastructure)
#
# This workflow targets the environments/dev/ folder only.

name: "Terraform — Dev"

on:
  pull_request:
    branches:
      - main
    paths:
      # Only trigger when dev environment files or the shared module change.
      # Avoids running dev pipeline when only prod files change.
      - "environments/dev/**"
      - "modules/**"

  push:
    branches:
      - main
    paths:
      - "environments/dev/**"
      - "modules/**"

# Prevent concurrent runs — second run waits for first to finish.
# This avoids two applies running simultaneously and corrupting state.
concurrency:
  group: terraform-dev
  cancel-in-progress: false   # Do NOT cancel in-progress — let it finish

env:
  # Point all terraform commands to the dev folder.
  TF_WORKING_DIR: environments/dev

  # Terraform will pick up AWS credentials from these env vars automatically.
  AWS_ACCESS_KEY_ID: ${{ secrets.AWS_ACCESS_KEY_ID_DEV }}
  AWS_SECRET_ACCESS_KEY: ${{ secrets.AWS_SECRET_ACCESS_KEY_DEV }}
  AWS_DEFAULT_REGION: us-east-1

jobs:
  # ─────────────────────────────────────────────
  # JOB 1: Validate — runs on every PR and push
  # ─────────────────────────────────────────────
  validate:
    name: "Validate"
    runs-on: ubuntu-latest

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v3
        with:
          terraform_version: "1.7.0"   # Pin version — never use 'latest' in CI

      # terraform init downloads providers and configures the backend.
      # -backend-config flags override the partial backend.tf values with secrets.
      - name: Terraform Init
        working-directory: ${{ env.TF_WORKING_DIR }}
        run: |
          terraform init \
            -backend-config="bucket=${{ secrets.TF_BACKEND_BUCKET }}" \
            -backend-config="dynamodb_table=${{ secrets.TF_BACKEND_DYNAMODB_TABLE }}" \
            -input=false   # Disable interactive prompts — essential for CI

      # terraform fmt -check exits with code 1 if any file is not formatted.
      # -recursive checks all .tf files in subdirectories too.
      - name: Terraform Format Check
        working-directory: ${{ env.TF_WORKING_DIR }}
        run: terraform fmt -check -recursive

      # terraform validate checks syntax and internal consistency.
      # Does NOT connect to AWS — fast and safe.
      - name: Terraform Validate
        working-directory: ${{ env.TF_WORKING_DIR }}
        run: terraform validate

  # ─────────────────────────────────────────────
  # JOB 2: Plan — runs on every PR and push
  # Shows what WOULD change without changing anything.
  # ─────────────────────────────────────────────
  plan:
    name: "Plan"
    runs-on: ubuntu-latest
    needs: validate   # Only plan if validate passed

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v3
        with:
          terraform_version: "1.7.0"

      - name: Terraform Init
        working-directory: ${{ env.TF_WORKING_DIR }}
        run: |
          terraform init \
            -backend-config="bucket=${{ secrets.TF_BACKEND_BUCKET }}" \
            -backend-config="dynamodb_table=${{ secrets.TF_BACKEND_DYNAMODB_TABLE }}" \
            -input=false

      # Save the plan to a binary file.
      # The saved plan is used in the apply job — this guarantees apply runs
      # exactly what was reviewed, not a re-generated plan.
      - name: Terraform Plan
        working-directory: ${{ env.TF_WORKING_DIR }}
        run: |
          terraform plan \
            -out=tfplan \
            -input=false \
            -detailed-exitcode   # Exit 0=no changes, 1=error, 2=changes present
        continue-on-error: true  # Let the next step capture the exit code

      # Upload the plan artifact so the apply job can download it.
      # Artifacts are scoped to the workflow run.
      - name: Upload Plan Artifact
        uses: actions/upload-artifact@v4
        with:
          name: tfplan-dev
          path: ${{ env.TF_WORKING_DIR }}/tfplan
          retention-days: 1   # Short retention — plan is only valid for the current run

      # Post a summary of the plan as a PR comment (human-readable).
      # terraform show converts the binary plan to readable text.
      - name: Post Plan to PR
        if: github.event_name == 'pull_request'
        uses: actions/github-script@v7
        with:
          script: |
            const output = `#### Terraform Plan — Dev
            \`\`\`
            ${{ steps.plan.outputs.stdout }}
            \`\`\`
            *Run ID: ${{ github.run_id }}*`;

            github.rest.issues.createComment({
              issue_number: context.issue.number,
              owner: context.repo.owner,
              repo: context.repo.repo,
              body: output
            });

  # ─────────────────────────────────────────────
  # JOB 3: Apply — runs ONLY on push to main
  # Uses the saved plan from the plan job.
  # ─────────────────────────────────────────────
  apply:
    name: "Apply"
    runs-on: ubuntu-latest
    needs: plan
    # This job only runs when code is merged to main, not on PRs.
    if: github.event_name == 'push' && github.ref == 'refs/heads/main'

    # GitHub Environment for apply — enables required reviewers in GitHub settings.
    # Go to: Repo → Settings → Environments → Create "dev" → Add required reviewers
    environment:
      name: dev

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v3
        with:
          terraform_version: "1.7.0"

      - name: Terraform Init
        working-directory: ${{ env.TF_WORKING_DIR }}
        run: |
          terraform init \
            -backend-config="bucket=${{ secrets.TF_BACKEND_BUCKET }}" \
            -backend-config="dynamodb_table=${{ secrets.TF_BACKEND_DYNAMODB_TABLE }}" \
            -input=false

      # Download the plan that was generated and reviewed in the plan job.
      - name: Download Plan Artifact
        uses: actions/download-artifact@v4
        with:
          name: tfplan-dev
          path: ${{ env.TF_WORKING_DIR }}

      # Apply the exact plan that was reviewed — no surprises.
      # -input=false ensures no interactive prompts block CI.
      - name: Terraform Apply
        working-directory: ${{ env.TF_WORKING_DIR }}
        run: terraform apply -input=false tfplan
```

---

## 5.4 Prod Environment Workflow (`terraform-prod.yml`)

The prod workflow is structurally identical to the dev workflow with two critical differences:

1. **Separate AWS credentials:** Uses `AWS_ACCESS_KEY_ID_PROD` / `AWS_SECRET_ACCESS_KEY_PROD` — completely isolated from dev credentials, with scoped IAM permissions.
2. **Manual approval gate:** The `environment: prod` block pauses the apply job. A designated reviewer must click "Review deployments" in the GitHub Actions UI and explicitly approve before Terraform touches prod infrastructure.

Configure the approval gate: **Repo → Settings → Environments → Create "prod" → Required reviewers → Add your team leads.**

```yaml
# terraform-prod.yml
#
# Identical structure to terraform-dev.yml with two key differences:
#   1. Uses prod AWS credentials
#   2. The apply job requires manual approval via the "prod" GitHub Environment
#
# Triggers: Pull Requests and pushes that touch prod/ or modules/

name: "Terraform — Prod"

on:
  pull_request:
    branches:
      - main
    paths:
      - "environments/prod/**"
      - "modules/**"

  push:
    branches:
      - main
    paths:
      - "environments/prod/**"
      - "modules/**"

concurrency:
  group: terraform-prod
  cancel-in-progress: false

env:
  TF_WORKING_DIR: environments/prod
  # Prod uses its own separate IAM credentials
  AWS_ACCESS_KEY_ID: ${{ secrets.AWS_ACCESS_KEY_ID_PROD }}
  AWS_SECRET_ACCESS_KEY: ${{ secrets.AWS_SECRET_ACCESS_KEY_PROD }}
  AWS_DEFAULT_REGION: us-east-1

jobs:
  validate:
    name: "Validate"
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: hashicorp/setup-terraform@v3
        with:
          terraform_version: "1.7.0"
      - name: Terraform Init
        working-directory: ${{ env.TF_WORKING_DIR }}
        run: |
          terraform init \
            -backend-config="bucket=${{ secrets.TF_BACKEND_BUCKET }}" \
            -backend-config="dynamodb_table=${{ secrets.TF_BACKEND_DYNAMODB_TABLE }}" \
            -input=false
      - name: Terraform Format Check
        working-directory: ${{ env.TF_WORKING_DIR }}
        run: terraform fmt -check -recursive
      - name: Terraform Validate
        working-directory: ${{ env.TF_WORKING_DIR }}
        run: terraform validate

  plan:
    name: "Plan"
    runs-on: ubuntu-latest
    needs: validate
    steps:
      - uses: actions/checkout@v4
      - uses: hashicorp/setup-terraform@v3
        with:
          terraform_version: "1.7.0"
      - name: Terraform Init
        working-directory: ${{ env.TF_WORKING_DIR }}
        run: |
          terraform init \
            -backend-config="bucket=${{ secrets.TF_BACKEND_BUCKET }}" \
            -backend-config="dynamodb_table=${{ secrets.TF_BACKEND_DYNAMODB_TABLE }}" \
            -input=false
      - name: Terraform Plan
        working-directory: ${{ env.TF_WORKING_DIR }}
        run: terraform plan -out=tfplan -input=false
      - name: Upload Plan Artifact
        uses: actions/upload-artifact@v4
        with:
          name: tfplan-prod
          path: ${{ env.TF_WORKING_DIR }}/tfplan
          retention-days: 1
      - name: Post Plan to PR
        if: github.event_name == 'pull_request'
        uses: actions/github-script@v7
        with:
          script: |
            github.rest.issues.createComment({
              issue_number: context.issue.number,
              owner: context.repo.owner,
              repo: context.repo.repo,
              body: `#### Terraform Plan — Prod\n\`\`\`\n${{ steps.plan.outputs.stdout }}\n\`\`\``
            });

  apply:
    name: "Apply"
    runs-on: ubuntu-latest
    needs: plan
    if: github.event_name == 'push' && github.ref == 'refs/heads/main'

    # "prod" GitHub Environment MUST have required reviewers configured.
    # The workflow will pause here until a reviewer approves in the GitHub UI.
    # Configure at: Repo → Settings → Environments → prod → Required reviewers
    environment:
      name: prod

    steps:
      - uses: actions/checkout@v4
      - uses: hashicorp/setup-terraform@v3
        with:
          terraform_version: "1.7.0"
      - name: Terraform Init
        working-directory: ${{ env.TF_WORKING_DIR }}
        run: |
          terraform init \
            -backend-config="bucket=${{ secrets.TF_BACKEND_BUCKET }}" \
            -backend-config="dynamodb_table=${{ secrets.TF_BACKEND_DYNAMODB_TABLE }}" \
            -input=false
      - name: Download Plan Artifact
        uses: actions/download-artifact@v4
        with:
          name: tfplan-prod
          path: ${{ env.TF_WORKING_DIR }}
      - name: Terraform Apply
        working-directory: ${{ env.TF_WORKING_DIR }}
        run: terraform apply -input=false tfplan
```

---

## 5.5 Drift Detection Workflow

**What is drift?** When someone manually changes a resource in the AWS Console without updating the Terraform configuration, the actual infrastructure diverges from the declared state. This is called drift.

**Why it matters:** Drift is silent. If a developer manually increases an S3 bucket's lifecycle rule to 90 days in the console, Terraform still thinks it should be 30. The next `apply` will revert it — surprising and potentially dangerous.

**Detection strategy:** Run `terraform plan` on a schedule. If the plan shows changes, drift has occurred.

```yaml
# .github/workflows/drift-detection.yml
name: "Drift Detection"

on:
  schedule:
    - cron: "0 8 * * 1-5"   # Every weekday at 8am UTC

jobs:
  detect-drift-prod:
    runs-on: ubuntu-latest
    env:
      TF_WORKING_DIR: environments/prod
      AWS_ACCESS_KEY_ID: ${{ secrets.AWS_ACCESS_KEY_ID_PROD }}
      AWS_SECRET_ACCESS_KEY: ${{ secrets.AWS_SECRET_ACCESS_KEY_PROD }}
    steps:
      - uses: actions/checkout@v4
      - uses: hashicorp/setup-terraform@v3
        with:
          terraform_version: "1.7.0"
      - name: Terraform Init
        working-directory: ${{ env.TF_WORKING_DIR }}
        run: |
          terraform init \
            -backend-config="bucket=${{ secrets.TF_BACKEND_BUCKET }}" \
            -backend-config="dynamodb_table=${{ secrets.TF_BACKEND_DYNAMODB_TABLE }}" \
            -input=false
      - name: Check for Drift
        working-directory: ${{ env.TF_WORKING_DIR }}
        run: |
          # -detailed-exitcode: exits 2 if there are changes (drift detected)
          terraform plan -detailed-exitcode -input=false || \
          (echo "DRIFT DETECTED — prod infrastructure differs from Terraform state" && exit 1)
```

This workflow fails (and GitHub can notify you via email/Slack) whenever drift is detected. When the workflow fails, investigate: was the change intentional? If so, update the Terraform config to match. If not, run `terraform apply` to restore the declared state.

---

# Part 6: The Complete Lifecycle — End to End

> **Level:** All levels
> **Goal:** See the full developer workflow from writing code to live infrastructure.

---

## 6.1 From Code to Infrastructure (Flow Diagram)

```
Developer                    GitHub / CI                     AWS
─────────                    ──────────                      ───
  │                               │                           │
  │  1. Write Terraform code      │                           │
  │     in environments/dev/      │                           │
  │                               │                           │
  │  2. git push origin feature/  │                           │
  │     add-new-bucket            │                           │
  │                               │                           │
  │  3. Open Pull Request         │                           │
  │     targeting main  ──────────▶                           │
  │                               │  4. Workflow triggers     │
  │                               │     (pr path filter)      │
  │                               │                           │
  │                               │  5. Job: validate         │
  │                               │     terraform fmt -check  │
  │                               │     terraform validate    │
  │                               │                           │
  │                               │  6. Job: plan             │
  │                               │     terraform init ───────▶ Reads state from S3
  │                               │     terraform plan ───────▶ Compares state vs config
  │                               │◀─────────────────────────── Returns diff
  │                               │                           │
  │◀──────────────────────────────│  7. Plan posted to PR     │
  │     (review plan output)      │     as a comment          │
  │                               │                           │
  │  8. Team reviews plan         │                           │
  │     Approves PR               │                           │
  │                               │                           │
  │  9. Merge PR to main ─────────▶                           │
  │                               │ 10. Push workflow triggers│
  │                               │                           │
  │                               │ 11. validate + plan re-run│
  │                               │     (fresh state read)    │
  │                               │                           │
  │                               │ 12. Job: apply            │
  │                               │     (waits for approval   │
  │                               │      if prod environment) │
  │                               │                           │
  │                               │ 13. Reviewer approves ────▶ (prod only)
  │                               │     in GitHub UI          │
  │                               │                           │
  │                               │ 14. terraform apply ──────▶ Creates/updates S3 bucket
  │                               │                           │ Writes new state to S3
  │                               │                           │ Releases DynamoDB lock
  │                               │                           │
  │◀──────────────────────────────│ 15. Workflow complete      │
  │     Apply succeeded           │     (or failed with logs) │
  └───────────────────────────────┴───────────────────────────┘
```

---

## 6.2 Key Decision Points

**At step 5 (fmt check):** If any `.tf` file is not formatted, the workflow fails here — before any AWS calls are made. Fix with `terraform fmt -recursive`.

**At step 6 (plan):** Plan reads current AWS state and your config. If resources already exist and match config, plan shows no changes. If config changed, it shows what will be created/modified/destroyed.

**At step 7 (PR comment):** The plan output looks like:
```
# aws_s3_bucket.this will be created
+ resource "aws_s3_bucket" "this" {
    + bucket = "my-org-app-assets-dev"
    + ...
  }

Plan: 4 to add, 0 to change, 0 to destroy.
```
Review this carefully. Any `- destroy` lines warrant scrutiny.

**At step 12–13 (apply with approval):** For prod, the `environment: prod` block pauses the workflow. A required reviewer must click "Review deployments" in the GitHub Actions UI and approve.

---

## 6.3 Developer Workflow Checklist

Follow this checklist for every infrastructure change:

1. **Create a feature branch** from `main`: `git checkout -b feature/add-logging-bucket`
2. **Edit Terraform files** in `environments/dev/` (or `modules/` for shared changes)
3. **Run `terraform fmt -recursive`** to format your files before committing
4. **Run `terraform validate`** to catch syntax errors locally
5. **Run `terraform plan`** locally to verify changes look correct
6. **Commit and push** your branch
7. **Open a Pull Request** targeting `main` — the CI pipeline starts automatically
8. **Review the plan comment** posted to your PR by the CI pipeline
9. **Address any unexpected changes** in the plan (investigate before approving)
10. **Get PR approval** from a teammate
11. **Merge to `main`** — the apply pipeline starts automatically
12. **Monitor the apply** in the GitHub Actions tab
13. **Verify in AWS Console** that the resources were created/modified as expected
14. **Check Terraform outputs** if your change creates resources referenced by other systems

---

# Part 7: Best Practices, Pitfalls, and Reference

> **Level:** All levels
> **Goal:** Consolidate operational wisdom and provide a quick-reference cheatsheet.

---

## 7.1 Safe Deployment Practices

| Practice                        | How It's Implemented Here                                     |
|---------------------------------|---------------------------------------------------------------|
| Plan before every apply         | Separate `plan` job runs before `apply` in all workflows      |
| Never apply unreviewed plans    | PR workflow runs plan; apply only triggers after merge        |
| Apply uses saved plan           | Artifact upload/download ensures apply = reviewed plan        |
| Prod requires human approval    | GitHub `environment: prod` with required reviewers            |
| Concurrent apply prevention     | `concurrency` group with `cancel-in-progress: false`          |
| State locking                   | DynamoDB lock table prevents simultaneous applies             |
| Pinned provider versions        | `~> 5.0` in `required_providers` prevents surprise upgrades   |
| Pinned Terraform version        | `terraform_version: "1.7.0"` in `setup-terraform` action     |
| Least-privilege IAM             | Separate IAM users/roles for dev and prod with scoped permissions |
| Encrypted state                 | `encrypt = true` in all backend configs                       |

---

## 7.2 Common Pitfalls

Knowing where people go wrong saves you from learning the hard way.

---

**Pitfall 1: Forgetting `terraform init` after backend or provider changes**

If you add a new provider, change the backend configuration, or pull changes that add a new module, you must re-run `terraform init`. Without it, Terraform will error because it cannot find the new provider plugin or module source.

*Fix:* When in doubt, run `terraform init`. It is always safe to re-run.

---

**Pitfall 2: Committing `terraform.tfstate` or `.terraform/` to git**

`terraform.tfstate` often contains sensitive values (database passwords, private key IDs). `.terraform/` contains provider binaries (large, platform-specific).

*Fix:* The `.gitignore` in this repository already excludes these. Never override it. Use remote state (S3) so state is never stored locally on developer machines.

---

**Pitfall 3: Not pinning provider versions**

```hcl
# Dangerous — uses whatever the latest version is at init time
required_providers {
  aws = { source = "hashicorp/aws" }
}
```

A breaking change in a new provider major version can silently break your configuration when a developer runs `terraform init` on a new machine.

*Fix:* Always pin to a major version: `version = "~> 5.0"`. Upgrade deliberately.

---

**Pitfall 4: Running `apply` without reading the plan**

The plan is your safety net. Every apply should be preceded by a plan review. Skipping this is how you accidentally destroy a production database.

*Fix:* Make it a habit: plan, read every line, then apply. In CI, the PR comment makes plan review mandatory — a human must read the diff before merging.

---

**Pitfall 5: Manually editing resources in the AWS Console**

The Console feels faster for small changes. But it creates drift — your Terraform config no longer matches reality. The next `apply` will revert your manual change, often surprising you.

*Fix:* All infrastructure changes go through Terraform. If you need to investigate, use the Console in read-only mode. If you make an emergency manual change, immediately update the Terraform config to match.

---

**Pitfall 6: Running `terraform destroy` in the wrong directory**

```bash
# You think you are in environments/dev/
# You are actually in environments/prod/
terraform destroy   # Destroys production
```

*Fix:* Always verify your working directory before running destructive commands: `pwd` and `terraform state list` to confirm what Terraform thinks it manages.

---

**Pitfall 7: Hardcoding values instead of using variables**

```hcl
# Hardcoded — cannot reuse this for prod without editing the file
resource "aws_s3_bucket" "this" {
  bucket = "my-org-app-assets-dev"
}
```

*Fix:* Anything that differs between environments (names, sizes, settings, tags) should be a variable with values in `terraform.tfvars`.

---

**Pitfall 8: Forgetting that S3 bucket names are globally unique**

S3 bucket names must be unique across all AWS accounts worldwide. `test-bucket` is almost certainly already taken.

*Fix:* Use a naming convention that includes your organization name, project, and environment: `my-org-orgwidesession-assets-dev`.

---

**Pitfall 9: Not running `terraform fmt` before committing**

The `terraform fmt -check` step in CI will fail your PR if files are not formatted. This is annoying if you only discover it in CI.

*Fix:* Run `terraform fmt -recursive` as part of your commit workflow. Consider adding a pre-commit hook.

---

**Pitfall 10: Importing resources without writing the config first**

Running `terraform import` adds a resource to state, but if there is no matching `resource` block in your config, the next `terraform plan` will show that resource as needing to be destroyed.

*Fix:* Always write the `resource` block in your config before running `terraform import`.

---

## 7.3 Code Review Checklist for Terraform PRs

Use this checklist when reviewing a teammate's infrastructure PR:

**Plan Review**
- [ ] Does the plan show only the resources you expected to change?
- [ ] Are there any `-` (destroy) or `-/+` (destroy + recreate) actions? If so, are they intentional?
- [ ] Does the plan show `0 to destroy` for any resources that should never be deleted?

**Code Quality**
- [ ] Are all new variables declared with `description` and `type`?
- [ ] Are environment-specific values in `terraform.tfvars`, not hardcoded in `main.tf`?
- [ ] Are provider and Terraform version constraints present and pinned?
- [ ] Are new resources tagged appropriately (`Environment`, `Project`, `ManagedBy`)?

**Security**
- [ ] Are there any hardcoded credentials, account IDs, or secrets in the code?
- [ ] If creating IAM policies, do they follow least privilege?
- [ ] If creating public resources (S3, security groups), is that intentional and documented?

**State and Structure**
- [ ] Is the change in the correct environment folder (`dev/` vs `prod/`)?
- [ ] If a new module is added, does it follow the existing module structure?
- [ ] Are outputs defined for new resources that other systems might reference?

---

## 7.4 Quick Reference: Local Commands

```bash
# Navigate to an environment
cd environments/dev

# First-time setup (downloads providers, configures backend)
terraform init \
  -backend-config="bucket=my-org-terraform-state" \
  -backend-config="dynamodb_table=my-org-terraform-locks"

# See what would change (safe — read-only)
terraform plan

# Apply changes (will prompt for confirmation)
terraform apply

# Apply without interactive prompt (CI-style)
terraform apply -auto-approve

# Destroy all resources in this environment (DANGEROUS — prompts for confirmation)
terraform destroy

# Reformat all .tf files
terraform fmt -recursive

# Validate syntax (no AWS calls)
terraform validate

# Show current state
terraform show

# List resources tracked in state
terraform state list

# Inspect a specific resource in state
terraform state show module.app_bucket.aws_s3_bucket.this

# Manually remove a resource from state (without destroying it in AWS)
terraform state rm aws_s3_bucket.this

# Import an existing AWS resource into state
terraform import module.app_bucket.aws_s3_bucket.this my-existing-bucket-name

# Move/rename a resource in state (avoids destroy + recreate on rename)
terraform state mv module.old_name.aws_s3_bucket.this module.new_name.aws_s3_bucket.this

# Read outputs after apply
terraform output
terraform output bucket_arn

# Visualize resource dependency graph (outputs DOT format)
terraform graph | dot -Tsvg > graph.svg

# Interactive expression evaluator (useful for testing expressions)
terraform console

# List all providers and their versions
terraform providers

# Unlock a stuck state lock (use the lock ID from the error message)
terraform force-unlock <lock-id>
```

---

## 7.5 Glossary

**Apply** — The Terraform command that executes the changes shown by `plan`, creating, modifying, or destroying real infrastructure.

**Backend** — Where Terraform stores its state file. The default is local (on disk). This guide uses S3 as a remote backend.

**Child Module** — A module called by another module or root module using a `module` block with a `source` argument.

**Data Source** — A read-only lookup of existing infrastructure that Terraform does not manage. Declared with the `data` block.

**Drift** — When real infrastructure diverges from the Terraform configuration, typically due to manual changes in the cloud console.

**HCL (HashiCorp Configuration Language)** — The declarative language used to write Terraform configuration files (`.tf` files).

**IaC (Infrastructure as Code)** — The practice of managing infrastructure through version-controlled configuration files rather than manual processes.

**Lock** — A record in DynamoDB that prevents two Terraform processes from applying simultaneously to the same state file.

**Module** — A directory containing `.tf` files. Can be a root module (the entry point) or a child module (called by another module).

**Output** — A value exposed by a module or root configuration after `apply`. Useful for passing values to other systems or displaying results.

**Plan** — The Terraform command that calculates and displays the diff between desired configuration and current state, without making any changes.

**Provider** — A plugin that translates Terraform configuration into API calls for a specific cloud or service (e.g., `hashicorp/aws`).

**Remote State** — State stored in a shared location (S3) rather than locally on a developer's machine.

**Resource** — A single infrastructure object managed by Terraform (e.g., one S3 bucket, one EC2 instance).

**Root Module** — The main entry point directory where you run Terraform commands. Contains `main.tf`, `variables.tf`, `outputs.tf`, and optionally `backend.tf` and `terraform.tfvars`.

**State** — Terraform's record (in `terraform.tfstate`) of what infrastructure it has created and the mapping between config names and real resource IDs.

**tfvars** — A file (typically `terraform.tfvars` or `*.tfvars`) containing variable values for a specific environment or configuration.

**Variable** — An input parameter declared in `variables.tf` and supplied via `terraform.tfvars`, `-var` flags, or environment variables.

**Workspace** — A Terraform feature for multiple named state files within a single backend. Not recommended for dev/prod isolation (use folder-based environments instead).

---

*This guide covers the full progression: beginner foundations → scalable project structure → state management → AWS deployment → CI/CD automation → operational practices. Follow the parts in order for a complete setup, or jump to specific sections as reference.*
