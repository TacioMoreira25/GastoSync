# Quickstart & Validation Guide: `002-pro-security-db-boletos`

**Feature**: Segurança de Conta por OTP, Gestão de Boletos com Alertas Diários e Evolução Pro de Dados
**Spec**: [spec.md](./spec.md) | **Data Model**: [data-model.md](./data-model.md) | **Contracts**: [api-contracts.md](./contracts/api-contracts.md)

---

## 1. Pré-requisitos

- **Go**: `1.23+`
- **Flutter SDK**: `3.x+` / Dart `3.x+`
- **PostgreSQL**: Local (via `docker compose up -d` em `gastosync_api/`) ou instância Neon Serverless configurada em `gastosync_api/.env`

---

## 2. Validação Automatizada do Backend (`gastosync_api`)

```bash
cd gastosync_api
go vet ./...
go test -v ./...
go build -o api ./cmd/api
```

### Cenários Validados nos Testes da API:
1. **Política de Senha Forte OWASP**: Rejeição de senhas curtas ou sem letra maiúscula, minúscula, número ou caractere especial em `/api/v1/auth/register` e `/api/v1/auth/reset-password`.
2. **Fluxo OTP de Verificação de E-mail**: Registro gera OTP de 6 dígitos (`email_verified = false`), bloqueia login antes da verificação (`403 EMAIL_NOT_VERIFIED`) e libera token JWT após `POST /api/v1/auth/verify-email`.
3. **Sync de Transações e Boletos**: Preservação de `payment_method`, `client_uuid`, `deleted_at` e campos de `bills` (`due_date`, `barcode`, `is_recurring`, `status`, `linked_tx_uuid`).

---

## 3. Validação Automatizada do Aplicativo (`gastosync_app`)

```bash
cd gastosync_app
flutter analyze
flutter test
```

### Cenários Validados nos Testes do App:
1. **Isolamento e Persistência Drift (Schema v3)**: Salvamento e leitura de `paymentMethod`, `clientUuid` e filtro por `userEmail` em todas as tabelas locais.
2. **Ciclo de Boletos e Recorrência**:
   - Criação de boleto pendente em `LocalBills` sem alterar o saldo realizado.
   - Baixa de boleto (`payBillAndCreateTransaction`) gerando automaticamente a despesa em `LocalTransactions` com `paymentMethod = 'Boleto'` e agendando o boleto do mês seguinte quando `isRecurring == true`.
3. **Motor de Notificações 2x ao Dia (`BillNotificationService`)**:
   - Disparo nos dois horários configurados (padrão `09:00` e `18:00`) para boletos vencidos, vencendo hoje ou em até 3 dias, sem duplicidade no mesmo turno.
4. **Edição e Exportação CSV**:
   - Atualização in-place de transação/boleto existente e geração de CSV com todas as colunas financeiras.

---

## 4. Auditoria de Segurança Final (`cloudflare/security-audit-skill`)

Após concluir todas as tarefas de implementação em `tasks.md`, executar o workflow de 6 fases definido em [`.agents/skills/security-audit/SKILL.md`](../../.agents/skills/security-audit/SKILL.md):

1. Fase 1: Reconnaissance & Escopo (`gastosync_api`, `gastosync_app`, `gastosync_agent`)
2. Fase 2: Coverage-Led Hunting (Auth/OTP, Isolamento Multi-Tenant `user_id`, SQL/Drift, Prompt Sanitization)
3. Fase 3: Candidate Validation
4. Fase 4: Independent Verification
5. Fase 5 & 6: Validação de schema e geração do relatório final em `.specs/002-pro-security-db-boletos/security-audit-report.md`
