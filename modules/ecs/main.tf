# ECS Fargate module.
# Creates everything needed to run a containerised service on AWS Fargate:
#   - ECS Cluster (with Container Insights for metrics/logs)
#   - CloudWatch Log Group (for container stdout/stderr)
#   - IAM Execution Role (ECR pull + Secrets Manager read + CloudWatch write)
#   - IAM Task Role (app-level AWS permissions, e.g. S3 access)
#   - Security Group (ingress on container port, full egress for external DB/ECR)
#   - Task Definition (Fargate, awsvpc, with secrets from Secrets Manager)
#   - ECS Service (rolling deploys, desired task count)

locals {
  name_prefix = "${var.environment}-${var.name_suffix}"
}

# ── ECS Cluster ───────────────────────────────────────────────────
resource "aws_ecs_cluster" "this" {
  name = local.name_prefix

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  tags = merge(var.tags, { Name = local.name_prefix })
}

# ── CloudWatch Log Group ──────────────────────────────────────────
resource "aws_cloudwatch_log_group" "this" {
  name              = "/ecs/${local.name_prefix}"
  retention_in_days = var.environment == "prod" ? 90 : 14

  tags = merge(var.tags, { Name = "/ecs/${local.name_prefix}" })
}

# ── IAM — Execution Role ──────────────────────────────────────────
# Used by the ECS agent (not the app) to:
#   - Pull the Docker image from ECR
#   - Fetch secret values from Secrets Manager at task start
#   - Write logs to CloudWatch
resource "aws_iam_role" "execution" {
  name = "${local.name_prefix}-ecs-execution"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = { Service = "ecs-tasks.amazonaws.com" }
        Action    = "sts:AssumeRole"
      }
    ]
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "execution_managed" {
  role       = aws_iam_role.execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# Allow the execution role to read the specific Secrets Manager secret.
resource "aws_iam_role_policy" "execution_secrets" {
  name = "secrets-manager-read"
  role = aws_iam_role.execution.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["secretsmanager:GetSecretValue"]
        Resource = [var.secrets_manager_arn]
      }
    ]
  })
}

# ── IAM — Task Role ───────────────────────────────────────────────
# Used by the running application (not the ECS agent).
# Grants app-level AWS permissions: S3 for image uploads.
resource "aws_iam_role" "task" {
  name = "${local.name_prefix}-ecs-task"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = { Service = "ecs-tasks.amazonaws.com" }
        Action    = "sts:AssumeRole"
      }
    ]
  })

  tags = var.tags
}

# Attach no managed policies to task role — add specific permissions as needed.
# For example, if the app uses S3 directly via the task role, add an inline policy here.

# ── Security Group ────────────────────────────────────────────────
resource "aws_security_group" "ecs" {
  name        = "${local.name_prefix}-ecs"
  description = "ECS Fargate tasks — ${local.name_prefix}"
  vpc_id      = var.vpc_id

  # Allow inbound traffic on the container port.
  ingress {
    from_port   = var.container_port
    to_port     = var.container_port
    protocol    = "tcp"
    cidr_blocks = var.allowed_ingress_cidrs
    description = "Container port"
  }

  # Full outbound: tasks need to reach ECR, Secrets Manager, CloudWatch,
  # and the external PostgreSQL database.
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound"
  }

  tags = merge(var.tags, { Name = "${local.name_prefix}-ecs" })
}

# ── Task Definition ───────────────────────────────────────────────
# Builds the container definition inline using jsonencode so Terraform can
# track changes and generate meaningful diffs.
#
# Secrets: each key in var.secret_keys is fetched from Secrets Manager at
# task start using the JSON key path syntax:
#   "<SECRET_ARN>:<json-key>::"
#
# This requires the Secrets Manager secret to be a flat JSON object:
#   { "database_url": "postgres://...", "client_id": "...", ... }
resource "aws_ecs_task_definition" "this" {
  family                   = local.name_prefix
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = tostring(var.cpu)
  memory                   = tostring(var.memory)
  execution_role_arn       = aws_iam_role.execution.arn
  task_role_arn            = aws_iam_role.task.arn

  container_definitions = jsonencode([
    {
      name      = var.name_suffix
      image     = var.container_image
      essential = true

      portMappings = [
        {
          containerPort = var.container_port
          protocol      = "tcp"
        }
      ]

      # Non-sensitive config — safe to define here.
      environment = [
        for k, v in var.container_environment : { name = k, value = v }
      ]

      # Sensitive config — fetched from Secrets Manager at task start.
      # Pattern: "<secret-arn>:<json-key>::"
      secrets = [
        for key in var.secret_keys : {
          name      = upper(key)
          valueFrom = "${var.secrets_manager_arn}:${key}::"
        }
      ]

      healthCheck = {
        command = [
          "CMD",
          "python",
          "-c",
          "import urllib.request; urllib.request.urlopen('http://localhost:${var.container_port}${var.health_check_path}')"
        ]
        interval    = 30
        timeout     = 5
        retries     = 3
        startPeriod = var.health_check_start_period
      }

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.this.name
          "awslogs-region"        = data.aws_region.current.name
          "awslogs-stream-prefix" = "ecs"
        }
      }
    }
  ])

  tags = merge(var.tags, { Name = local.name_prefix })
}

data "aws_region" "current" {}

# ── ECS Service ───────────────────────────────────────────────────
# Rolling deploy: minimum 50%, maximum 200% — ensures zero-downtime deploys
# without needing to over-provision capacity.
resource "aws_ecs_service" "this" {
  name            = local.name_prefix
  cluster         = aws_ecs_cluster.this.id
  task_definition = aws_ecs_task_definition.this.arn
  desired_count   = var.desired_count
  launch_type     = "FARGATE"

  # Force a new deployment whenever Terraform detects a task definition change.
  force_new_deployment = true

  network_configuration {
    subnets          = var.subnet_ids
    security_groups  = [aws_security_group.ecs.id]
    assign_public_ip = var.assign_public_ip
  }

  deployment_minimum_healthy_percent = 50
  deployment_maximum_percent         = 200

  # Ignore image changes made outside Terraform (e.g. by the BE deploy workflow).
  # The ECS service's task definition revision is updated by the deploy pipeline,
  # not by Terraform — so Terraform should not try to revert those changes.
  lifecycle {
    ignore_changes = [task_definition]
  }

  tags = merge(var.tags, { Name = local.name_prefix })

  depends_on = [aws_iam_role_policy_attachment.execution_managed]
}
