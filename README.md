# Cloud – Professor IA API

API NestJS que transforma qualquer pergunta em uma explicação estruturada pelo modelo Gemini 2.5 Flash, com foco em estudantes e linguagem de professor. Também expõe uma rota de health-check e documentação via Swagger.s

## Requisitos

- Node.js 18+
- Conta no Google AI Studio com chave do Gemini (`GEMINI_API_KEY`).

## Configuração

1. Instale as dependências:
   ```bash
   npm install
   ```
2. Crie um arquivo `.env` na raiz e defina:
   ```dotenv
   GEMINI_API_KEY=coloque_sua_chave
   PORT=3000 # opcional
   ```
3. Inicie o servidor:
   ```bash
   npm run start:dev
   ```
   A API ficará disponível em `http://localhost:3000` e a documentação em `http://localhost:3000/docs`.

## Rotas disponíveis

### `GET /health`

Verifica se o serviço está saudável.

**Resposta**

```json
{
  "status": "ok",
  "timestamp": 1700000000000
}
```

### `POST /study`

Envia uma pergunta em português para o professor virtual (Gemini 2.5 Flash) e retorna um plano de estudos estruturado.

**Body**

```json
{
  "question": "Explique o que é derivada e como aplicá-la em física."
}
```

**Resposta**

```json
{
  "question": "Explique o que é derivada e como aplicá-la em física.",
  "explanation": "1) Visão geral... 2) Conceitos-chave... 3) Exemplos... 4) Exercícios... 5) Próximos passos..."
}
```

#### Rate limit

A rota `/study` é protegida por um guard in-memory que limita cada origem/IP a **5 requisições por minuto**. Ultrapassar o limite resulta em `429 Too Many Requests`.

## Documentação Swagger

- Geração automática em `src/main.ts` usando `@nestjs/swagger`.
- Disponível em runtime via `GET /docs`.
- Inclui schemas para request/response do `/study` e do `/health`.

## Como funciona

- `AppController` recebe o POST `/study`, valida o payload e delega para `AppService`.
- `AppService` usa o SDK oficial `@google/generative-ai` para chamar o modelo Gemini 2.5 Flash com um prompt fixo em tom de professor.
- `RateLimitGuard` aplica o limite de 5 requisições/minuto por origem/IP.
- `HealthController` expõe o health-check simples.

## Scripts úteis

- `npm run start:dev`: modo desenvolvimento com watch.
- `npm run start:prod`: executa o build gerado em `dist`.
- `npm run test`: roda os testes unitários (controllers e guards).
- `npm run lint`: executa o ESLint.

## Testes

Execute:

```bash
npm test
```

## Observações

- O guard de rate limit usa memória local; para múltiplas instâncias considere Redis ou outro storage compartilhado.
- Garanta que o servidor possui a variável `GEMINI_API_KEY` antes de iniciar, caso contrário o serviço retornará `503`.

## Execução containerizada

### Docker

```bash
docker build -t cloud-api:latest .
docker run --rm -p 3000:3000 --env-file .env cloud-api:latest
```

### Docker Compose

1. Garanta um `.env` baseado no `.env.example`.
2. Suba os serviços:
   ```bash
   docker compose up --build
   ```
3. A API ficará disponível em `http://localhost:3000`.

## Infraestrutura com Terraform + AWS

Os manifests estão em `infra/terraform` e criam:

- Repositório ECR para a imagem do app.
- VPC pública com 2 subnets, security groups e Internet Gateway.
- Application Load Balancer exposto publicamente (use o DNS de saída como endpoint).
- Cluster ECS Fargate, task definition e service com logs no CloudWatch.

### Pré-requisitos

1. Terraform >= 1.8
2. AWS CLI autenticado (perfil com permissões para ECS, EC2, IAM, ELB, CloudWatch Logs, ECR, SSM, S3 e DynamoDB).
3. Bucket S3 + tabela DynamoDB para o state remoto:
   ```bash
   aws s3 mb s3://meu-terraform-state
   aws dynamodb create-table \
     --table-name terraform-locks \
     --attribute-definitions AttributeName=LockID,AttributeType=S \
     --key-schema AttributeName=LockID,KeyType=HASH \
     --billing-mode PAY_PER_REQUEST
   ```
4. Parâmetros no AWS Systems Manager Parameter Store contendo o `GEMINI_API_KEY` por ambiente:
   ```bash
   aws ssm put-parameter \
     --name gemini-api-key-staging \
     --value "minha-chave" \
     --type SecureString
   ```
   Utilize nomes/ARNs que correspondam aos valores dos arquivos `infra/terraform/environments/*.tfvars`.

### Passo a passo

1. Entre na pasta:
   ```bash
   cd infra/terraform
   ```
2. Inicialize apontando o backend remoto (exemplo para staging):
   ```bash
   terraform init \
     -backend-config="bucket=meu-terraform-state" \
     -backend-config="key=environments/staging/terraform.tfstate" \
     -backend-config="region=us-east-1" \
     -backend-config="dynamodb_table=terraform-locks"
   ```
3. Aplique usando o `tfvars` do ambiente e a tag da imagem que deseja rodar (por padrão `latest`):
   ```bash
   terraform apply \
     -var-file="environments/staging.tfvars" \
     -var="image_tag=latest"
   ```
4. Anote os outputs:
   - `alb_dns_name`: endpoint público.
   - `ecr_repository_url`: destino para `docker push`.

Repita o processo para `production` usando `environments/production.tfvars` e um backend `key` diferente.

## CI/CD com GitHub Actions

Dois workflows foram adicionados em `.github/workflows`:

- `deploy-staging.yml`: executa testes, builda/pusha a imagem para o ECR e roda `terraform apply` usando `environments/staging.tfvars` sempre que houver `push` na branch `staging`.
- `deploy-production.yml`: mesmo fluxo, disparado por `push` na `main`.

### Segredos requeridos

Configure em **Settings → Secrets → Actions**:

- `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY`
- `AWS_REGION`
- `TF_STATE_BUCKET`
- `TF_STATE_DYNAMO_TABLE`
- `TF_STATE_KEY_STAGING` (ex.: `environments/staging/terraform.tfstate`)
- `TF_STATE_KEY_PRODUCTION` (ex.: `environments/production/terraform.tfstate`)

Os arquivos `environments/*.tfvars` definem o ARN do parâmetro SSM usado por cada ambiente. Garanta que o parâmetro exista antes do deploy. A cada pipeline a imagem recebe a tag `GITHUB_SHA` e o Terraform atualiza o serviço ECS apontando para essa nova tag, publicando automaticamente a API via ALB público.

> **Dica:** execute pelo menos um `terraform apply` manual por ambiente antes de habilitar os workflows para garantir que o repositório ECR e o restante da infraestrutura existam quando o CI/CD tentar publicar a imagem.
