# Phase 1 Data Model: Segurança de Conta por OTP, Gestão de Boletos e Evolução Pro de Dados

**Feature**: `002-pro-security-db-boletos`
**Date**: 2026-11-06

---

## 1. Modelo Relacional em Nuvem (PostgreSQL 16+ — `gastosync_api`)

### 1.1 Tabela `users`

| Coluna | Tipo | Constraints | Descrição |
| :--- | :--- | :--- | :--- |
| `id` | `UUID` | `PRIMARY KEY DEFAULT gen_random_uuid()` | Identificador único global do usuário |
| `name` | `VARCHAR(120)` | `NOT NULL` | Nome completo (mín. 3 caracteres) |
| `email` | `VARCHAR(255)` | `UNIQUE NOT NULL` | E-mail normalizado em minúsculas |
| `password_hash` | `TEXT` | `NOT NULL` | Hash Bcrypt (cost 12) da senha forte |
| `email_verified` | `BOOLEAN` | `NOT NULL DEFAULT FALSE` | Indica se o titular confirmou o OTP de 6 dígitos |
| `email_verified_at` | `TIMESTAMPTZ` | `NULL` | Data/hora da confirmação do e-mail |
| `monthly_income` | `NUMERIC(14, 2)` | `NOT NULL DEFAULT 0.00` | Renda base mensal configurada |
| `savings_goal_percent` | `NUMERIC(5, 2)` | `NOT NULL DEFAULT 20.00` | Meta percentual de poupança (`0` a `100`) |
| `reminder_time_1` | `VARCHAR(5)` | `NOT NULL DEFAULT '09:00'` | 1º horário diário de alerta de boletos (`HH:MM`) |
| `reminder_time_2` | `VARCHAR(5)` | `NOT NULL DEFAULT '18:00'` | 2º horário diário de alerta de boletos (`HH:MM`) |
| `email_bill_notifications` | `BOOLEAN` | `NOT NULL DEFAULT TRUE` | Habilita lembretes de boletos por e-mail |
| `created_at` | `TIMESTAMPTZ` | `NOT NULL DEFAULT NOW()` | Data de criação da conta |
| `updated_at` | `TIMESTAMPTZ` | `NOT NULL DEFAULT NOW()` | Data da última atualização de perfil |

---

### 1.2 Tabela `email_verification_tokens`

| Coluna | Tipo | Constraints | Descrição |
| :--- | :--- | :--- | :--- |
| `email` | `VARCHAR(255)` | `PRIMARY KEY` | E-mail em processo de verificação |
| `code_hash` | `VARCHAR(128)` | `NOT NULL` | Hash SHA-256 (`GastoSync::VerifyEmail::email::code`) |
| `expires_at` | `TIMESTAMPTZ` | `NOT NULL` | Expiração (10 minutos após geração) |
| `attempts` | `INT` | `NOT NULL DEFAULT 0` | Tentativas incorretas (bloqueia ao atingir `5`) |
| `created_at` | `TIMESTAMPTZ` | `NOT NULL DEFAULT NOW()` | Timestamp de emissão |

---

### 1.3 Tabela `password_reset_tokens`

| Coluna | Tipo | Constraints | Descrição |
| :--- | :--- | :--- | :--- |
| `email` | `VARCHAR(255)` | `PRIMARY KEY` | E-mail solicitante da recuperação de senha |
| `code_hash` | `VARCHAR(128)` | `NOT NULL` | Hash SHA-256 (`GastoSync::OTP::email::code`) |
| `expires_at` | `TIMESTAMPTZ` | `NOT NULL` | Expiração (10 minutos após geração) |
| `attempts` | `INT` | `NOT NULL DEFAULT 0` | Tentativas incorretas (bloqueia ao atingir `5`) |
| `created_at` | `TIMESTAMPTZ` | `NOT NULL DEFAULT NOW()` | Timestamp de emissão |

---

### 1.4 Tabela `transactions` (Movimentações Liquidadas)

