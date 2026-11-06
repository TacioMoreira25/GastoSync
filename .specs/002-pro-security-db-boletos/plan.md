# Implementation Plan: Segurança de Conta por OTP, Gestão de Boletos com Alertas Diários e Evolução Pro de Dados

**Branch**: `002-pro-security-db-boletos` | **Date**: 2026-11-06 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `.specs/002-pro-security-db-boletos/spec.md`

## Summary

Implementar a evolução **GastoSync Pro** cobrindo:
1. **Verificação de E-mail ao Criar Conta (OTP de 6 dígitos)** no backend Go (`gastosync_api`) e no cliente Flutter (`gastosync_app`), bloqueando login na nuvem até a confirmação do código e aplicando política de senha forte OWASP e Rate Limiting em todas as rotas de OTP.
2. **Refatoração e Padronização do Banco de Dados e Sincronização**: Manutenção da arquitetura Multi-Tenant em tabela única indexada por `user_id` com `ON DELETE CASCADE`, migração de colunas monetárias no PostgreSQL para `NUMERIC(14, 2)`, adição de `client_uuid`, `payment_method`, `updated_at` e `deleted_at` (Soft Delete) em transações, e isolamento completo por `userEmail` em todas as tabelas do SQLite (Drift Schema v3).
3. **Sistema Dedicado de Boletos (`bills` / `LocalBills`) e Notificações 2x ao Dia**: Criação da entidade separada de boletos com suporte a vencimento, linha digitável/PIX copia-e-cola, recorrência mensal e baixa em 1 toque (gerando automaticamente a transação realizada e o boleto do próximo mês), acompanhado do motor de notificações duas vezes ao dia (horários personalizáveis pelo usuário, padrão `09:00` e `18:00`) via Central In-App, Notificações Locais e E-mail.
4. **Recursos Pro e Auditoria Cloudflare**: Edição de lançamentos e boletos existentes, sincronização de perfil financeiro (`PUT /api/v1/auth/profile`), exportação de relatório em CSV e auditoria completa de segurança ao final usando a skill `cloudflare/security-audit-skill`.

## Technical Context

**Language/Version**: Go 1.23+ (`gastosync_api`) | Flutter 3.x+ / Dart 3.13+ (`gastosync_app`) | Python 3.11+ (`gastosync_agent`)

**Primary Dependencies**:
- **Backend (`gastosync_api`)**: `github.com/gofiber/fiber/v2`, `github.com/jackc/pgx/v5`, `golang.org/x/crypto/bcrypt`, `github.com/golang-jwt/jwt/v5`
- **Frontend (`gastosync_app`)**: `flutter_riverpod`, `drift`, `sqlite3`, `dio`, `go_router`, `fl_chart`, `intl`

**Storage**: PostgreSQL 16+ (Neon Serverless em produção / Docker local) + SQLite local via Drift (Mobile Offline-First / Web WASM)

**Testing**: `go test ./...` (Backend Go) e `flutter test` + `flutter analyze` (Frontend Flutter)

**Target Platform**: Android, iOS, Web (Cloudflare Pages) e Linux Server Container (Render.com)

**Project Type**: Multi-service Mobile + Web + REST API (`gastosync_app` + `gastosync_api` + `gastosync_agent`)

**Performance Goals**: Operações locais SQLite/Streams `< 100ms`; consultas PostgreSQL indexadas por `user_id` `< 20ms`; zero erro de arredondamento de centavos (`NUMERIC(14,2)`)

**Constraints**: Offline-First incondicional no Mobile; isolamento estrito por `user_id` no servidor e `userEmail` no SQLite; preservação integral das 4 abas principais de navegação do protótipo Figma v2

**Scale/Scope**: Suporte Multi-Tenant escalável em tabela única com índices compostos B-Tree para milhares de usuários e milhões de transações/boletos

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

