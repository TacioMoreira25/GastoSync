# GastoSync

> Plataforma multiplataforma de gestão financeira pessoal (Android e Web) com operação Offline-First, API Core em Go e Agente Preditivo por IA.

<p align="left">
  <img src="https://img.shields.io/badge/FLUTTER%203-02569B?style=for-the-badge&logo=flutter&logoColor=white" height="28" alt="Flutter 3" />
  <img src="https://img.shields.io/badge/DART%203-0175C2?style=for-the-badge&logo=dart&logoColor=white" height="28" alt="Dart 3" />
  <img src="https://img.shields.io/badge/GO%201.24+-00ADD8?style=for-the-badge&logo=go&logoColor=white" height="28" alt="Go" />
  <img src="https://img.shields.io/badge/POSTGRESQL%20%2F%20NEON-4169E1?style=for-the-badge&logo=postgresql&logoColor=white" height="28" alt="PostgreSQL Neon" />
  <img src="https://img.shields.io/badge/DRIFT%20%2F%20SQLITE-003B57?style=for-the-badge&logo=sqlite&logoColor=white" height="28" alt="Drift SQLite" />
  <img src="https://img.shields.io/badge/CLOUDFLARE%20PAGES-F38020?style=for-the-badge&logo=cloudflare&logoColor=white" height="28" alt="Cloudflare Pages" />
  <img src="https://img.shields.io/badge/GROQ%20%2F%20LLAMA%203.3-F55036?style=for-the-badge&logo=meta&logoColor=white" height="28" alt="Groq AI" />
</p>

---

## Acesso em Produção e Download

- **Versão Web (Cloudflare Pages):** [`https://gastosync.pages.dev`](https://gastosync.pages.dev)
- **Instalador Android (`.apk`):** Acesse [**Releases**](https://github.com/TacioMoreira25/GastoSync/releases/latest) para baixar a versão mais recente em produção (`gastosync-v*.apk`).
- **API Core (Go / Render):** [`https://gastosync-api.onrender.com/health`](https://gastosync-api.onrender.com/health)
- **Agente de IA (Python / Render):** [`https://gastosync-agent.onrender.com/api/v1/agent/status`](https://gastosync-agent.onrender.com/api/v1/agent/status)

---

## Arquitetura do Monorepo

```text
gasto-sync/
├── .specify/          # Governança e constituição arquitetural (Spec-Driven Development)
├── .specs/            # Especificações funcionais, plano técnico e backlog de tarefas
├── gastosync_app/     # Cliente Flutter Multiplataforma (Android Offline-First & Web WASM)
├── gastosync_api/     # API Core em Go (Autenticação JWT/OTP/LGPD, Sync e PostgreSQL)
└── gastosync_agent/   # Serviço Satélite em Python (FastAPI + Groq SDK) para IA e OCR
```

- **Cliente (`gastosync_app`)**: Layout responsivo adaptativo (`< 800px` Mobile com barra inferior e `>= 800px` Web Desktop com barra lateral), operação **Offline-First** via SQLite nativo (`Drift`) no Android e SQLite WASM / IndexedDB na Web, cálculo determinístico de 9 indicadores financeiros e sincronização bidirecional.
- **API Core (`gastosync_api`)**: Microsserviço em Go (`Fiber v2` + `pgx/v5`) conectado ao Neon PostgreSQL (Auth com senha forte OWASP, OTP 6 dígitos, recuperação de senha, exclusão definitiva de conta LGPD, boletos 2x/dia e Sync).
- **Agente IA (`gastosync_agent/app`)**: Serviço satélite em Python (`FastAPI` + `Groq`) para categorização em linguagem natural, OCR de comprovantes/boletos (`qwen/qwen3.8-27b`), assistente conversacional com contexto orçamentário e fallback automático de modelos.

---

## Como Executar Localmente

### 1. API Core em Go (`gastosync_api`)

```bash
cd gastosync_api
cp .env.example .env # Preencha DATABASE_URL e JWT_SECRET no arquivo .env
go mod tidy
go run ./cmd/api
```

### 2. App Flutter (`gastosync_app`)

```bash
cd gastosync_app
flutter pub get

# Web (Chrome ou servidor local)
flutter run -d chrome
flutter run -d web-server --web-hostname=localhost --web-port=3000

# Android (Emulador ou dispositivo conectado)
flutter run

# Build de produção (Web Cloudflare Pages & Android APK)
./cloudflare-build.sh
./cloudflare-deploy.sh
flutter build apk --release
```

### 3. Serviço de IA (`gastosync_agent/app`)

```bash
cd gastosync_agent/app
python3 -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt
cp .env.example .env # Preencha API_KEY_GROQ no arquivo .env
uvicorn main:app --reload --port 8000
```

### 4. Testes Automatizados

```bash
# Core API em Go
cd gastosync_api && go test -v ./...

# App Flutter (Drift, Motor Financeiro, UI e Sync)
cd gastosync_app && flutter test

# Agente de IA (Python / pytest)
cd gastosync_agent/app && pytest -v
```

---

## Documentação por Módulo e Especificações

- **App Flutter**: [`gastosync_app/README.md`](gastosync_app/README.md)
- **API Core (Go)**: [`gastosync_api/README.md`](gastosync_api/README.md)
- **Agente IA (Python)**: [`gastosync_agent/app/README.md`](gastosync_agent/app/README.md)
- **Constituição do Projeto**: [`.specify/memory/constitution.md`](.specify/memory/constitution.md)
- **Especificação Funcional Pro (002)**: [`.specs/002-pro-security-db-boletos/spec.md`](.specs/002-pro-security-db-boletos/spec.md)
- **Plano Técnico e Contratos (002)**: [`.specs/002-pro-security-db-boletos/plan.md`](.specs/002-pro-security-db-boletos/plan.md)
- **Backlog de Tarefas (002)**: [`.specs/002-pro-security-db-boletos/tasks.md`](.specs/002-pro-security-db-boletos/tasks.md)
- **Relatório de Auditoria de Segurança**: [`.specs/002-pro-security-db-boletos/security-audit-report.md`](.specs/002-pro-security-db-boletos/security-audit-report.md)

---

## Licença

Este projeto está licenciado sob a **Licença MIT** — consulte o arquivo [`LICENSE`](LICENSE) para mais detalhes.
