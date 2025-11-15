# Cloud – Professor IA API

API NestJS que transforma qualquer pergunta em uma explicação estruturada pelo modelo Gemini 2.5 Flash, com foco em estudantes e linguagem de professor. Também expõe uma rota de health-check e documentação via Swagger.

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