- **I. Offline-First Incondicional no Mobile & Web Online Direta**: **PASS**. `LocalBills` e `LocalTransactions` operam 100% localmente via Drift Streams no Mobile e sincronizam assincronamente via `/api/v1/sync/{push,pull}`.
- **II. Separação de Microsserviços & Isolamento de Falhas**: **PASS**. Autenticação, OTP, banco PostgreSQL e worker de e-mail de boletos residem em `gastosync_api` (Go), mantendo `gastosync_agent` (Python) isolado apenas para IA/OCR.
- **III. Human-in-the-Loop Obrigatório**: **PASS**. Nenhuma sugestão da IA é salva sem confirmação explícita do usuário no modal.
- **IV. Reatividade por Streams e 9 Métricas de Saúde Financeira**: **PASS**. A baixa de um boleto insere a despesa no Drift e atualiza instantaneamente todas as streams e as 9 métricas financeiras.
- **V. Design Adaptativo Multiplataforma**: **PASS**. As 4 abas principais (`Início`, `Transações`, `Planejamento`, `Mais`) são preservadas; Boletos entram como sub-aba em `Transações`, card no `Dashboard` e opção no modal `+`.
- **VI. Resiliência de Rede, Segurança, Autenticação e Privacidade**: **PASS**. Senhas com Bcrypt e política forte OWASP, OTP com SHA-256 + `ConstantTimeCompare`, Rate Limiting em todas as rotas de auth/OTP, isolamento por `user_id` e auditoria final com `cloudflare/security-audit-skill`.

## Project Structure

### Documentation (this feature)

```text
.specs/002-pro-security-db-boletos/
├── spec.md                     # Especificação de requisitos e User Stories (/speckit-specify)
├── checklists/
│   └── requirements.md         # Checklist de validação da spec (/speckit-specify)
├── plan.md                     # Este plano técnico (/speckit-plan)
├── research.md                 # Decisões arquiteturais Fase 0 (/speckit-plan)
├── data-model.md               # Modelagem PostgreSQL + Drift Fase 1 (/speckit-plan)
├── quickstart.md               # Guia de validação Fase 1 (/speckit-plan)
├── contracts/
│   └── api-contracts.md        # Contratos REST JSON Fase 1 (/speckit-plan)
└── tasks.md                    # Lista de tarefas executáveis (/speckit-tasks)
```

### Source Code (repository root)

```text
.agents/skills/
└── security-audit/             # Skill oficial cloudflare/security-audit-skill instalada

gastosync_api/
├── cmd/api/main.go             # Registro de rotas, rate limiters e worker de boletos
└── internal/
    ├── database/postgres.go    # Migrations idempotentes (NUMERIC, UUID, bills, tokens)
    ├── handlers/
    │   ├── auth_handler.go     # Register c/ OTP, VerifyEmail, ResendVerification, UpdateProfile, OWASP Password
    │   ├── sync_handler.go     # Push/Pull de transactions (UUID/SoftDelete), bills e budgets
    │   └── bill_notifier.go    # Worker de notificações de boletos 2x ao dia por e-mail
    ├── middleware/
    │   ├── auth_middleware.go  # Validação JWT e injeção de user_id
    │   └── error_middleware.go # Rate limiter e headers OWASP
    └── models/models.go        # DTOs de User, TransactionDTO, BillDTO, BudgetDTO e Auth/OTP

gastosync_app/
├── lib/
│   ├── core/
│   │   ├── constants/api_constants.dart
│   │   ├── database/app_database.dart              # Schema v3 (LocalTransactions, LocalBills, isolamento userEmail)
│   │   ├── services/
│   │   │   ├── bill_notification_service.dart      # Motor de notificações 2x ao dia (horários configuráveis)
│   │   │   └── csv_export_service.dart             # Exportação de relatório financeiro CSV
│   │   └── widgets/gastosync_notifications_modal.dart
│   └── features/
│       ├── auth/
│       │   ├── data/services/auth_service.dart
│       │   ├── domain/auth_provider.dart
│       │   └── presentation/screens/login_screen.dart
│       ├── dashboard/presentation/screens/dashboard_screen.dart
│       ├── settings/
│       │   ├── domain/models/user_profile.dart
│       │   └── presentation/screens/more_screen.dart
│       └── transactions/
│           ├── data/
│           │   ├── repositories/transaction_repository_impl.dart
│           │   └── services/cloud_sync_service.dart
│           ├── domain/models/
│           │   ├── transaction.dart
│           │   └── bill.dart
│           └── presentation/
│               ├── controllers/transactions_controller.dart
│               ├── screens/transactions_screen.dart
│               └── widgets/manual_transaction_form_modal.dart
└── test/                       # Testes unitários, widget e regressão multiplataforma
```

**Structure Decision**: Mantida a arquitetura modular do monorepo dividida entre `gastosync_api` (Go) e `gastosync_app` (Flutter Feature-First Clean Architecture), adicionando a skill `.agents/skills/security-audit` e os artefatos da feature em `.specs/002-pro-security-db-boletos/`.

## Complexity Tracking

Nenhuma violação à Constituição do projeto. Todas as adições respeitam o isolamento Offline-First e a topologia existente.
