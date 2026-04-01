# ECS Fargate Deployment Guide

This guide walks you through deploying the OrgWideSession backend on AWS ECS Fargate from scratch. Follow the steps in order — each section builds on the previous one.

---

## How Everything Fits Together

```
OrgWideSession-IAC (this repo)          OrgWideSession-BE
─────────────────────────────           ─────────────────
Terraform creates:                      GitHub Actions:
  - ECR repository          ──────────>   docker build
  - ECS Cluster                           docker push → ECR
  - ECS Task Definition                   fetch task def from AWS
  - ECS Service             <──────────   update image in task def
  - IAM roles                             deploy to ECS service
  - Security group
  - CloudWatch log group
  - Secrets Manager (manual)
  - S3 bucket
```

**IAC owns the infrastructure.** The BE deploy workflow owns the image. They meet at the task definition: Terraform creates it once; the deploy workflow updates only the container image on every push.

---

## Prerequisites

Before starting, make sure you have:

- An AWS account with admin access (or sufficient IAM permissions — see below)
- AWS CLI installed and configured (`aws configure`)
- Terraform >= 1.5 installed (`terraform -version`)
- A PostgreSQL database accessible from the internet (the ECS tasks call out to it)
- The OrgWideSession-IAC and OrgWideSession-BE repositories on GitHub

### Required AWS IAM permissions

The IAM user you run Terraform with needs these services:

- **S3** — create/manage buckets (assets + state)
- **ECR** — create repositories
- **ECS** — create clusters, task definitions, services
- **IAM** — create roles and policies
- **CloudWatch Logs** — create log groups
- **EC2** — create security groups (VPC permissions)
- **Secrets Manager** — read (for referencing secrets in task definitions)

---

## Step 1 — Find your VPC and Subnet IDs

ECS Fargate tasks run inside a VPC. You need a VPC with at least two public subnets (in different availability zones for reliability).

### Option A — Use the default VPC (quickest for getting started)

```bash
# Get the default VPC ID
aws ec2 describe-vpcs \
  --filters "Name=isDefault,Values=true" \
  --query "Vpcs[0].VpcId" \
  --output text

# Get two public subnets in the default VPC
aws ec2 describe-subnets \
  --filters "Name=vpc-id,Values=<YOUR_VPC_ID>" \
  --query "Subnets[*].[SubnetId,AvailabilityZone]" \
  --output table
```

### Option B — Use the AWS console

1. Go to **VPC** → **Your VPCs** → copy the VPC ID
2. Go to **VPC** → **Subnets** → filter by your VPC → copy two subnet IDs from different AZs

You will paste these values into `terraform.tfvars` in Step 4.

---

## Step 2 — Create the Secrets Manager Secret

The ECS task pulls all sensitive configuration from a single AWS Secrets Manager secret at startup. You create this secret once; ECS fetches the values every time a new task starts.

### Why one secret for everything?

AWS Secrets Manager charges per secret (not per key). Storing all config in one JSON secret is cheaper and simpler to manage than creating a separate secret per value.

### 2a — Create the secret

Go to **AWS Console** → **Secrets Manager** → **Store a new secret**

1. Choose **Other type of secret**
2. Select **Plaintext** and paste the following JSON (fill in your real values):

```json
{
  "database_url":          "postgresql://username:password@your-db-host:5432/dbname",
  "client_id":             "your-azure-app-client-id",
  "tenant_id":             "your-azure-tenant-id",
  "openid_config_url":     "https://login.microsoftonline.com/<tenant-id>/v2.0/.well-known/openid-configuration",
  "valid_audience":        "api://your-azure-app-client-id",
  "valid_issuer":          "https://sts.windows.net/<tenant-id>/",
  "qr_secret_key":         "a-long-random-string-change-this",
  "client_secret":         "your-azure-app-client-secret",
  "email_redirect_url":    "https://your-app-domain.com",
  "from_address":          "noreply@yourdomain.com",
  "app_base_url":          "https://your-app-domain.com",
  "aws_access_key_id":     "AKIA...",
  "aws_secret_access_key": "your-s3-secret",
  "s3_bucket_name":        "dev-orgwidesession-be"
}
```

