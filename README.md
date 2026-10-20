# GastoSync

Sistema de gestão financeira pessoal multiplataforma com agente preditivo e orçamentário por IA.

## Estrutura do Repositório

```text
gastosync/
├── .agents/skills/    # Skills do Spec Kit integradas ao Antigravity
├── .specify/          # Configurações e constituição do projeto
├── .specs/            # Especificações de features, arquitetura e tarefas (SDD)
├── gastosync_app/     # Cliente Flutter Multiplataforma (Web, Android, iOS)
└── gastosync_agent/   # Backend Python para orquestração de LLM via Groq API
```

## Especificações (Spec-Driven Development)

- **Constituição**: `.specify/memory/constitution.md`
- **Feature 001**: `.specs/001-fluxos-operacao-gastosync/`
  - Requisitos: `spec.md`
  - Arquitetura & Contratos: `plan.md`
  - Tarefas: `tasks.md`

## Stack Técnica

### Cliente (`gastosync_app`)
- **UI**: Material Design 3 (Light/Dark Mode)
- **Estado**: Flutter Riverpod
- **Navegação**: GoRouter (Shell adaptativo Mobile/Web)
- **Persistência**: Drift + SQLite (Offline-First)
- **Gráficos**: fl_chart (9 Métricas de Saúde Financeira)
- **Rede**: Dio (REST com fallback offline)

### Agente Backend (`gastosync_agent`)
- **API**: FastAPI
- **Inferência**: Llama 3.3 70B via Groq Cloud SDK (LPU)

