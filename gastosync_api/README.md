# GastoSync Core API (`gastosync_api`)

> Microsserviço em **Go (Golang)** responsável por **Autenticação (JWT + Bcrypt)**, **Gestão de Conta** e **Sincronização de Dados** com o **PostgreSQL (Neon)**.

---

## Stack e Bibliotecas

- **Linguagem**: Go 1.23+
- **HTTP Framework**: `github.com/gofiber/fiber/v2`
- **Driver PostgreSQL**: `github.com/jackc/pgx/v5/pgxpool`
- **Criptografia de Senhas**: `golang.org/x/crypto/bcrypt`
- **Tokens JWT**: `github.com/golang-jwt/jwt/v5`
- **Configuração**: `github.com/joho/godotenv`

---

## Estrutura de Diretórios

```text
gastosync_api/
├── cmd/
│   └── api/
│       └── main.go              # Entrypoint HTTP, middlewares e rotas
├── internal/
│   ├── config/
│   │   └── config.go            # Carregamento e validação de variáveis de ambiente
│   ├── database/
│   │   └── postgres.go          # Pool pgxpool e migrações automáticas (users, transactions, budgets)
│   ├── models/
│   │   └── models.go            # Entidades de domínio e DTOs de requisição/resposta
│   ├── middleware/
│   │   └── auth_middleware.go   # Validação de Bearer Token JWT
│   └── handlers/
│       ├── auth_handler.go      # Registro, login e perfil do usuário
│       └── sync_handler.go      # Sincronização push e pull de transações e metas
├── .dockerignore
├── .env.example
├── Dockerfile
└── go.mod
```

---

## Endpoints da API

| Método | Rota | Autenticação | Descrição |
| :--- | :--- | :---: | :--- |
| `GET` | `/health` | Pública | Verificação de integridade do serviço |
| `POST` | `/api/v1/auth/register` | Pública | Cadastro de usuário e emissão de JWT |
| `POST` | `/api/v1/auth/login` | Pública | Autenticação de usuário e emissão de JWT |
| `GET` | `/api/v1/auth/me` | Bearer JWT | Dados do perfil autenticado |
| `POST` | `/api/v1/sync/push` | Bearer JWT | Envio de transações e metas locais para o banco central |
| `GET` | `/api/v1/sync/pull` | Bearer JWT | Consulta de transações e metas do usuário autenticado |

---

## Desenvolvimento Local

1. Copie o template de variáveis de ambiente:
   ```bash
   cp .env.example .env
   ```
2. Preencha `DATABASE_URL` e `JWT_SECRET` no arquivo `.env` local (ignorado pelo Git).
3. Baixe as dependências e inicie o servidor:
   ```bash
   go mod tidy
   go run ./cmd/api
   ```

Para testar via container Docker localmente:
```bash
docker build -t gastosync-api .
docker run --rm -p 8080:8080 --env-file .env gastosync-api
```