3. Click **Next**
4. Secret name: `orgwidesession/dev/config`
5. Click through to **Store**

> **Important:** The JSON key names (e.g. `database_url`, `client_id`) must exactly match the values in `secret_keys` inside `terraform.tfvars`. They are case-sensitive.

### 2b — Copy the Secret ARN

After saving, open the secret and copy the **Secret ARN**. It looks like:

```
arn:aws:secretsmanager:us-east-1:123456789012:secret:orgwidesession/dev/config-AbCdEf
```

You will paste this into `terraform.tfvars` in the next step.

---

## Step 3 — Create an IAM User for CI/CD

You need two IAM users (or one if dev and prod share the same account):

- One for deploying dev infrastructure (`AWS_ACCESS_KEY_ID_DEV`)
- One for deploying prod infrastructure (`AWS_ACCESS_KEY_ID_PROD`)

You also need a third set of credentials for the **BE deploy workflow** (ECR push + ECS deploy).

### 3a — Terraform IAM user (per environment)

In **IAM** → **Users** → **Create user**

- Username: `orgwidesession-terraform-dev`
- Attach policies: `AdministratorAccess` (or scope down with a custom policy)
- Create access key → **Application running outside AWS**
- Save the `Access key ID` and `Secret access key`

### 3b — BE deploy IAM user

In **IAM** → **Users** → **Create user**

- Username: `orgwidesession-be-deployer`
- Attach a custom inline policy:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ecr:GetAuthorizationToken",
        "ecr:BatchCheckLayerAvailability",
        "ecr:InitiateLayerUpload",
        "ecr:UploadLayerPart",
        "ecr:CompleteLayerUpload",
        "ecr:PutImage"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "ecs:DescribeTaskDefinition",
        "ecs:RegisterTaskDefinition",
        "ecs:UpdateService",
        "ecs:DescribeServices"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": "iam:PassRole",
      "Resource": [
        "arn:aws:iam::*:role/*-ecs-execution",
        "arn:aws:iam::*:role/*-ecs-task"
      ]
    }
  ]
}
```

- Create access key → save it

---

## Step 4 — Fill in terraform.tfvars

Open `environments/dev/terraform.tfvars` and replace the three placeholder values:

```hcl
# The VPC ID from Step 1
vpc_id     = "vpc-0abc1234def56789a"

# Two subnet IDs from Step 1
subnet_ids = ["subnet-0111aaaa2222bbbb", "subnet-0333cccc4444dddd"]

# The Secret ARN from Step 2b
secrets_manager_arn = "arn:aws:secretsmanager:us-east-1:123456789012:secret:orgwidesession/dev/config-AbCdEf"
```

Do the same for `environments/prod/terraform.tfvars` when you're ready to set up prod.

Commit and push these changes to the `development` branch.

---

## Step 5 — Configure GitHub Secrets in OrgWideSession-IAC

Go to **OrgWideSession-IAC** → **Settings** → **Secrets and variables** → **Actions** → **New repository secret**

Add all six secrets:

| Secret name | Value |
|---|---|
| `AWS_ACCESS_KEY_ID_DEV` | Access key ID for the dev Terraform IAM user |
| `AWS_SECRET_ACCESS_KEY_DEV` | Secret access key for the dev Terraform IAM user |
| `AWS_ACCESS_KEY_ID_PROD` | Access key ID for the prod Terraform IAM user |
| `AWS_SECRET_ACCESS_KEY_PROD` | Secret access key for the prod Terraform IAM user |
| `TF_BACKEND_BUCKET` | `github-session-my-org-terraform-state` |
| `TF_BACKEND_DYNAMODB_TABLE` | `github-session-my-org-terraform-locks` |

> `TF_BACKEND_BUCKET` and `TF_BACKEND_DYNAMODB_TABLE` are the names of the S3 bucket and DynamoDB table created by `bootstrap/`. If you haven't run the bootstrap yet, do that first — see the `TERRAFORM_IMPLEMENTATION_GUIDE.md`.

---

## Step 6 — Configure GitHub Environments in OrgWideSession-IAC

Go to **OrgWideSession-IAC** → **Settings** → **Environments** → **New environment**

Create two environments:

### `dev` environment
- Name: `dev`
- No required reviewers (dev applies automatically on merge to `development`)
- Deployment branches: `development` only

### `prod` environment
- Name: `prod`
- **Required reviewers:** add yourself or your team — prod apply needs manual approval
- Deployment branches: `main` only

---

## Step 7 — Run Terraform (Create the Infrastructure)

The Terraform workflow runs automatically when you push to the `development` branch. Here's what happens:

```
Push to development
       │
       ▼
  setup job          ← detects branch → environment=dev
       │
       ▼
  validate job       ← terraform fmt check + terraform validate
       │
       ▼
  plan job           ← terraform plan (shows what will be created)
       │
       ▼
  apply job          ← terraform apply (creates ECR, ECS, IAM, etc.)
