---

description: "Task list for feature 002-pro-security-db-boletos implementation"
---

# Tasks: Segurança de Conta por OTP, Gestão de Boletos com Alertas Diários e Evolução Pro de Dados

**Input**: Design documents from `.specs/002-pro-security-db-boletos/`

**Prerequisites**: [plan.md](./plan.md), [spec.md](./spec.md), [research.md](./research.md), [data-model.md](./data-model.md), [contracts/api-contracts.md](./contracts/api-contracts.md), [quickstart.md](./quickstart.md)

**Tests**: Incluídos testes automatizados para a API Go (`go test ./...`) e para o aplicativo Flutter (`flutter test`), seguidos pela auditoria em 6 fases da Cloudflare (`security-audit`).

**Organization**: Tarefas agrupadas por fase fundacional e por User Story (`[US1]` a `[US5]`) para permitir implementação incremental e validação independente.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Pode ser executada em paralelo (arquivos distintos, sem dependências pendentes)
- **[Story]**: Rótulo da User Story correspondente (`[US1]`, `[US2]`, `[US3]`, `[US4]`, `[US5]`)
- Caminhos exatos dos arquivos incluídos em todas as tarefas

---

## Phase 1: Setup (Shared Infrastructure & Security Tooling)

**Purpose**: Preparação de constantes de rotas e instalação da skill de auditoria de segurança da Cloudflare

- [x] T001 Install official Cloudflare security audit skill into `.agents/skills/security-audit/SKILL.md`
- [x] T002 [P] Add new API endpoint constants (`authVerifyEmailEndpoint = '/api/v1/auth/verify-email'`, `authResendVerificationEndpoint = '/api/v1/auth/resend-verification'`, `authProfileEndpoint = '/api/v1/auth/profile'`) in `gastosync_app/lib/core/constants/api_constants.dart`

---

## Phase 2: Foundational (Database Schema & Core Models — Blocking Prerequisites)

**Purpose**: Evolução idempotente do schema PostgreSQL (`NUMERIC(14,2)`, `client_uuid`, `deleted_at`, `bills`, `email_verification_tokens`) e do schema Drift SQLite v3 (`LocalTransactions`, `LocalBills` e isolamento multi-conta por `userEmail`)

**⚠️ CRITICAL**: Nenhuma User Story deve ser iniciada antes da conclusão desta fase

