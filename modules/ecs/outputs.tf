output "cluster_id" {
  description = "ID of the ECS cluster"
  value       = aws_ecs_cluster.this.id
}

output "cluster_name" {
  description = "Name of the ECS cluster"
  value       = aws_ecs_cluster.this.name
}

output "service_name" {
  description = "Name of the ECS service — use this in the deploy workflow as ECS_SERVICE secret"
  value       = aws_ecs_service.this.name
}

output "task_definition_family" {
  description = "Task definition family name — use this in the deploy workflow as ECS_TASK_DEFINITION secret"
  value       = aws_ecs_task_definition.this.family
}

output "container_name" {
  description = "Container name inside the task definition — use this in the deploy workflow as CONTAINER_NAME secret"
  value       = var.name_suffix
}

output "execution_role_arn" {
  description = "ARN of the ECS execution role"
  value       = aws_iam_role.execution.arn
}

output "task_role_arn" {
  description = "ARN of the ECS task role"
  value       = aws_iam_role.task.arn
}

output "security_group_id" {
  description = "ID of the ECS tasks security group"
  value       = aws_security_group.ecs.id
}

output "log_group_name" {
  description = "CloudWatch log group name — tail logs with: aws logs tail <name> --follow"
  value       = aws_cloudwatch_log_group.this.name
}
