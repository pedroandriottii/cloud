output "alb_dns_name" {
  description = "URL pública do load balancer."
  value       = aws_lb.api.dns_name
}

output "ecr_repository_url" {
  description = "URL do repositório ECR para a imagem do container da API."
  value       = aws_ecr_repository.api.repository_url
}

output "ecs_cluster_name" {
  description = "Cluster ECS criado para o serviço."
  value       = aws_ecs_cluster.api.name
}
