terraform {
  required_version = ">= 1.8.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# ============================================================================
# DATA SOURCES (Dados consultados da AWS)
# ============================================================================
data "aws_caller_identity" "current" {}

data "aws_availability_zones" "available" {
  state = "available"
}

# ============================================================================
# LOCALS (Variáveis locais reutilizáveis)
# ============================================================================
locals {
  # Seleciona as 2 primeiras zonas de disponibilidade para alta disponibilidade
  azs = slice(data.aws_availability_zones.available.names, 0, 2)

  # Define tags padrão que serão aplicadas em todos os recursos
  tags = merge(
    {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "terraform"
    },
    var.default_tags,
  )
}

# ============================================================================
# ECR (Elastic Container Registry) - Repositório de Imagens Docker
# ============================================================================
# Cria um repositório no ECR para armazenar as imagens Docker da aplicação
resource "aws_ecr_repository" "api" {
  name = "${var.project_name}-${var.environment}"

  image_tag_mutability = "MUTABLE"

  tags = local.tags
}

# ============================================================================
# NETWORKING - VPC, Subnets e Roteamento
# ============================================================================
# Cria a VPC (Virtual Private Cloud) - rede isolada na AWS
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true   # Permite resolução de DNS dentro da VPC
  enable_dns_hostnames = true   # Permite usar hostnames para instâncias

  tags = merge(local.tags, { Name = "${var.project_name}-${var.environment}-vpc" })
}

# Internet Gateway - permite comunicação com a internet
resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.main.id
  tags   = merge(local.tags, { Name = "${var.project_name}-${var.environment}-igw" })
}

# Cria 2 subnets públicas em zonas de disponibilidade diferentes
# Subnets públicas = recursos que podem acessar a internet diretamente
# Usamos 2 subnets para alta disponibilidade (se uma zona cair, a outra continua)
resource "aws_subnet" "public" {
  count                   = 2
  vpc_id                  = aws_vpc.main.id
  cidr_block              = cidrsubnet(var.vpc_cidr, 4, count.index)
  availability_zone       = element(local.azs, count.index)           
  map_public_ip_on_launch = true 

  tags = merge(
    local.tags,
    {
      Name = "${var.project_name}-${var.environment}-public-${count.index}"
    },
  )
}

# Tabela de roteamento para as subnets públicas
# Define como o tráfego será roteado dentro da VPC
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  tags   = merge(local.tags, { Name = "${var.project_name}-${var.environment}-public-rt" })
}

# Rota padrão: todo tráfego (0.0.0.0/0) vai para o Internet Gateway
resource "aws_route" "internet_access" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.gw.id
}

# Associa as subnets públicas à tabela de roteamento
resource "aws_route_table_association" "public" {
  count          = 2
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# ============================================================================
# SECURITY GROUPS
# ============================================================================
# Security Group para o Application Load Balancer (ALB)
# Define quais portas podem receber tráfego do ALB
resource "aws_security_group" "alb" {
  name   = "${var.project_name}-${var.environment}-alb"
  vpc_id = aws_vpc.main.id

  # Permite tráfego HTTP (porta 80) de qualquer lugar (0.0.0.0/0)
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Permite todo tráfego de saída
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = local.tags
}

# Security Group para o serviço ECS (containers)
# Apenas o ALB pode acessar os containers diretamente (segurança em camadas)
resource "aws_security_group" "service" {
  name   = "${var.project_name}-${var.environment}-service"
  vpc_id = aws_vpc.main.id

  # Permite tráfego apenas do ALB (não diretamente da internet)
  # Isso garante que os containers não sejam acessíveis publicamente
  ingress {
    from_port       = var.container_port
    to_port         = var.container_port
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]  # Apenas do ALB
  }

  # Permite todo tráfego de saída (containers podem acessar internet para APIs externas)
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = local.tags
}

# ============================================================================
# LOAD BALANCER - Distribuição de Carga e Alta Disponibilidade
# ============================================================================
# Application Load Balancer (ALB)
# Distribui o tráfego entre múltiplos containers para alta disponibilidade
resource "aws_lb" "api" {
  name               = "${var.project_name}-${var.environment}"
  load_balancer_type = "application"  # ALB (Application Load Balancer)
  internal           = false          # Público 
  security_groups    = [aws_security_group.alb.id]
  subnets            = aws_subnet.public[*].id  # Distribuído em múltiplas subnets

  tags = local.tags
}