```

### What gets created

Terraform creates these resources on first apply:

```
module.ecr
  aws_ecr_repository.this             → dev-orgwidesession-be
  aws_ecr_lifecycle_policy.this       → keep last 10 images

module.ecs
  aws_ecs_cluster.this                → dev-orgwidesession-be
  aws_cloudwatch_log_group.this       → /ecs/dev-orgwidesession-be
  aws_iam_role.execution              → dev-orgwidesession-be-ecs-execution
  aws_iam_role.task                   → dev-orgwidesession-be-ecs-task
  aws_iam_role_policy_attachment      → AmazonECSTaskExecutionRolePolicy
  aws_iam_role_policy.execution_secrets → Secrets Manager read
  aws_security_group.ecs              → dev-orgwidesession-be-ecs
  aws_ecs_task_definition.this        → dev-orgwidesession-be (revision 1)
  aws_ecs_service.this                → dev-orgwidesession-be

module.app_bucket
  aws_s3_bucket.this                  → dev-orgwidesession-be
  (+ versioning, encryption, lifecycle, public access block)
```

> The ECS service starts but the tasks will fail immediately because the ECR repository is empty — no Docker image has been pushed yet. This is expected. The tasks will become healthy after you complete Step 9.

### Verify the apply succeeded

```bash
# Check the ECS cluster was created
aws ecs describe-clusters --clusters dev-orgwidesession-be

