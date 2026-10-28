# GastoSync Core API (`gastosync_api`)

> Microsserviço de alta performance em **Go (Golang)** responsável por **Autenticação (JWT + Bcrypt)**, **Gestão de Conta** e **Sincronização Bidirecional** com o banco de dados **Neon Serverless PostgreSQL**.

---

## 1. Visão Geral e Arquitetura

O `gastosync_api` foi projetado como um microsserviço independente e blindado para isolar o núcleo financeiro e de segurança do aplicativo das rotinas experimentais de IA (`gastosync_agent`).

```text
┌────────────────────────────────────────────────────────┐
│           Cliente Flutter (gastosync_app)              │
│   📱 Mobile (Drift SQLite Offline)  |  💻 Web (Online) │
└──────────────────────────┬─────────────────────────────┘
                           │ HTTPS + Bearer JWT
                           ▼
┌────────────────────────────────────────────────────────┐
│            gastosync_api (Go + Fiber v2)               │
│   • Hospedado no Render.com (Container Docker ~15MB)   │
│   • Senhas com Hash Bcrypt (cost 12)                   │
│   • Validação estrita de user_id via JWT Middleware    │
│   • Driver nativo concorrente pgx/v5 (Connection Pool) │
└──────────────────────────┬─────────────────────────────┘
                           │ TLS / SSL (sslmode=require)
                           ▼
┌────────────────────────────────────────────────────────┐
│            Neon Serverless PostgreSQL                  │
│   • 1 GB de armazenamento permanente (Free Tier)       │
│   • Isolado da internet pública (acesso só via API)    │
└────────────────────────────────────────────────────────┘
```

---

## 2. Stack e Bibliotecas (Go)