- [x] T003 Update PostgreSQL schema migrations in `gastosync_api/internal/database/postgres.go` to migrate monetary columns to `NUMERIC(14, 2)` (`monthly_income`, `amount`, `limit_amount`), add `email_verified BOOLEAN NOT NULL DEFAULT TRUE`, `email_verified_at TIMESTAMPTZ`, `reminder_time_1 VARCHAR(5) NOT NULL DEFAULT '09:00'`, `reminder_time_2 VARCHAR(5) NOT NULL DEFAULT '18:00'`, `email_bill_notifications BOOLEAN NOT NULL DEFAULT TRUE` to `users`, add `client_uuid UUID`, `credit_card_uuid UUID`, and `deleted_at TIMESTAMPTZ` with `UNIQUE (user_id, client_uuid)` to `transactions`, create table `email_verification_tokens (email VARCHAR(255) PRIMARY KEY, code_hash VARCHAR(128) NOT NULL, expires_at TIMESTAMPTZ NOT NULL, attempts INT NOT NULL DEFAULT 0, created_at TIMESTAMPTZ NOT NULL DEFAULT NOW())`, remove hard FK on `password_reset_tokens.email`, create table `bills` with `is_credit_card_charge BOOLEAN NOT NULL DEFAULT FALSE`, `credit_card_uuid UUID`, `status IN ('pending', 'paid', 'overdue')`, `amount NUMERIC(14, 2) NOT NULL CHECK (amount > 0)`, `UNIQUE (user_id, client_uuid)`, and composite index `idx_bills_user_due ON bills(user_id, status, due_date ASC)`, and create table `credit_cards` (`name`, `limit_amount NUMERIC(14,2)`, `target_min_percent NUMERIC(5,2) DEFAULT 50`, `target_max_percent NUMERIC(5,2) DEFAULT 80`, `due_day INT`, `is_primary BOOLEAN`)
- [x] T004 [P] Update Go domain structs and DTOs in `gastosync_api/internal/models/models.go` adding `EmailVerified`, `ReminderTime1`, `ReminderTime2`, `EmailBillNotifications` to `User`, adding `VerifyEmailRequest`, `ResendVerificationRequest`, `UpdateProfileRequest`, `RegisterResponse`, adding `ClientUUID`, `CreditCardUUID`, and `DeletedAt` to `TransactionDTO`, creating `BillDTO` (including `IsCreditCardCharge bool` and `CreditCardUUID *string`), creating `CreditCardDTO`, and adding `Bills []BillDTO` + `CreditCards []CreditCardDTO` to `SyncPushRequest`, `SyncPushResponse`, and `SyncPullResponse`
- [x] T005 Upgrade Drift database to `schemaVersion = 3` in `gastosync_app/lib/core/database/app_database.dart` and `gastosync_app/lib/core/database/app_database.g.dart` adding `clientUuid`, `paymentMethod` (`default 'PIX'`), `creditCardUuid`, `updatedAt`, and `deletedAt` to `LocalTransactions`, adding `userEmail` isolation column to `LocalBudgets`, `LocalMetrics`, and `LocalAgentInsights`, creating table `LocalBills` (`id`, `clientUuid`, `userEmail`, `description` max 255 chars, `amount > 0`, `dueDate`, `category`, `barcode`, `isRecurring`, `isCreditCardCharge`, `creditCardUuid`, `status` in `['pending', 'paid', 'overdue']`, `paidAt`, `linkedTransactionId`, `linkedTxUuid`, `isSynced`, `updatedAt`, `deletedAt`), and creating table `LocalCreditCards` (`id`, `clientUuid`, `userEmail`, `name`, `limitAmount`, `targetMinPercent` default 50.0, `targetMaxPercent` default 80.0, `dueDay` default 10, `isPrimary`, `isSynced`, `updatedAt`, `deletedAt`)

**Checkpoint**: Schemas PostgreSQL e SQLite v3 prontos — implementação das User Stories liberada.

---

## Phase 3: User Story 1 - Verificação de E-mail no Cadastro e Proteção de Acesso (Priority: P1) 🎯 MVP

**Goal**: Exigir código OTP de 6 dígitos (expiração de 10 minutos, máx. 5 tentativas) ao criar conta, bloquear login em nuvem de contas não verificadas, aplicar política de senha forte OWASP no backend Go e proteger todos os endpoints de OTP com `AuthRateLimiter`.

**Independent Test**: Registrar uma nova conta, verificar o recebimento do OTP (ou `dev_preview_code` em ambiente local), testar bloqueio de login antes da verificação (`403 EMAIL_NOT_VERIFIED`), submeter o código de 6 dígitos em `/api/v1/auth/verify-email` e confirmar emissão do JWT e entrada no Dashboard.

### Implementation for User Story 1