# Check the ECR repository was created
aws ecr describe-repositories --repository-names dev-orgwidesession-be
```

---

## Step 8 — Collect Terraform Outputs

After the apply succeeds, read the outputs — these values become GitHub Secrets in the BE repo.

### Via GitHub Actions

In the Actions tab of OrgWideSession-IAC, open the completed apply run → expand the **Terraform Apply** step → scroll to the outputs section at the bottom. You will see:

```
ecr_repository_url         = "123456789012.dkr.ecr.us-east-1.amazonaws.com/dev-orgwidesession-be"
ecs_cluster_name           = "dev-orgwidesession-be"
ecs_service_name           = "dev-orgwidesession-be"
ecs_task_definition_family = "dev-orgwidesession-be"
ecs_container_name         = "orgwidesession-be"
ecs_log_group              = "/ecs/dev-orgwidesession-be"
```

### Via AWS CLI (if you ran Terraform locally)

```bash
cd environments/dev
terraform output
```

---

## Step 9 — Configure GitHub Secrets in OrgWideSession-BE

Go to **OrgWideSession-BE** → **Settings** → **Secrets and variables** → **Actions** → **New repository secret**

Add all eight secrets using the values from Step 8:

| Secret name | Where to get the value |
|---|---|
| `AWS_ACCESS_KEY_ID` | Access key ID for the BE deployer IAM user (Step 3b) |
| `AWS_SECRET_ACCESS_KEY` | Secret access key for the BE deployer IAM user (Step 3b) |
| `AWS_REGION` | `us-east-1` (or your region) |
| `ECR_REPOSITORY` | `dev-orgwidesession-be` (from `ecr_repository_url`, just the repo name — not the full URL) |
| `ECS_CLUSTER` | `dev-orgwidesession-be` |
| `ECS_SERVICE` | `dev-orgwidesession-be` |
| `ECS_TASK_DEFINITION` | `dev-orgwidesession-be` |
| `CONTAINER_NAME` | `orgwidesession-be` |

> **ECR_REPOSITORY** is just the repository name, not the full URL. The workflow constructs the full URI by combining the ECR registry URL (from `aws-actions/amazon-ecr-login` output) with this name.

---

## Step 10 — Configure GitHub Environment in OrgWideSession-BE

Go to **OrgWideSession-BE** → **Settings** → **Environments** → **New environment**

- Name: `production`
- Required reviewers: add yourself or your team (this gates every ECS deploy)
- Deployment branches: `main` only

---

## Step 11 — Deploy the Application (First Push)

Push code to the `main` branch of OrgWideSession-BE (or merge a PR into `main`).

The deploy workflow runs:

```
Push to main
       │
       ▼
  Configure AWS credentials
       │
       ▼
  Log in to ECR
       │
       ▼
  docker build -t <ECR_URL>:<SHA> .
  docker push
       │
       ▼
  Fetch current task definition from AWS   ← the one Terraform created
       │
       ▼
  Render new task definition               ← swap container image to new SHA
       │
       ▼
  Deploy to ECS service                    ← registers new task def revision
       │                                      ECS drains old tasks, starts new ones
       ▼
  Wait for service stability               ← polls until all new tasks are healthy
```

### What happens inside the new ECS task

When ECS starts a new task, the container runs `entrypoint.sh`:

```
1. alembic upgrade head    ← runs all pending database migrations
2. gunicorn main:app       ← starts the FastAPI app (1 worker, port 8000)
```

If `alembic upgrade head` fails (e.g. bad migration, database unreachable), the container exits immediately. ECS sees the task as unhealthy, does not replace the running tasks, and the deployment fails safely — your current version keeps running.

---

## Step 12 — Verify the Deployment

### Check ECS service health

```bash
aws ecs describe-services \
  --cluster dev-orgwidesession-be \
  --services dev-orgwidesession-be \
  --query "services[0].{status:status,running:runningCount,desired:desiredCount,pending:pendingCount}"
```

Expected output:
```json
{
  "status": "ACTIVE",
  "running": 1,
  "desired": 1,
  "pending": 0
}
```

### Get the task's public IP

```bash
# Get the task ARN
TASK_ARN=$(aws ecs list-tasks \
  --cluster dev-orgwidesession-be \
  --service-name dev-orgwidesession-be \
  --query "taskArns[0]" \
  --output text)

# Get the network interface ID
ENI=$(aws ecs describe-tasks \
  --cluster dev-orgwidesession-be \
  --tasks $TASK_ARN \
  --query "tasks[0].attachments[0].details[?name=='networkInterfaceId'].value" \
  --output text)

# Get the public IP
aws ec2 describe-network-interfaces \
  --network-interface-ids $ENI \
  --query "NetworkInterfaces[0].Association.PublicIp" \
  --output text
```

Then test: `curl http://<PUBLIC_IP>:8000/docs`

### Tail the logs

```bash
aws logs tail /ecs/dev-orgwidesession-be --follow
```

You should see the migration output followed by the gunicorn startup message:

```
==> Running database migrations...
INFO  [alembic.runtime.migration] Running upgrade ...
==> Migrations complete.
==> Starting application server...
[INFO] Starting gunicorn 21.2.0
[INFO] Listening at: http://0.0.0.0:8000
```

---

## Day-to-Day Operations

### Deploy a new version

Merge a PR into `main` in OrgWideSession-BE. The deploy workflow runs automatically.

### Roll back to a previous version

