variable "aws_region" {
  description = "AWS region where the resources will be created."
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Base name used for tagging and resource naming."
  type        = string
  default     = "cloud-api"
}

variable "environment" {
  description = "Environment name (e.g., staging, production)."
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC."
  type        = string
  default     = "10.0.0.0/16"
}

variable "container_port" {
  description = "Port exposed by the NestJS container."
  type        = number
  default     = 3000
}

variable "container_cpu" {
  description = "Fargate CPU units."
  type        = number
  default     = 256
}

variable "container_memory" {
  description = "Fargate memory (MiB)."
  type        = number
  default     = 512
}

variable "desired_count" {
  description = "Desired ECS tasks."
  type        = number
  default     = 1
}

variable "health_check_path" {
  description = "HTTP path for the load balancer health check."
  type        = string
  default     = "/health"
}

variable "image_tag" {
  description = "Container image tag deployed by Terraform."
  type        = string
  default     = "latest"
}

variable "gemini_api_key_ssm_parameter_name" {
  description = "ARN or name of the SSM parameter that stores the GEMINI_API_KEY secret."
  type        = string
  default     = ""
}

variable "default_tags" {
  description = "Optional default tags applied to every resource."
  type        = map(string)
  default     = {}
}