- **Linguagem**: Go 1.23+
- **HTTP Framework**: [`github.com/gofiber/fiber/v2`](https://github.com/gofiber/fiber) (alta velocidade e baixíssimo consumo de memória)
- **Driver PostgreSQL**: [`github.com/jackc/pgx/v5/pgxpool`](https://github.com/jackc/pgx) (pool de conexões nativo compatível com o scale-to-zero do Neon)
- **Criptografia de Senhas**: `golang.org/x/crypto/bcrypt`
- **Tokens JWT**: [`github.com/golang-jwt/jwt/v5`](https://github.com/golang-jwt/jwt)
- **Variáveis de Ambiente**: [`github.com/joho/godotenv`](https://github.com/joho/godotenv)

---

## 3. Estrutura de Pastas Planejada

```text
gastosync_api/
├── cmd/
│   └── api/
│       └── main.go              # Ponto de entrada, CORS, rotas e graceful shutdown
├── internal/
│   ├── config/
│   │   └── config.go            # Leitura segura das variáveis de ambiente
│   ├── database/
│   │   ├── postgres.go          # Pool de conexão pgxpool com Neon SSL
│   │   └── migrations.sql       # Criação automática das tabelas (users, transactions, budgets)
│   ├── models/
│   │   └── models.go            # Structs de Usuário, Transação, Orçamento e DTOs
│   ├── middleware/
│   │   └── auth_middleware.go   # Extração e validação do JWT Bearer Token
│   └── handlers/
│       ├── auth_handler.go      # POST /api/v1/auth/register e POST /api/v1/auth/login
│       └── sync_handler.go      # POST /api/v1/sync/push e GET /api/v1/sync/pull
├── .dockerignore
├── .env.example                 # Template de variáveis (SEM segredos reais)
├── Dockerfile                   # Build multi-stage (golang:1.23-alpine -> alpine:3.20)
├── go.mod
└── README.md
```

---

## 4. Contratos de Endpoints

| Método | Rota | Autenticação | Descrição |
| :--- | :--- | :---: | :--- |
| `GET` | `/health` | Pública | Healthcheck para o Render monitorar o container |
| `POST` | `/api/v1/auth/register` | Pública | Cria conta com senha em Bcrypt e retorna JWT |
| `POST` | `/api/v1/auth/login` | Pública | Valida credenciais e retorna JWT + dados do perfil |
| `GET` | `/api/v1/auth/me` | Bearer JWT | Retorna os dados do usuário logado |
| `POST` | `/api/v1/sync/push` | Bearer JWT | Recebe lote de transações/metas locais e salva no Neon |
| `GET` | `/api/v1/sync/pull` | Bearer JWT | Retorna todas as transações e metas do usuário autenticado |

---

## 5. Como Rodar Localmente

### Opção A: Direto com Go
```bash
cd gastosync_api
cp .env.example .env
# Edite o arquivo .env com sua DATABASE_URL do Neon e um JWT_SECRET
go mod tidy
go run ./cmd/api
```

### Opção B: Com Docker
```bash
cd gastosync_api
docker build -t gastosync-api .
docker run --rm -p 8080:8080 --env-file .env gastosync-api
```

---

## 6. Guia Passo a Passo de Deploy em Nuvem (100% Gratuito e Seguro)

### Passo 1: Criar o Banco no Neon.tech (PostgreSQL)
1. Acesse [https://neon.tech](https://neon.tech) e crie uma conta gratuita.
2. Clique em **New Project**:
   - **Project Name**: `gastosync-db`
   - **Postgres Version**: `16` ou `17`
   - **Region**: Escolha `AWS US East (Ohio)` ou `AWS US East (N. Virginia)` (mesma região do Render para latência zero entre API e Banco).
3. No Dashboard do Neon, copie a **Connection String** (certifique-se de que termina com `?sslmode=require`):
   ```text
   postgresql://neondb_owner:SUA_SENHA@ep-xyz.us-east-2.aws.neon.tech/neondb?sslmode=require
   ```
4. **Segurança**: Guarde essa URL apenas para colar no painel do Render e no seu `.env` local (que está no `.gitignore`).

---

### Passo 2: Fazer Deploy da API Go (`gastosync_api`) no Render.com
1. Acesse [https://dashboard.render.com](https://dashboard.render.com) e clique em **New +** -> **Web Service**.
2. Conecte o seu repositório GitHub `GastoSync`.
3. Configure os campos do serviço:
   - **Name**: `gastosync-api`
   - **Region**: `Ohio (US East)` ou `Oregon` (preferencialmente a mesma região escolhida no Neon).
   - **Branch**: `master`
   - **Root Directory**: `gastosync_api` *(Muito importante! Assim o Render isola o deploy apenas nesta pasta)*.
   - **Runtime**: `Docker`
   - **Instance Type**: `Free`
4. Na seção **Environment Variables** do Render, adicione (clicando em *Add Environment Variable*):
   - `APP_ENV` = `production`
   - `DATABASE_URL` = *(Cole a Connection String do Neon copiada no Passo 1)*
   - `JWT_SECRET` = *(Gere no seu terminal com `openssl rand -hex 32` e cole aqui)*
   - `JWT_EXPIRATION_HOURS` = `168`
   - `CORS_ALLOWED_ORIGINS` = `*` *(ou a URL do seu Cloudflare Pages, ex: `https://gastosync.pages.dev`)*
5. Em **Advanced** -> **Health Check Path**, coloque: `/health`
6. Clique em **Create Web Service**. O Render construirá a imagem Docker e disponibilizará sua URL (ex: `https://gastosync-api.onrender.com`).

---

### Passo 3: Fazer Deploy do Agente IA (`gastosync_agent`) no Render.com (Separado)
1. No Render, clique em **New +** -> **Web Service** e selecione o mesmo repositório.
2. Configure:
   - **Name**: `gastosync-agent`
   - **Root Directory**: `gastosync_agent`
   - **Runtime**: `Python 3`
   - **Build Command**: `pip install -r requirements.txt`
   - **Start Command**: `uvicorn main:app --host 0.0.0.0 --port $PORT`
   - **Instance Type**: `Free`
3. Em **Environment Variables**:
   - `API_KEY_GROQ` = *(Chave da Groq Cloud)*

---

### Passo 4: Fazer Deploy do Frontend Web (`gastosync_app`) no Cloudflare Pages
1. No seu computador, gere a build Web apontando para a URL da sua API no Render:
   ```bash
   cd gastosync_app
   flutter build web --release \
     --dart-define=GASTOSYNC_CORE_API_URL=https://gastosync-api.onrender.com \
     --dart-define=GASTOSYNC_API_URL=https://gastosync-agent.onrender.com
   ```
2. Acesse o painel da [Cloudflare](https://dash.cloudflare.com/) -> **Workers & Pages** -> **Create** -> **Pages** -> **Upload assets** (ou via CLI `npx wrangler pages deploy build/web --project-name=gastosync`).
3. Nomeie o projeto como `gastosync` e envie a pasta `gastosync_app/build/web`.
4. Seu app estará no ar em `https://gastosync.pages.dev` com HTTPS automático e banda ilimitada!
