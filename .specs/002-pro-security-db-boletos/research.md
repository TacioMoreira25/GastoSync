# Phase 0 Research: Segurança de Conta por OTP, Gestão de Boletos e Evolução Pro de Dados

**Feature**: `002-pro-security-db-boletos`
**Date**: 2026-11-08

---

## Decision 1: Arquitetura Relacional Multi-Tenant (Tabela Única Compartilhada vs. Sub-tabela por Usuário)

- **Decision**: Manter **uma única tabela relacional por entidade** (`users`, `transactions`, `bills`, `budgets`) no PostgreSQL com chave estrangeira `user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE` e índices B-Tree compostos iniciados por `user_id` (`(user_id, tx_date DESC)`, `(user_id, status, due_date ASC)`, `(user_id, year, month)`). No SQLite local (Drift), isolar todas as tabelas (`LocalTransactions`, `LocalBills`, `LocalBudgets`, `LocalMetrics`, `LocalAgentInsights`) pela coluna `userEmail` indexada.
- **Rationale**:
  1. **Performance $O(\log N)$ via B-Tree Composto**: Como `user_id` é a primeira coluna do índice composto, o PostgreSQL agrupa contiguamente todas as entradas de um mesmo usuário nas páginas de índice. Uma consulta `WHERE user_id = $1` ou uma deleção em cascata `DELETE FROM users WHERE id = $1` acessa diretamente a sub-árvore daquele usuário em menos de 1 ms, sem nunca fazer *full table scan* nos dados dos demais usuários.
  2. **Escalabilidade em Serverless Postgres (Neon)**: Criar sub-tabelas por usuário (`transactions_u1`, `transactions_u2`...) gera explosão de catálogo (`pg_class`, `pg_attribute`) e milhares de descritores de arquivo no armazenamento, inviabilizando *connection pooling* e migrações de schema (`ALTER TABLE`).
  3. **Integridade Referencial e Segurança**: O uso de `ON DELETE CASCADE` garante que, ao remover um usuário, todos os seus registros dependentes em `transactions`, `bills`, `budgets` e tokens sejam expurgados atomicamente em uma única transação ACID.

---

## Decision 2: Precisão Monetária e Identidade de Sincronização (`NUMERIC(14,2)` + `client_uuid` + Soft Delete)

- **Decision**:
  1. Migrar colunas monetárias no PostgreSQL (`amount`, `limit_amount`, `monthly_income`, `savings_goal_percent`) de `DOUBLE PRECISION` para `NUMERIC(14, 2)` (e `NUMERIC(5, 2)` para percentuais).
  2. Adicionar `client_uuid UUID` (gerado no cliente no momento da criação), `payment_method`, `updated_at` e `deleted_at` (Soft Delete) em `transactions` e `bills`.

---

## Decision 3: Tabela Dedicada de Boletos (`bills` / `LocalBills`), Baixa Vinculada e Cobranças Embutidas na Fatura do Cartão (`is_credit_card_charge`)

- **Decision**:
  1. Criar uma tabela dedicada `bills` no PostgreSQL e `LocalBills` no Drift (SQLite), separada da tabela `transactions`.
  2. Quando o usuário marca um boleto convencional (`is_credit_card_charge = false`) como pago ("Dar Baixa"), o boleto passa para `status = 'paid'`, registra `paid_at`, cria automaticamente uma despesa em `transactions` referenciada por `linked_tx_uuid` / `linkedTransactionId` e, se `is_recurring = true`, gera automaticamente o boleto pendente do mês seguinte.
  3. Incluir o campo `is_credit_card_charge BOOLEAN NOT NULL DEFAULT FALSE` ("Desconta no Cartão / Incluso na Fatura") para assinaturas e despesas recorrentes cobradas no cartão de crédito (ex.: Academia, Streaming) quando o usuário também cadastra a Fatura Mensal do Cartão:
     - **Alertas 2x ao dia ativos**: Notifica normalmente na data do desconto para o usuário lembrar de liberar o limite do cartão.
     - **Sem Dupla Contagem no Caixa**: Não soma no "Valor Final a Pagar" de boletos e, ao ser confirmado no mês, não gera saída duplicada no Saldo Líquido (pois o desembolso financeiro já ocorre no pagamento da Fatura do Cartão).
     - **Alocação Inteligente por Categoria**: O valor e a categoria do item (`category`, ex.: `Saúde`) são considerados no cálculo de consumo por categoria (gráficos e barras de `Planejamento`), abatendo automaticamente o mesmo montante da categoria genérica da Fatura do Cartão para que a soma das categorias nunca ultrapasse o gasto real.

