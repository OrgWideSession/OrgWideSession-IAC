output "repository_url" {
  description = "Full ECR repository URL — use this as the image base URI in ECS task definitions and CI/CD pipelines"
  value       = aws_ecr_repository.this.repository_url
}

output "repository_arn" {
  description = "ARN of the ECR repository — use this in IAM policies"
  value       = aws_ecr_repository.this.arn
}

output "repository_name" {
  description = "Short name of the ECR repository"
  value       = aws_ecr_repository.this.name
}