# Target Group - define para onde o ALB vai rotear o tráfego
# Os containers ECS serão registrados aqui como "targets"
resource "aws_lb_target_group" "api" {
  name        = "${var.project_name}-${var.environment}"
  port        = var.container_port
  protocol    = "HTTP"
  target_type = "ip" 
  vpc_id      = aws_vpc.main.id

  # Health Check
  # Se um container não responder, o ALB para de enviar tráfego para ele
  health_check {
    interval            = 30              # Verifica a cada 30 segundos
    healthy_threshold   = 2                # Precisa de 2 checks sucessivos para considerar saudável
    unhealthy_threshold = 5                # 5 checks falhos para considerar não saudável
    matcher             = "200-399"        # Aceita códigos HTTP 200-399 como saudável
    path                = var.health_check_path  # Endpoint de health check
    port                = "traffic-port"   # Usa a mesma porta do tráfego
  }

  tags = local.tags
}

# Listener - "escuta" na porta 80 e roteia para o target group
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.api.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.api.arn
  }
}

# ============================================================================
# CLOUDWATCH LOGS - Centralização de Logs
# ============================================================================
resource "aws_cloudwatch_log_group" "api" {
  name              = "/ecs/${var.project_name}-${var.environment}"
  retention_in_days = 14  # Mantém logs por 14 dias
  tags              = local.tags
}

# ============================================================================
# IAM ROLES - Permissões e Segurança
# ============================================================================
# Policy document que permite ao serviço ECS assumir estas roles
data "aws_iam_policy_document" "task_execution_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]  # Serviço ECS pode assumir esta role
    }
  }
}

# Role de Execução - usada pelo ECS para:
# - Fazer pull de imagens do ECR
# - Enviar logs para CloudWatch
# - Buscar secrets do SSM Parameter Store
resource "aws_iam_role" "task_execution" {
  name               = "${var.project_name}-${var.environment}-execution"
  assume_role_policy = data.aws_iam_policy_document.task_execution_assume_role.json
  tags               = local.tags
}

