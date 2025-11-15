output "alb_dns_name" {
  description = "Public DNS name for the load balancer."
  value       = aws_lb.api.dns_name
}

output "ecr_repository_url" {
  description = "ECR repository URL for the API container image."
  value       = aws_ecr_repository.api.repository_url
}

output "ecs_cluster_name" {
  description = "ECS cluster created for the service."
  value       = aws_ecs_cluster.api.name
}
