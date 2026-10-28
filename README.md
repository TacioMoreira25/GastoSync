# GastoSync

> Sistema de gestão financeira pessoal multiplataforma (Android, iOS e Web) 100% Offline-First com Agente Preditivo e Orçamentário por IA.

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

## Sobre o Projeto

O **GastoSync** opera com persistência local reativa via **Drift (SQLite)** no Mobile (100% Offline-First) e operação online direta na Web, sincronizando de forma segura com o microsserviço **`gastosync_api` em Go (Golang)** conectado ao **Neon Serverless PostgreSQL**. De maneira desacoplada, consome o orquestrador **`gastosync_agent` em Python (FastAPI + Groq Cloud)** para categorização de despesas em linguagem natural, leitura de comprovantes via OCR e recomendações de orçamento com revisão **Human-in-the-Loop**.

## Estrutura do Repositório

```text
gasto-sync/
├── .agents/skills/    # Skills do Spec Kit configuradas para execução controlada
├── .specify/          # Constituição arquitetural e scripts de governança (SDD)
├── .specs/            # Especificações de features, plano técnico e tasks
├── gastosync_app/     # Cliente Flutter Multiplataforma (Mobile Offline-First & Web Online)
├── gastosync_api/     # Microsserviço Core em Go (Auth JWT/Bcrypt, Sync & Neon Postgres + Docker)
└── gastosync_agent/   # Serviço Satélite em Python (FastAPI + Groq SDK) para orquestração de IA
```

## Stack Técnica

### 1. Cliente (`gastosync_app` — Hospedado no Cloudflare Pages)
- **UI**: Material Design 3 (Adaptativo Mobile/Web conforme Protótipo v2)
- **Estado**: Flutter Riverpod (`StreamProvider` reativo)
- **Navegação**: GoRouter (`StatefulShellRoute`)
- **Persistência**: Drift + SQLite no Mobile (100% Offline-First) e API REST direta na Web
- **Gráficos**: `fl_chart` (Painel com as 9 Métricas de Saúde Financeira)
- **Rede**: Dio (REST com JWT, timeouts de 10s/20s e fallback offline)

### 2. Backend Core (`gastosync_api` — Hospedado no Render via Docker)
- **Linguagem & Framework**: Go (Golang) + Fiber v2
- **Banco em Nuvem**: Neon Serverless PostgreSQL (`pgx/v5` com SSL/TLS obrigatório)
- **Segurança**: Hash de senhas em Bcrypt, autenticação JWT e isolamento estrito por `user_id`
- **Container**: Multi-stage Dockerfile (`alpine:3.20` não-root, ~15 MB de imagem final)

### 3. Agente IA Satélite (`gastosync_agent` — Hospedado no Render)
- **API**: FastAPI + Pydantic
- **Segurança**: Classificador de contexto contra *Prompt Injection*
- **Inferência**: Llama 3.3 70B & Visão via Groq Cloud SDK (LPU)

## Como Executar

### Pré-requisitos
- **Flutter SDK**: 3.x+ (com suporte a Web e Android configurado)
- **Go**: 1.23+ (ou Docker para rodar `gastosync_api`)
- **Python**: 3.11+ (para o agente de IA `gastosync_agent`)
- **Banco de Dados**: String de conexão do **Neon Serverless Postgres** (`DATABASE_URL` com `sslmode=require`)

---

### 1. Backend Core em Go (`gastosync_api`)

```bash
cd gastosync_api

# Copiar template de variáveis de ambiente (NUNCA faça commit do .env real)
cp .env.example .env

# Rodar direto com Go:
go mod tidy
go run ./cmd/api

# Ou rodar via container Docker:
docker build -t gastosync-api .
docker run --rm -p 8080:8080 --env-file .env gastosync-api
```
> Veja o passo a passo completo de deploy gratuito (Neon + Render + Cloudflare Pages) em [`gastosync_api/README.md`](gastosync_api/README.md).

---

### 2. Serviço Satélite de IA (`gastosync_agent`)

```bash
cd gastosync_agent

# Criar e ativar ambiente virtual
python -m venv .venv
source .venv/bin/activate  # No Windows: .venv\Scripts\activate

# Instalar dependências
pip install -r requiriments.txt

# Configurar variáveis de ambiente
cp .env.example .env # Adicione sua API_KEY_GROQ no arquivo .env

# Iniciar o servidor FastAPI
uvicorn main:app --reload --port 8000
```
> O backend estará disponível em `http://localhost:8000` (documentação interativa em `/docs`).

---

### 2. App Multiplataforma (`gastosync_app`)

Instale as dependências:
```bash
cd gastosync_app
flutter pub get
```

#### A. Rodando na Web (Navegador)
Você pode rodar no Chrome ou em um servidor local (Firefox/qualquer navegador):

```bash
# Opção 1: Abrir diretamente no Chrome
flutter run -d chrome

# Opção 2: Subir servidor Web local (útil para Firefox ou outro navegador)
flutter run -d web-server --web-hostname=localhost --web-port=3000

# Conectando com a API local do Backend IA:
flutter run -d chrome --dart-define=GASTOSYNC_API_URL=http://localhost:8000
```
> Acesse `http://localhost:3000` no seu navegador se usar a opção de servidor local.

#### B. Rodando no Android (Emulador ou Dispositivo Físico)

Certifique-se de que o emulador está ligado ou o celular conectado via USB com depuração ativa:

```bash
# Listar dispositivos detectados
flutter devices

# Iniciar a aplicação
flutter run
```

> **Dica (Erro de armazenamento no emulador Android)**:  
> Se encontrar o erro `INSTALL_FAILED_INSUFFICIENT_STORAGE`, limpe os dados do emulador via linha de comando ou pelo Android Studio:
> ```bash
> $HOME/Android/Sdk/emulator/emulator -avd <NOME_DO_AVD> -wipe-data
> ```

#### C. Build de Produção para Web
Para gerar os arquivos estáticos para publicação (Vercel, Firebase Hosting, Nginx, etc.):

```bash
flutter build web --release
```
Os arquivos prontos serão gerados em `gastosync_app/build/web/`.


## Especificações (Spec-Driven Development)

- **Constituição do Projeto**: [`.specify/memory/constitution.md`](.specify/memory/constitution.md)
- **Especificação Funcional**: [`.specs/001-fluxos-operacao-gastosync/spec.md`](.specs/001-fluxos-operacao-gastosync/spec.md)
- **Plano Técnico e Contratos da API**: [`.specs/001-fluxos-operacao-gastosync/plan.md`](.specs/001-fluxos-operacao-gastosync/plan.md)
- **Tarefas e Backlog**: [`.specs/001-fluxos-operacao-gastosync/tasks.md`](.specs/001-fluxos-operacao-gastosync/tasks.md)
- **Guia de Deploy Web**: [`gastosync_app/docs/WEB_DEPLOYMENT_GUIDE.md`](gastosync_app/docs/WEB_DEPLOYMENT_GUIDE.md)
