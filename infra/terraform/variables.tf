variable "aws_region" {
  description = "Região AWS onde os recursos serão criados."
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Nome base usado para tagging e nomeação de recursos."
  type        = string
  default     = "cloud-api"
}

variable "environment" {
  description = "Nome do ambiente (ex: staging, production)."
  type        = string
}

variable "vpc_cidr" {
  description = "Bloco CIDR para a VPC."
  type        = string
  default     = "10.0.0.0/16"
}

variable "container_port" {
  description = "Porta exposta pelo container NestJS."
  type        = number
  default     = 3000
}

variable "container_cpu" {
  description = "Unidades de CPU Fargate."
  type        = number
  default     = 256
}

variable "container_memory" {
  description = "Memória Fargate (MiB)."
  type        = number
  default     = 512
}

variable "desired_count" {
  description = "Tarefas ECS desejadas."
  type        = number
  default     = 1
}

variable "health_check_path" {
  description = "Caminho HTTP para o check de saúde do load balancer."
  type        = string
  default     = "/health"
}

variable "image_tag" {
  description = "Tag da imagem do container implantada pelo Terraform."
  type        = string
  default     = "latest"
}

variable "gemini_api_key_ssm_parameter_name" {
  description = "ARN ou nome do parâmetro SSM que armazena a chave GEMINI_API_KEY secreta."
  type        = string
  default     = ""
}

variable "default_tags" {
  description = "Tags padrão opcionais aplicadas a todos os recursos."
  type        = map(string)
  default     = {}
}