| Coluna | Tipo | Constraints | Descrição |
| :--- | :--- | :--- | :--- |
| `id` | `BIGSERIAL` | `PRIMARY KEY` | ID sequencial interno no servidor |
| `user_id` | `UUID` | `NOT NULL REFERENCES users(id) ON DELETE CASCADE` | Proprietário do registro |
| `client_uuid` | `UUID` | `NOT NULL DEFAULT gen_random_uuid()` | Identificador único universal gerado pelo cliente |
| `local_id` | `BIGINT` | `NULL` | ID local legado para retrocompatibilidade |
| `description` | `VARCHAR(255)` | `NOT NULL` | Descrição da receita ou despesa (`1..255` chars) |
| `amount` | `NUMERIC(14, 2)` | `NOT NULL CHECK (amount > 0)` | Valor monetário exato em Reais |
| `tx_date` | `TIMESTAMPTZ` | `NOT NULL` | Data da movimentação |
| `tx_type` | `VARCHAR(20)` | `NOT NULL CHECK (tx_type IN ('income', 'expense'))` | Tipo (`income` ou `expense`) |
| `category` | `VARCHAR(100)` | `NOT NULL` | Categoria (Despesa nunca pode ser `'Renda'`) |
| `payment_method` | `VARCHAR(50)` | `NOT NULL DEFAULT 'PIX'` | `PIX`, `Débito`, `Crédito`, `Dinheiro`, `Transferência`, `Boleto` |
| `created_at` | `TIMESTAMPTZ` | `NOT NULL DEFAULT NOW()` | Timestamp de criação |
| `updated_at` | `TIMESTAMPTZ` | `NOT NULL DEFAULT NOW()` | Timestamp da última edição |
| `deleted_at` | `TIMESTAMPTZ` | `NULL` | Timestamp de exclusão lógica (Soft Delete) |

- **Constraints & Índices**:
  - `UNIQUE (user_id, client_uuid)`
  - `UNIQUE (user_id, local_id)`
  - `CREATE INDEX idx_transactions_user_date ON transactions(user_id, tx_date DESC) WHERE deleted_at IS NULL;`

---

### 1.5 Tabela `bills` (Boletos e Contas a Pagar)

| Coluna | Tipo | Constraints | Descrição |
| :--- | :--- | :--- | :--- |
| `id` | `BIGSERIAL` | `PRIMARY KEY` | ID sequencial interno no servidor |
| `user_id` | `UUID` | `NOT NULL REFERENCES users(id) ON DELETE CASCADE` | Proprietário do boleto |
| `client_uuid` | `UUID` | `NOT NULL DEFAULT gen_random_uuid()` | Identificador único universal gerado pelo cliente |
| `local_id` | `BIGINT` | `NULL` | ID local no SQLite |
| `description` | `VARCHAR(255)` | `NOT NULL` | Nome da conta/boleto (ex: `Energia Elétrica`, `Aluguel`) |
| `amount` | `NUMERIC(14, 2)` | `NOT NULL CHECK (amount > 0)` | Valor do boleto em Reais |
| `due_date` | `DATE` | `NOT NULL` | Data de vencimento do boleto |
| `category` | `VARCHAR(100)` | `NOT NULL` | Categoria orçamentária associada |
| `barcode` | `VARCHAR(255)` | `NOT NULL DEFAULT ''` | Linha digitável ou código PIX Copia e Cola |
| `is_recurring` | `BOOLEAN` | `NOT NULL DEFAULT FALSE` | Indica se o boleto repete mensalmente |
| `status` | `VARCHAR(20)` | `NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'paid', 'overdue'))` | Estado atual do boleto |
| `paid_at` | `TIMESTAMPTZ` | `NULL` | Data/hora em que foi dada baixa |
| `linked_tx_uuid` | `UUID` | `NULL` | `client_uuid` da transação gerada ao pagar o boleto |
| `last_notified_at` | `TIMESTAMPTZ` | `NULL` | Último envio de alerta por e-mail pelo worker |
| `created_at` | `TIMESTAMPTZ` | `NOT NULL DEFAULT NOW()` | Data de cadastro |
| `updated_at` | `TIMESTAMPTZ` | `NOT NULL DEFAULT NOW()` | Data da última alteração |
| `deleted_at` | `TIMESTAMPTZ` | `NULL` | Exclusão lógica (Soft Delete) |