In OrgWideSession-BE → **Actions** → **Deploy — ECS Fargate** → **Run workflow**

This triggers a new deploy from the current `main` HEAD. To deploy a specific commit, check out that commit, create a branch, and merge it.

Alternatively, roll back via ECS directly:

```bash
# List recent task definition revisions
aws ecs list-task-definitions \
  --family-prefix dev-orgwidesession-be \
  --sort DESC

# Force the service to use a specific revision
aws ecs update-service \
  --cluster dev-orgwidesession-be \
  --service dev-orgwidesession-be \
  --task-definition dev-orgwidesession-be:5    # replace 5 with the revision you want
```

### Change infrastructure (CPU, memory, secrets, environment variables)

Edit `environments/dev/terraform.tfvars` → push to `development` → the Terraform workflow plans and applies the change.

> When you change the task definition in Terraform (e.g. add a new environment variable), Terraform registers a new task definition revision and ECS deploys it. The `lifecycle { ignore_changes = [task_definition] }` block on the ECS service means Terraform only resets the image when you explicitly change `container_image` in the module — it does not fight with the BE deploy workflow over which image is running.

### Update a secret value

1. Go to **Secrets Manager** → find `orgwidesession/dev/config` → **Edit**
2. Update the JSON value
3. Force a new ECS deployment to pick up the change (ECS only reads secrets at task start):

```bash
aws ecs update-service \
  --cluster dev-orgwidesession-be \
  --service dev-orgwidesession-be \
  --force-new-deployment
```

### View migration logs specifically

```bash
aws logs filter-log-events \
  --log-group-name /ecs/dev-orgwidesession-be \
  --filter-pattern "migration"
```

---

## Promoting to Production

The prod environment follows the same process. When you're ready:

1. Fill in `environments/prod/terraform.tfvars` with prod VPC, subnets, and a separate Secrets Manager secret ARN
2. Create the prod Secrets Manager secret (`orgwidesession/prod/config`) with production values
3. Merge to `main` in OrgWideSession-IAC — the Terraform workflow will plan for prod and wait for reviewer approval before applying
4. After Terraform applies, collect prod outputs and add them as GitHub Secrets in OrgWideSession-BE (create a second set of secrets or use GitHub Environments to scope them to a prod environment)

---

## Troubleshooting

### ECS tasks keep stopping immediately

**Symptom:** `runningCount` stays at 0, tasks stop within seconds.

**Check the logs:**
```bash
aws logs tail /ecs/dev-orgwidesession-be --follow
```

**Common causes:**
- `DATABASE_URL` is wrong — the app can't connect to the database
- A secret key in `secret_keys` doesn't exist in the Secrets Manager JSON — ECS fails to start the task before even running the container
- The database is unreachable from the ECS task's VPC/subnet/security group

### Migrations fail on deploy

**Symptom:** Deploy workflow fails at "Wait for service stability". Logs show an Alembic error.

The old tasks keep running — your app is still up. Fix the migration, push a new commit, and the deploy retries.

### "CannotPullContainerError" in ECS events

**Symptom:** Task fails with a container pull error.

**Causes:**
- The ECR image doesn't exist yet (push has not completed)
- The ECS execution role lacks ECR permissions (check `aws_iam_role_policy_attachment.execution_managed` in Terraform state)
- The task is in a private subnet with no NAT gateway — it can't reach ECR. Either add a NAT gateway or move tasks to public subnets and set `assign_public_ip = true`

### Terraform apply fails with "Error: creating ECS Service"

**Cause:** The subnet IDs or VPC ID in `terraform.tfvars` are wrong.

**Fix:** Double-check the IDs with `aws ec2 describe-subnets` and update `terraform.tfvars`.

### Secret value not updated after changing Secrets Manager

ECS reads secrets at **task start**, not continuously. After changing a secret value, force a new deployment:

```bash
aws ecs update-service \
  --cluster dev-orgwidesession-be \
  --service dev-orgwidesession-be \
  --force-new-deployment
```
