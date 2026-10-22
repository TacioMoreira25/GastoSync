# GastoSync

> Sistema de gestão financeira pessoal multiplataforma (Android, iOS e Web) 100% Offline-First com Agente Preditivo e Orçamentário por IA.

<p align="left">
  <img src="https://img.shields.io/badge/FLUTTER%203-02569B?style=for-the-badge&logo=flutter&logoColor=white" height="28" alt="Flutter 3" />
  <img src="https://img.shields.io/badge/DART%203-0175C2?style=for-the-badge&logo=dart&logoColor=white" height="28" alt="Dart 3" />
  <img src="https://img.shields.io/badge/RIVERPOD-00B4AB?style=for-the-badge&logo=flutter&logoColor=white" height="28" alt="Riverpod" />
  <img src="https://img.shields.io/badge/DRIFT%20%2F%20SQLITE-003B57?style=for-the-badge&logo=sqlite&logoColor=white" height="28" alt="Drift SQLite" />
  <img src="https://img.shields.io/badge/PYTHON%203.11-3776AB?style=for-the-badge&logo=python&logoColor=white" height="28" alt="Python 3.11" />
  <img src="https://img.shields.io/badge/FASTAPI-009688?style=for-the-badge&logo=fastapi&logoColor=white" height="28" alt="FastAPI" />
  <img src="https://img.shields.io/badge/GROQ%20%2F%20LLAMA%203.3-F55036?style=for-the-badge&logo=meta&logoColor=white" height="28" alt="Groq AI" />
</p>

---

## Sobre o Projeto

O **GastoSync** opera com persistência local reativa via **Drift (SQLite)** para garantir funcionamento imediato mesmo sem internet, enquanto consome de forma assíncrona um orquestrador em **Python (FastAPI + Groq Cloud)** para categorização de despesas em linguagem natural, leitura de comprovantes via OCR e recomendações de orçamento com revisão **Human-in-the-Loop**.

## Estrutura do Repositório

```text
gasto-sync/
├── .agents/skills/    # Skills do Spec Kit configuradas para execução controlada
├── .specify/          # Constituição arquitetural e scripts de governança (SDD)
├── .specs/            # Especificações de features, plano técnico e tasks
├── gastosync_app/     # Cliente Flutter Multiplataforma (Android, iOS, Web)
└── gastosync_agent/   # Backend Python (FastAPI + Groq SDK) para orquestração de IA
```

## Stack Técnica

### Cliente (`gastosync_app`)
- **UI**: Material Design 3 (Adaptativo Mobile/Web, Light & Dark Mode)
- **Estado**: Flutter Riverpod (`StreamProvider` reativo)
- **Navegação**: GoRouter (`StatefulShellRoute`)
- **Persistência**: Drift + SQLite (100% Offline-First)
- **Gráficos**: `fl_chart` (Painel com as 9 Métricas de Saúde Financeira)
- **Rede**: Dio (REST com timeouts de 10s/20s e fallback offline)

### Agente Backend (`gastosync_agent`)
- **API**: FastAPI + Pydantic
- **Segurança**: Classificador de contexto contra *Prompt Injection*
- **Inferência**: Llama 3.3 70B & Visão via Groq Cloud SDK (LPU)

## Como Executar

**1. Backend IA (`gastosync_agent`)**:
```bash
cd gastosync_agent
python -m venv .venv && source .venv/bin/activate
pip install -r requiriments.txt
cp .env.example .env # Adicione sua API_KEY_GROQ
uvicorn main:app --reload --port 8000
```

**2. App Multiplataforma (`gastosync_app`)**:
```bash
cd gastosync_app
flutter pub get
flutter run -d chrome --dart-define=GASTOSYNC_API_URL=http://localhost:8000
```

## Especificações (Spec-Driven Development)

- **Constituição do Projeto**: [`.specify/memory/constitution.md`](.specify/memory/constitution.md)
- **Especificação Funcional**: [`.specs/001-fluxos-operacao-gastosync/spec.md`](.specs/001-fluxos-operacao-gastosync/spec.md)
- **Plano Técnico e Contratos da API**: [`.specs/001-fluxos-operacao-gastosync/plan.md`](.specs/001-fluxos-operacao-gastosync/plan.md)
- **Tarefas e Backlog**: [`.specs/001-fluxos-operacao-gastosync/tasks.md`](.specs/001-fluxos-operacao-gastosync/tasks.md)
- **Guia de Deploy Web**: [`gastosync_app/docs/WEB_DEPLOYMENT_GUIDE.md`](gastosync_app/docs/WEB_DEPLOYMENT_GUIDE.md)
