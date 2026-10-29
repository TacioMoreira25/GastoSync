# GastoSync

> Plataforma multiplataforma de gestão financeira pessoal (Android, iOS e Web) com operação Offline-First no Mobile, API Core em Go e Agente Preditivo por IA.

<p align="left">
  <img src="https://img.shields.io/badge/FLUTTER%203-02569B?style=for-the-badge&logo=flutter&logoColor=white" height="28" alt="Flutter 3" />
  <img src="https://img.shields.io/badge/DART%203-0175C2?style=for-the-badge&logo=dart&logoColor=white" height="28" alt="Dart 3" />
  <img src="https://img.shields.io/badge/GO%201.23+-00ADD8?style=for-the-badge&logo=go&logoColor=white" height="28" alt="Go" />
  <img src="https://img.shields.io/badge/POSTGRESQL%20%2F%20NEON-4169E1?style=for-the-badge&logo=postgresql&logoColor=white" height="28" alt="PostgreSQL Neon" />
  <img src="https://img.shields.io/badge/DRIFT%20%2F%20SQLITE-003B57?style=for-the-badge&logo=sqlite&logoColor=white" height="28" alt="Drift SQLite" />
  <img src="https://img.shields.io/badge/DOCKER-2496ED?style=for-the-badge&logo=docker&logoColor=white" height="28" alt="Docker" />
  <img src="https://img.shields.io/badge/GROQ%20%2F%20LLAMA%203.3-F55036?style=for-the-badge&logo=meta&logoColor=white" height="28" alt="Groq AI" />
</p>

---

## Arquitetura do Monorepo

```text
gasto-sync/
├── .specify/          # Governança e constituição arquitetural (Spec-Driven Development)
├── .specs/            # Especificações funcionais, plano técnico e backlog de tarefas
├── gastosync_app/     # Cliente Flutter Multiplataforma (Mobile Offline-First & Web Online)
├── gastosync_api/     # API Core em Go (Autenticação JWT/Bcrypt, Sync e PostgreSQL)
└── gastosync_agent/   # Serviço Satélite em Python (FastAPI + Groq SDK) para IA e OCR
```

- **Cliente (`gastosync_app`)**: Opera 100% offline no Mobile via SQLite nativo (`Drift`) com sincronização em background, e online direto via API REST na Web.
- **API Core (`gastosync_api`)**: Microsserviço em Go (`Fiber v2` + `pgx/v5`) conectado ao Neon PostgreSQL.
- **Agente IA (`gastosync_agent`)**: Serviço independente em Python (`FastAPI` + `Groq`) para categorização em linguagem natural, OCR de comprovantes e assistente conversacional com validação *Human-in-the-Loop*.

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
```

### 3. Serviço de IA (`gastosync_agent`)

```bash
cd gastosync_agent
python -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt
cp .env.example .env # Preencha API_KEY_GROQ no arquivo .env
uvicorn main:app --reload --port 8000
```

---

## Documentação por Módulo e Especificações

- **App Flutter**: [`gastosync_app/README.md`](gastosync_app/README.md)
- **API Core (Go)**: [`gastosync_api/README.md`](gastosync_api/README.md)
- **Constituição do Projeto**: [`.specify/memory/constitution.md`](.specify/memory/constitution.md)
- **Especificação Funcional**: [`.specs/001-fluxos-operacao-gastosync/spec.md`](.specs/001-fluxos-operacao-gastosync/spec.md)
- **Plano Técnico e Contratos**: [`.specs/001-fluxos-operacao-gastosync/plan.md`](.specs/001-fluxos-operacao-gastosync/plan.md)
- **Backlog de Tarefas**: [`.specs/001-fluxos-operacao-gastosync/tasks.md`](.specs/001-fluxos-operacao-gastosync/tasks.md)