# Anexa a política padrão do ECS para execução de tasks
# Permite pull de imagens do ECR e envio de logs para CloudWatch
resource "aws_iam_role_policy_attachment" "task_execution" {
  role       = aws_iam_role.task_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# Policy customizada para acessar secrets no SSM Parameter Store
# Permite que os containers busquem a chave da API Gemini de forma segura
data "aws_iam_policy_document" "task_execution_ssm" {
  statement {
    effect = "Allow"

    actions = [
      "ssm:GetParameter",
      "ssm:GetParameters",
      "ssm:GetParametersByPath",
    ]

    # Permite acesso apenas aos parâmetros que começam com "gemini-api-key-"
    resources = [
      "arn:aws:ssm:${var.aws_region}:${data.aws_caller_identity.current.account_id}:parameter/gemini-api-key-*",
    ]
  }
}

# Anexa a policy customizada à role de execução
resource "aws_iam_role_policy" "task_execution_ssm" {
  name   = "${var.project_name}-${var.environment}-execution-ssm"
  role   = aws_iam_role.task_execution.id
  policy = data.aws_iam_policy_document.task_execution_ssm.json
}

# Role da Task - usada pela aplicação em execução
# Pode ser usada para dar permissões específicas à aplicação
resource "aws_iam_role" "task" {
  name               = "${var.project_name}-${var.environment}-task"
  assume_role_policy = data.aws_iam_policy_document.task_execution_assume_role.json
  tags               = local.tags
}

# ============================================================================
# ECS CLUSTER - Orquestração de Containers
# ============================================================================
# Cria um cluster ECS
resource "aws_ecs_cluster" "api" {
  name = "${var.project_name}-${var.environment}"
  tags = local.tags
}

# ============================================================================
# LOCALS - Configurações do Container
# ============================================================================
locals {
  container_image = "${aws_ecr_repository.api.repository_url}:${var.image_tag}"

  # Configura secrets do SSM Parameter Store
  container_secrets = var.gemini_api_key_ssm_parameter_name == "" ? [] : [
    {
      name      = "GEMINI_API_KEY"
      valueFrom = var.gemini_api_key_ssm_parameter_name
    }
  ]
}

# ============================================================================
# ECS TASK DEFINITION - Template do Container
# ============================================================================
# Define como o container deve ser executado (CPU, memória, imagem, variáveis, etc)
resource "aws_ecs_task_definition" "api" {
  family                   = "${var.project_name}-${var.environment}"
  cpu                      = tostring(var.container_cpu)      # CPU alocada (ex: 256 = 0.25 vCPU)
  memory                   = tostring(var.container_memory)    # Memória alocada (ex: 512 = 512 MB)
  network_mode             = "awsvpc"                          # Usa a VPC para networking
  requires_compatibilities = ["FARGATE"]                       # Usa Fargate (serverless, sem gerenciar servidores)
  execution_role_arn       = aws_iam_role.task_execution.arn   # Role para executar a task
  task_role_arn            = aws_iam_role.task.arn            # Role para a aplicação dentro do container

  # Define a configuração do container
  container_definitions = jsonencode([
    {
      name      = "api"
      image     = local.container_image  # Imagem Docker do ECR
      essential = true                   # Se este container falhar, a task inteira falha

      # Mapeamento de portas - expõe a porta do container
      portMappings = [
        {
          containerPort = var.container_port  # Porta dentro do container
          hostPort      = var.container_port  # Porta no host (Fargate)
          protocol      = "tcp"
        }
      ]

      # Configuração de logs - envia logs para CloudWatch
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.api.name
          awslogs-region        = var.aws_region
          awslogs-stream-prefix = "ecs"
        }
      }

      # Variáveis de ambiente - disponíveis dentro do container
      environment = [
        {
          name  = "PORT"
          value = tostring(var.container_port)
        },
        {
          name  = "NODE_ENV"
          value = var.environment  # staging, production, etc
        }
      ]

      # Secrets - variáveis sensíveis do SSM Parameter Store
      # São injetadas como variáveis de ambiente, mas de forma segura
      secrets = local.container_secrets

      # Health Check - verifica se o container está saudável
      # Executa um comando dentro do container periodicamente
      healthCheck = {
        command  = ["CMD-SHELL", "curl -f http://localhost:${var.container_port}${var.health_check_path} || exit 1"]
        interval = 30  # Executa a cada 30 segundos
        retries  = 3   # Tenta 3 vezes antes de considerar não saudável
        timeout  = 5   # Timeout de 5 segundos
      }
    }
  ])

  tags = local.tags
}

# ============================================================================
# ECS SERVICE - Serviço em Execução
# ============================================================================
# O serviço mantém os containers rodando e garante o número desejado de instâncias
# Se um container cair, o ECS automaticamente inicia um novo
resource "aws_ecs_service" "api" {
  name            = "${var.project_name}-${var.environment}"
  cluster         = aws_ecs_cluster.api.id
  task_definition = aws_ecs_task_definition.api.arn  # Qual template usar
  desired_count   = var.desired_count                 # Quantos containers manter rodando
  launch_type     = "FARGATE"                         # Usa Fargate (serverless)

  # Configuração de rede - onde os containers vão rodar
  network_configuration {
    subnets          = aws_subnet.public[*].id        # Subnets públicas
    security_groups  = [aws_security_group.service.id]  # Firewall do container
    assign_public_ip = true                          # IP público para acessar internet
  }

  # Integração com o Load Balancer
  # Registra os containers no ALB para receber tráfego
  load_balancer {
    target_group_arn = aws_lb_target_group.api.arn
    container_name   = "api"
    container_port   = var.container_port
  }

  # Lifecycle hook - evita que o Terraform sobrescreva atualizações manuais
  # Útil quando você atualiza a task definition manualmente (ex: novo deploy)
  lifecycle {
    ignore_changes = [task_definition]
  }

  # Garante que o listener do ALB existe antes de criar o serviço
  depends_on = [aws_lb_listener.http]

  tags = local.tags
}