- **Constraints & Índices**:
  - `UNIQUE (user_id, client_uuid)`
  - `CREATE INDEX idx_bills_user_due ON bills(user_id, status, due_date ASC) WHERE deleted_at IS NULL;`

---

### 1.6 Tabela `budgets`

| Coluna | Tipo | Constraints | Descrição |
| :--- | :--- | :--- | :--- |
| `id` | `BIGSERIAL` | `PRIMARY KEY` | ID interno |
| `user_id` | `UUID` | `NOT NULL REFERENCES users(id) ON DELETE CASCADE` | Proprietário da meta |
| `category` | `VARCHAR(100)` | `NOT NULL` | Nome da categoria |
| `limit_amount` | `NUMERIC(14, 2)` | `NOT NULL CHECK (limit_amount >= 0)` | Teto mensal em Reais |
| `month` | `INT` | `NOT NULL CHECK (month BETWEEN 1 AND 12)` | Mês de referência (`1..12`) |
| `year` | `INT` | `NOT NULL CHECK (year >= 2020)` | Ano de referência (`>= 2020`) |
| `updated_at` | `TIMESTAMPTZ` | `NOT NULL DEFAULT NOW()` | Última atualização |

---

## 2. Modelo Local Offline-First (Drift / SQLite — `gastosync_app`, Schema Version 3)

### 2.1 `LocalTransactions`
- `id`: `IntColumn` (`autoIncrement`)
- `clientUuid`: `TextColumn` (UUID v4 único)
- `userEmail`: `TextColumn` (e-mail da conta proprietária em minúsculas)
- `description`: `TextColumn` (`min: 1, max: 255`)
- `amount`: `RealColumn` (`> 0`)
- `date`: `DateTimeColumn`
- `type`: `TextColumn` (`'income'` | `'expense'`)
- `category`: `TextColumn`
- `paymentMethod`: `TextColumn` (default `'PIX'`)
- `isSynced`: `BoolColumn` (default `false`)
- `updatedAt`: `DateTimeColumn` (`nullable`)
- `deletedAt`: `DateTimeColumn` (`nullable`)

### 2.2 `LocalBills`
- `id`: `IntColumn` (`autoIncrement`)
- `clientUuid`: `TextColumn` (UUID v4 único)
- `userEmail`: `TextColumn` (e-mail da conta proprietária em minúsculas)
- `description`: `TextColumn` (`min: 1, max: 255`)
- `amount`: `RealColumn` (`> 0`)
- `dueDate`: `DateTimeColumn`
- `category`: `TextColumn`
- `barcode`: `TextColumn` (default `''`)
- `isRecurring`: `BoolColumn` (default `false`)
- `status`: `TextColumn` (`'pending'` | `'paid'` | `'overdue'`, default `'pending'`)
- `paidAt`: `DateTimeColumn` (`nullable`)
- `linkedTransactionId`: `IntColumn` (`nullable`)
- `linkedTxUuid`: `TextColumn` (`nullable`)
- `isSynced`: `BoolColumn` (default `false`)
- `updatedAt`: `DateTimeColumn` (`nullable`)
- `deletedAt`: `DateTimeColumn` (`nullable`)

### 2.3 Isolamento Multi-Conta em `LocalBudgets`, `LocalMetrics` e `LocalAgentInsights`
- Adição da coluna `userEmail` (`TextColumn` com default `'marcos.pereira@gastosync.local'`) nas três tabelas para que toda consulta e stream filtre pela conta autenticada atual.

---

## 3. Máquina de Estados de um Boleto (`BillStatus`)

```text
[Criado] ──(due_date >= hoje)──> PENDING
   │                                │
   └──(due_date < hoje)────────> OVERDUE
                                    │
   ┌────────────────────────────────┘
   ▼ (Usuário clica em "Dar Baixa / Pagar")
 PAID (paid_at = NOW(), gera Transaction com paymentMethod='Boleto')
   │
   └── Se is_recurring == true: cria novo Bill PENDING com due_date = +1 mês
```
