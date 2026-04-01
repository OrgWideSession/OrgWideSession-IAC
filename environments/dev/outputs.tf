output "bucket_id" {
  description = "Name of the S3 bucket"
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

output "ecr_repository_url" {
  description = "ECR repository URL — set this as ECR_REPOSITORY in the BE deploy workflow"
  value       = module.ecr.repository_url
}

output "ecs_cluster_name" {
  description = "ECS cluster name — set this as ECS_CLUSTER in the BE deploy workflow"
  value       = module.ecs.cluster_name
}

output "ecs_service_name" {
  description = "ECS service name — set this as ECS_SERVICE in the BE deploy workflow"
  value       = module.ecs.service_name
}

output "ecs_task_definition_family" {
  description = "Task definition family — set this as ECS_TASK_DEFINITION in the BE deploy workflow"
  value       = module.ecs.task_definition_family
}

output "ecs_container_name" {
  description = "Container name in the task definition — set this as CONTAINER_NAME in the BE deploy workflow"
  value       = module.ecs.container_name
}

output "ecs_log_group" {
  description = "CloudWatch log group — tail with: aws logs tail <name> --follow"
  value       = module.ecs.log_group_name
}