---

## Decision 4: Verificação de E-mail no Cadastro via Código OTP de 6 Dígitos

- **Decision**: Reutilizar e expandir a arquitetura criptográfica de OTP de 6 dígitos (CSPRNG + hash SHA-256 com salt de contexto + comparação em tempo constante `subtle.ConstantTimeCompare` + expiração de 10 minutos + máximo de 5 tentativas) em uma tabela dedicada `email_verification_tokens`, exigindo confirmação logo após `POST /api/v1/auth/register`.

---

## Decision 5: Motor de Notificações de Boletos 2x ao Dia + Auditoria Cloudflare

- **Decision**:
  1. Armazenar no perfil do usuário dois horários diários configuráveis (`reminder_time_1` padrão `'09:00'` e `reminder_time_2` padrão `'18:00'`) e a flag `email_bill_notifications` (`true` por padrão).
  2. No cliente (`BillNotificationService`), verificar nos dois turnos diários todos os boletos com `status != 'paid'` cujo vencimento seja `<= hoje + 3 dias`, disparando notificação local/nativa e card de destaque na Central de Notificações (`GastoSyncNotificationsModal`), registrando a janela notificada para evitar repetição no mesmo turno.
  3. No servidor Go (`StartBillReminderWorker`), executar verificação periódica para enviar lembrete por e-mail nos dois horários configurados pelo usuário.
  4. Instalar e utilizar a skill oficial `cloudflare/security-audit-skill` (`.agents/skills/security-audit/SKILL.md`) na fase final de verificação do projeto.

---

## Decision 6: Gestão de Cartões de Crédito (Principal e Secundário) e Faixa Saudável de Limite (50%–80%)

- **Decision**:
  1. Criar a tabela `credit_cards` no PostgreSQL e `LocalCreditCards` no Drift SQLite armazenando apenas metadados de gestão financeira (`name`, `limit_amount`, `target_min_percent` default `50.0`, `target_max_percent` default `80.0`, `due_day`, `is_primary`). Jamais armazenar PAN (número do cartão), CVV ou validade (conformidade PCI/OWASP).
  2. Adicionar a referência opcional `credit_card_uuid` em `transactions` e `bills` para permitir associar compras no crédito (ex.: Mercado) e assinaturas recorrentes no cartão (ex.: Academia) ao Cartão Principal ou a um Cartão Secundário.
  3. Na tela `Planejamento` (sub-aba/seção `Cartões & Limite`) e no `Dashboard`, calcular em tempo real para cada cartão no mês:
     - **Fixas / Assinaturas no Cartão**: Soma dos `bills` com `is_credit_card_charge = true` daquele cartão.
     - **Variáveis / Compras no Cartão**: Soma das `transactions` do tipo `expense` com `payment_method = 'Crédito'` vinculadas àquele cartão.
     - **Indicador de Bom Relacionamento Bancário**: Exibe a meta de utilização saudável (ex.: 50% a 80% — `R$ 750,00` a `R$ 1.200,00` para um limite de `R$ 1.500,00`), a margem restante até o teto de 80% e alerta preventivo caso o usuário ultrapasse o percentual saudável configurado.