- [x] T006 [US1] Implement `validateStrongPassword` (min 8 chars, uppercase, lowercase, digit, special char), update `Register` to set `email_verified = false` and dispatch 6-digit OTP via `email_verification_tokens`, update `Login` to return `403 EMAIL_NOT_VERIFIED` with automatic OTP dispatch when unverified, and implement `VerifyEmail` and `ResendVerification` handlers in `gastosync_api/internal/handlers/auth_handler.go`
- [x] T007 [US1] Register `/api/v1/auth/verify-email` and `/api/v1/auth/resend-verification` routes and attach `middleware.AuthRateLimiter()` to `/forgot-password`, `/verify-reset-code`, `/reset-password`, `/verify-email`, and `/resend-verification` in `gastosync_api/cmd/api/main.go`
- [x] T008 [P] [US1] Add unit tests for strong password validation, email verification OTP hashing, and rate-limited auth flows in `gastosync_api/internal/handlers/auth_handler_test.go`
- [x] T009 [US1] Update `register`, `login`, `verifyEmail`, and `resendVerificationEmail` methods in `gastosync_app/lib/features/auth/data/services/auth_service.dart` to parse `requires_verification`, `dev_preview_code`, and `EMAIL_NOT_VERIFIED` responses
- [x] T010 [US1] Update `AuthNotifier` and `AuthState` in `gastosync_app/lib/features/auth/domain/auth_provider.dart` to manage pending email verification state, local/remote OTP verification (`verifyEmailRegistration`), and resend logic (`resendEmailVerification`)
- [x] T011 [US1] Create `_VerifyEmailDialog` modal in `gastosync_app/lib/features/auth/presentation/screens/login_screen.dart` and trigger it automatically after registration or when an unverified account attempts login

**Checkpoint**: User Story 1 concluída e testável de forma independente.

---

## Phase 4: User Story 2 - Gestão Dedicada de Boletos e Contas a Pagar com Baixa Automática (Priority: P1)

**Goal**: Permitir o cadastro, listagem, cópia de linha digitável/PIX e baixa em 1 toque de Boletos (`LocalBills` / `bills`), gerando automaticamente a transação de despesa paga (`paymentMethod = 'Boleto'`) e agendando o boleto do próximo mês quando `isRecurring == true`.

**Independent Test**: Criar um boleto recorrente com linha digitável pelo botão `+` (aba `Boleto / Conta`), visualizá-lo na sub-aba `Boletos a Pagar` de `Transações` e no card do `Dashboard`, copiar o código de barras e clicar em "Dar Baixa / Pagar" verificando a criação da despesa em `Lançamentos` e do novo boleto para o mês seguinte.

### Implementation for User Story 2

