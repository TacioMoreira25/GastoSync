# Release & Architecture Readiness Checklist: Fluxos de Operação GastoSync

**Purpose**: Validação da completude, clareza, consistência e cobertura dos requisitos de Offline-First (Mobile), Web Online, Autenticação JWT/Bcrypt, Sincronização em Nuvem (Go + Neon Postgres) e Interface Adaptativa v2.
**Created**: 2026-11-03
**Feature**: [spec.md](../spec.md) | [plan.md](../plan.md) | [tasks.md](../tasks.md)

**Note**: Este checklist foi gerado pelo comando `/speckit-checklist` com base no contexto e nos requisitos da feature.
**Review Ownership**: Artefato de revisão pertencente ao revisor. Marque um item como `[x]` apenas quando o critério de qualidade do requisito for considerado satisfeito.
**Marker Semantics**: `[x]` significa que o critério foi revisado e aprovado quanto à qualidade da especificação.

---

## Requirement Completeness (Completude dos Requisitos)

- [ ] CHK001 - Os requisitos de persistência local Offline-First no Mobile estão explicitamente documentados para todas as 4 tabelas do Drift (`LocalTransactions`, `LocalBudgets`, `LocalMetrics`, `LocalAgentInsights`)? [Completeness, Spec §FR-001, §FR-007, §FR-008]
- [ ] CHK002 - Os contratos de requisição e resposta para autenticação (`POST /api/v1/auth/register`, `POST /api/v1/auth/login`, `GET /api/v1/auth/me`) estão completamente especificados? [Completeness, Spec §FR-015, Plan §REST API Contracts]
- [ ] CHK003 - Os contratos de sincronização bidirecional (`POST /api/v1/sync/push` e `GET /api/v1/sync/pull`) especificam o isolamento estrito por `user_id` extraído do token JWT? [Completeness, Spec §FR-016, §FR-018]
- [ ] CHK004 - Todos os campos e ações do modal unificado `Adicionar transação` (Entrada Inteligente com IA/OCR, abas Despesa/Receita, Valor, Descrição, Categoria, Meio de Pagamento e Data) estão especificados? [Completeness, Spec §FR-005]
- [ ] CHK005 - As fórmulas matemáticas das 9 Métricas de Saúde Financeira estão integralmente documentadas sem variáveis indefinidas? [Completeness, Spec §FR-003, Plan §Algoritmos das 9 Métricas]

## Requirement Clarity (Clareza e Especificidade)

- [ ] CHK006 - A distinção operacional entre Mobile (100% Offline-First via SQLite nativo) e Web (operação online autenticada via API REST) está definida sem ambiguidade? [Clarity, Spec §FR-016, §FR-017, Constitution §I]
- [ ] CHK007 - Os breakpoints de responsividade entre o layout Mobile (`< 600dp` / `< 800dp` com barra inferior) e o layout Web/Desktop (`>= 800dp` com Sidebar esquerda fixa e Grid de 2 colunas) estão quantificados? [Clarity, Spec §FR-013]
- [ ] CHK008 - Os requisitos de força de senha (tamanho mínimo, maiúsculas, minúsculas, dígitos, caracteres especiais e bloqueio de senhas comuns) estão claramente definidos para criação e redefinição de conta? [Clarity, Spec §FR-015]
- [ ] CHK009 - Os tokens visuais do protótipo v2 (`#0F172A` Navy, `#10B981` Emerald, `#F8FAFC` Background, `#F59E0B` Amber Warning) estão especificados para cada componente da UI? [Clarity, Plan §Especificação Visual do Protótipo v2]

## Requirement Consistency (Consistência entre Artefatos)

- [ ] CHK010 - A arquitetura de 3 camadas (`gastosync_app` em Flutter, `gastosync_api` em Go e `gastosync_agent` em Python) está alinhada entre `constitution.md`, `spec.md`, `plan.md` e `tasks.md`? [Consistency, Constitution §II]
- [ ] CHK011 - As 4 abas principais de navegação (`Início`, `Transações`, `Planejamento`, `Mais`) estão consistentes entre as especificações de rota do `GoRouter` e os cenários de aceitação? [Consistency, Spec §FR-013, Plan §Estrutura de Navegação]
- [ ] CHK012 - A separação de responsabilidades entre o botão central `+` (lançamento de transações com preenchimento IA/OCR) e o botão flutuante `G✨` (chat conversacional de dúvidas financeiras) está consistente em toda a documentação? [Consistency, Spec §FR-005, §FR-006]

## Acceptance Criteria Quality (Mensurabilidade)

- [ ] CHK013 - O tempo limite de escrita local e atualização reativa das streams no Drift (`< 100ms`) é objetivamente verificável? [Measurability, Spec §SC-001]
- [ ] CHK014 - Os tempos limites (timeouts) das chamadas HTTP (`10s` para inferência textual, `20s` para OCR e `25s` para cold-start da API Core) estão quantificados? [Measurability, Spec §FR-004, Plan §Performance Goals]
- [ ] CHK015 - A exigência de 100% de confirmação humana (*Human-in-the-Loop*) antes da persistência de sugestões geradas por IA é verificável nos critérios de aceite? [Measurability, Spec §SC-004, Constitution §III]

## Scenario & Edge Case Coverage (Cobertura de Cenários e Exceções)

- [ ] CHK016 - O comportamento de fallback quando o backend de IA (`gastosync_agent`) ou a API Core (`gastosync_api`) estão inacessíveis ou sofrem timeout está especificado sem bloqueio da interface? [Edge Case, Spec §Edge Cases]
- [ ] CHK017 - As regras de bloqueio contra entradas inválidas (valores `<= 0`, descrições vazias, tentativas repetidas de login incorreto) estão definidas? [Edge Case, Spec §FR-009, §Edge Cases]
- [ ] CHK018 - O comportamento de isolamento de dados ao alternar entre contas de usuários diferentes (filtragem por `userEmail` / `user_id` e limpeza de sessão no Logout) está coberto? [Coverage, Spec §FR-018, Constitution §VI]
- [ ] CHK019 - O tratamento de idempotência na sincronização (`UNIQUE (user_id, local_id)` e `(user_id, category, month, year)`) está especificado para evitar duplicação de lançamentos em múltiplos cliques de sync? [Coverage, Plan §REST API Contracts]

## Non-Functional & Security Requirements (Segurança e Governança)

- [ ] CHK020 - A proibição de exposição de chaves secretas (`DATABASE_URL`, `JWT_SECRET`, `API_KEY_GROQ`) no código-fonte cliente ou no controle de versão está documentada e garantida? [Security, Spec §FR-011, §FR-018, Constitution §VI]
- [ ] CHK021 - Os requisitos de sanitização contra *Prompt Injection* antes do envio de textos livres ao agente de IA estão especificados? [Security, Plan §Summary, Constitution §VI]

---

## Notes

- Marque os itens como `[x]` após validar que a especificação e a entrega atendem ao critério.
- `/speckit-implement` utiliza a pasta `checklists/` como gate de leitura e não altera os marcadores automaticamente.