- [x] T012 [P] [US2] Create `Bill` domain model and `BillStatus` enum (`pending`, `paid`, `overdue`) with `isCreditCardCharge` flag, validation rules (`amount > 0`, `description` 1..255 chars), due-date helpers (`daysUntilDue`, `isDueToday`, `isOverdue`, `isDueSoon`), and next-month recurrence calculation (handling day 28/29/30/31 clamping) in `gastosync_app/lib/features/transactions/domain/models/bill.dart`
- [x] T013 [US2] Implement `LocalBills` DAO operations (`watchAllBills`, `insertBill`, `updateBill`, `deleteBillById`, and transactional `payBillAndCreateTransaction` that marks bill as `'paid'`, only inserts a cash-outflow `LocalTransactions` when `isCreditCardCharge == false` so credit-card-embedded charges do not double-subtract from net balance, and schedules next month's bill if `isRecurring == true`) in `gastosync_app/lib/core/database/app_database.dart`
- [x] T014 [US2] Extend `TransactionsController` and Riverpod stream providers (`watchBillsProvider`, `pendingBillsCountProvider`, and category spending aggregation in `PlanningScreen` / `GastoSyncNotificationsModal` so `isCreditCardCharge` items allocate their amount to their target `category` while deducting from generic credit card invoice totals) in `gastosync_app/lib/features/transactions/presentation/controllers/transactions_controller.dart`
- [x] T015 [US2] Update `ManualTransactionFormModal` in `gastosync_app/lib/features/transactions/presentation/widgets/manual_transaction_form_modal.dart` to include the 3rd tab `Boleto / Conta` with fields for Data de Vencimento (`dueDate`), Linha Digitável / PIX Copia e Cola (`barcode`), switch `Repetir mensalmente (Recorrente)` (`isRecurring`), and switch `Desconta no Cartão (Incluso na Fatura)` (`isCreditCardCharge`)
- [x] T016 [US2] Update `TransactionsScreen` in `gastosync_app/lib/features/transactions/presentation/screens/transactions_screen.dart` with a segmented view toggle (`Lançamentos` | `Boletos a Pagar`), summary cards separating `Total Real a Pagar` (`!isCreditCardCharge`) from `Lembretes no Cartão (Inclusos na Fatura)` (`isCreditCardCharge`), copy-barcode action (`Clipboard.setData`), and 1-tap `Dar Baixa / Pagar` (`Confirmar no Cartão`) button
- [x] T017 [P] [US2] Add a compact `Próximos Boletos & Vencimentos` summary card on `DashboardScreen` in `gastosync_app/lib/features/dashboard/presentation/screens/dashboard_screen.dart` with quick navigation to the bills view

**Checkpoint**: User Stories 1 e 2 concluídas e testáveis de forma independente.

---

## Phase 5: User Story 3 - Sistema de Notificações de Boletos Duas Vezes ao Dia (Priority: P1)

**Goal**: Notificar o usuário 2 vezes ao dia (nos dois horários configurados em `UserProfile`, padrão `09:00` e `18:00`) sobre boletos que vencem em até 3 dias, vencem hoje ou estão vencidos, atuando na Central de Notificações In-App, em Notificações Locais/Nativas e por E-mail no backend Go.

**Independent Test**: Configurar os dois horários diários de lembrete na tela `Mais`, cadastrar um boleto vencendo hoje/em 2 dias e validar que `BillNotificationService` e `gastoSyncNotificationsProvider` geram os alertas prioritários nos dois turnos diários sem duplicar no mesmo turno, além de sincronizar as preferências com `PUT /api/v1/auth/profile`.

### Implementation for User Story 3

- [x] T018 [P] [US3] Implement `UpdateProfile` handler (`PUT /api/v1/auth/profile`) in `gastosync_api/internal/handlers/auth_handler.go` and register route in `gastosync_api/cmd/api/main.go` to persist `name`, `monthly_income`, `savings_goal_percent`, `reminder_time_1`, `reminder_time_2`, and `email_bill_notifications`
- [x] T019 [P] [US3] Implement `StartBillReminderWorker` in `gastosync_api/internal/handlers/bill_notifier.go` and wire it in `gastosync_api/cmd/api/main.go` to check due/overdue bills at each user's `reminder_time_1` and `reminder_time_2` (2x/day) and dispatch HTML reminder emails via Brevo / Resend / SMTP
- [x] T020 [US3] Update `UserProfile` and `UserProfileNotifier` in `gastosync_app/lib/features/settings/domain/models/user_profile.dart` to store `reminderTime1` (default `'09:00'`), `reminderTime2` (default `'18:00'`), and `emailBillNotifications` (default `true`), syncing changes with `PUT /api/v1/auth/profile`
- [x] T021 [US3] Create `BillNotificationService` in `gastosync_app/lib/core/services/bill_notification_service.dart` that evaluates twice-daily reminder windows (`reminderTime1` and `reminderTime2`), tracks per-window dispatch state to prevent duplicate alerts in the same shift, and triggers local device/browser notifications
- [x] T022 [US3] Integrate due-today, overdue, and upcoming (<= 3 days) bill alerts into `gastoSyncNotificationsProvider` and `GastoSyncNotificationsModal` in `gastosync_app/lib/core/widgets/gastosync_notifications_modal.dart`
- [x] T023 [US3] Add UI controls in `MoreScreen` (`gastosync_app/lib/features/settings/presentation/screens/more_screen.dart`) allowing the user to customize the 1st and 2nd daily bill notification times (`HH:MM`) and toggle email bill reminders

**Checkpoint**: User Stories 1, 2 e 3 concluídas e testáveis de forma independente.

---

## Phase 6: User Story 4 - Integridade Monetária, Isolamento Multi-Conta, Edição e Sincronização Fiel (Priority: P2)

**Goal**: Garantir preservação de `paymentMethod`, `clientUuid` e `deletedAt` no SQLite e no sync bidirecional com o PostgreSQL, isolar todas as tabelas locais por `userEmail` e permitir a edição de transações e boletos existentes.

**Independent Test**: Criar uma transação com `paymentMethod = 'Crédito'`, editá-la no modal, sincronizar via `pushPendingTransactions` / `pullFromCloud`, excluir uma transação e verificar que o `paymentMethod`, a edição e a exclusão (`deleted_at`) são refletidos na nuvem e isolados por `userEmail`.

### Implementation for User Story 4

- [x] T024 [P] [US4] Update `Push` and `Pull` in `gastosync_api/internal/handlers/sync_handler.go` to upsert `transactions` and `bills` by `(user_id, client_uuid)`, propagate soft deletions (`deleted_at`), and filter `WHERE deleted_at IS NULL` on pull
- [x] T025 [US4] Update `Transaction` domain model in `gastosync_app/lib/features/transactions/domain/models/transaction.dart` and repository in `gastosync_app/lib/features/transactions/data/repositories/transaction_repository_impl.dart` to include `clientUuid`, `paymentMethod`, `updatedAt`, and `deletedAt`
- [x] T026 [US4] Update `CloudSyncService` in `gastosync_app/lib/features/transactions/data/services/cloud_sync_service.dart` to send real `payment_method`, `client_uuid`, `deleted_at`, and `bills` payload on push, and hydrate both `LocalTransactions` and `LocalBills` on pull
- [x] T027 [US4] Add edit mode support (`initialTransaction` and `initialBill`) to `ManualTransactionFormModal` in `gastosync_app/lib/features/transactions/presentation/widgets/manual_transaction_form_modal.dart` and add edit action buttons to transaction and bill cards in `gastosync_app/lib/features/transactions/presentation/screens/transactions_screen.dart`

**Checkpoint**: User Stories 1 a 4 concluídas.

---

## Phase 7: User Story 5 - Gestão de Cartões de Crédito (Principal e Secundário) e Teto Saudável de Relacionamento Bancário (Priority: P1)

**Goal**: Permitir cadastrar Cartão Principal e Cartões Secundários (nome, limite ex: R$ 1.500, faixa saudável de relacionamento bancário ex: 50% a 80% / R$ 750 a R$ 1.200, dia de vencimento), vincular compras no Crédito (ex: Mercado) e cobranças fixas no cartão (ex: Academia) ao cartão escolhido, e visualizar o termômetro de uso do limite em `Planejamento > Cartões & Limite` e no `Dashboard`.

**Independent Test**: Cadastrar "Cartão Principal" (limite R$ 1.500, faixa ideal 50%–80%) e "Cartão Secundário", vincular uma assinatura fixa (Academia R$ 120) e uma compra de Mercado no crédito (R$ 680) ao Cartão Principal, e verificar em `Planejamento > Cartões & Limite` a separação Fixas (R$ 120) + Compras/Mercado (R$ 680) = R$ 800 (53,3%) e a margem saudável restante de R$ 400 até atingir 80% (R$ 1.200).

### Implementation for User Story 5

- [x] T028 [P] [US5] Create `CreditCard` and `CreditCardUsageSummary` domain models in `gastosync_app/lib/features/planning/domain/models/credit_card_model.dart` calculating `fixedSubscriptionsAmount`, `variablePurchasesAmount`, `totalUsedAmount`, `utilizationPercent`, `healthyMinAmount` (e.g. 50%), `healthyMaxAmount` (e.g. 80%), `remainingHealthyMargin`, and `isAboveHealthyCeiling`
- [x] T029 [US5] Implement `LocalCreditCards` DAO methods (`watchAllCreditCards`, `upsertCreditCard`, `deleteCreditCard`, and default seed for `Cartão Principal` with R$ 1.500 limit and 50%–80% target range) in `gastosync_app/lib/core/database/app_database.dart`
- [x] T030 [US5] Add credit card selector chip/dropdown in `ManualTransactionFormModal` (`gastosync_app/lib/features/transactions/presentation/widgets/manual_transaction_form_modal.dart`) whenever `paymentMethod == 'Crédito'` or `isCreditCardCharge == true`
- [x] T031 [US5] Add `Cartões & Limite` view/section in `PlanningScreen` (`gastosync_app/lib/features/planning/presentation/screens/planning_screen.dart`), summary indicator on `DashboardScreen`, and alert in `GastoSyncNotificationsModal` when a card exceeds its healthy utilization ceiling (`targetMaxPercent`)

---

## Phase 8: User Story 6 - Exportação de Relatório Financeiro em CSV (Priority: P2)

**Goal**: Permitir exportar transações, boletos e resumo de cartões da conta ativa em formato CSV padronizado diretamente pela tela de Transações ou pela aba `Mais`.

**Independent Test**: Clicar em "Exportar CSV" na tela de Transações ou na aba `Mais` e verificar a geração e exibição/cópia/download do relatório CSV contendo todas as movimentações e boletos do usuário.

### Implementation for User Story 6

- [x] T032 [P] [US6] Create `CsvExportService` in `gastosync_app/lib/core/services/csv_export_service.dart` formatting `Transaction`, `Bill`, and `CreditCard` records into RFC-4180 CSV with UTF-8 BOM
- [x] T033 [US6] Wire the CSV export modal/download action in `TransactionsScreen` (`gastosync_app/lib/features/transactions/presentation/screens/transactions_screen.dart`) and `MoreScreen` (`gastosync_app/lib/features/settings/presentation/screens/more_screen.dart`)

---

## Phase 9: Polish, Regression Testing & Cloudflare Security Audit

**Purpose**: Testes automatizados de ponta a ponta e execução da auditoria de segurança em 6 fases com a skill `cloudflare/security-audit-skill`

- [x] T034 [P] Write comprehensive Flutter unit and widget tests for `LocalBills`, `LocalCreditCards` (healthy 50%–80% utilization math, Fixed vs Variable breakdown), recurrence, 2x/day notifications, `paymentMethod` persistence, and CSV export in `gastosync_app/test/features/transactions/bills_and_sync_test.dart`
- [x] T035 Run full validation suite (`go vet ./...`, `go test ./...` in `gastosync_api/` and `flutter analyze`, `flutter test` in `gastosync_app/`) per `quickstart.md`
- [x] T036 Execute the 6-phase security audit workflow using `.agents/skills/security-audit/SKILL.md` across `gastosync_api`, `gastosync_app`, and `gastosync_agent`, remediate any verified findings, and generate `.specs/002-pro-security-db-boletos/security-audit-report.md`

---

## Dependencies & Execution Order

### Phase Dependencies

1. **Setup (Phase 1)**: Concluída / imediata.
2. **Foundational (Phase 2 — T003..T005)**: Pré-requisito bloqueante para todas as User Stories.
3. **User Stories P1 (Phases 3, 4, 5)**:
   - **US1 (T006..T011)**: Verificação de E-mail por OTP e Hardening Auth.
   - **US2 (T012..T017)**: Boletos (`LocalBills` / `bills`), Baixa Automática e Recorrência.
   - **US3 (T018..T023)**: Notificações 2x ao Dia (depende de US2 para ler os boletos).
4. **User Stories P2 (Phases 6, 7)**:
   - **US4 (T024..T027)**: Sync Completo (`UUID`, `paymentMethod`, Soft Delete) e Edição.
   - **US5 (T028..T029)**: Exportação CSV.
5. **Polish & Security Audit (Phase 8 — T030..T032)**: Executada após todas as User Stories.

### Parallel Opportunities

- `T003` (Go Postgres DDL) e `T005` (Flutter Drift Schema v3) atuam em projetos separados (`gastosync_api` vs `gastosync_app`) e podem rodar em paralelo.
- `T006`/`T007`/`T008` (Backend Auth OTP) podem rodar em paralelo com `T012`/`T013` (Domínio e DAO de Boletos no Flutter).
- `T018`/`T019` (Backend Profile & Bill Email Worker) podem rodar em paralelo com `T020`/`T021` (Serviço de Notificação 2x/dia no Flutter).
