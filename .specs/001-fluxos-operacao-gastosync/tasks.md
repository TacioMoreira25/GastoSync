# Tasks: Fluxos de Operação GastoSync (Offline-First e Agente IA)

**Feature**: `001-fluxos-operacao-gastosync` | **Branch**: `001-fluxos-operacao-gastosync` | **Spec**: [spec.md](./spec.md) | **Plan**: [plan.md](./plan.md)

## Phase 1: Setup & Infraestrutura Compartilhada

**Purpose**: Configuração base do monorepo e ferramentas de desenvolvimento

- [x] T001 Estruturar monorepo com `gastosync_app` (Flutter) e `gastosync_agent` (Python)
- [x] T002 Configurar dependências essenciais no `pubspec.yaml` (Drift, Riverpod, Dio, fl_chart, GoRouter, Freezed)
- [x] T003 [P] Configurar regras de lint e análise estática em `gastosync_app/analysis_options.yaml`
- [x] T004 [P] Inicializar o GitHub Spec Kit (`.specify/` e `.agents/skills/`) com integração Antigravity

---

## Phase 2: Fundação & Persistência Local (Bloqueante)

**Purpose**: Infraestrutura de banco de dados reativo Drift e cliente de rede que desbloqueiam todas as User Stories

**⚠️ CRÍTICO**: Nenhuma User Story pode ser finalizada sem a camada Drift ativa

- [x] T005 Implementar tabelas `LocalTransactions` e `LocalBudgets` em `gastosync_app/lib/core/database/app_database.dart`
- [x] T006 Implementar tabela `LocalMetrics` (snapshots históricos das 9 métricas) em `gastosync_app/lib/core/database/app_database.dart`
- [x] T007 Implementar tabela `LocalAgentInsights` (persistência das sugestões do Llama 3.3) em `gastosync_app/lib/core/database/app_database.dart`
- [x] T008 Executar `build_runner` para regenerar `app_database.g.dart` com as 4 tabelas
- [x] T009 Configurar cliente HTTP `Dio` com timeouts de 10s/20s e base URL em `gastosync_app/lib/core/network/dio_client.dart`
- [x] T010 [P] Configurar `GoRouter` com navegação adaptativa em `gastosync_app/lib/core/router/app_router.dart`

**Checkpoint**: Camada de banco de dados e rede pronta para implementação das User Stories

---

## Phase 3: User Story 1 - Registro e Leitura 100% Offline-First (Priority: P1) 🎯 MVP

**Goal**: Permitir que o usuário cadastre receitas/despesas sem internet, com persistência imediata no Drift e atualização reativa das streams

**Independent Test**: Desconectar a rede (modo avião), cadastrar uma despesa e verificar que ela aparece instantaneamente na listagem e altera o saldo sem reload

### Testes da User Story 1 ⚠️
- [x] T011 [P] [US1] Testes unitários de inserção e stream no Drift em `gastosync_app/test/core/database/app_database_test.dart`
- [x] T012 [P] [US1] Teste de cálculo de saldo com múltiplas transações de receita/despesa em `gastosync_app/test/features/transactions/domain/transaction_calculations_test.dart`

### Implementação da User Story 1
- [x] T013 [P] [US1] Criar modelo de domínio e DTOs de Transação em `gastosync_app/lib/features/transactions/domain/models/transaction.dart`
- [x] T014 [US1] Implementar repositório `TransactionRepository` conectando ao `AppDatabase` em `gastosync_app/lib/features/transactions/data/repositories/transaction_repository_impl.dart`
- [x] T015 [US1] Criar provedor Riverpod `watchTransactionsProvider` escutando a stream do Drift em `gastosync_app/lib/features/transactions/presentation/controllers/transactions_controller.dart`
- [x] T016 [US1] Implementar tela de listagem de transações em `gastosync_app/lib/features/transactions/presentation/screens/transactions_screen.dart`
- [x] T017 [US1] Implementar formulário manual de cadastro rápido de transação com validação de campos

**Checkpoint**: User Story 1 funcional de ponta a ponta em modo 100% offline (MVP validado!)

---

## Phase 4: User Story 2 - Sugestão Preditiva & Modal Human-in-the-Loop (Priority: P1)

**Goal**: Ao cadastrar gasto com descrição vaga, acionar o backend Python via Dio, processar no Llama 3.3 e exibir Modal Human-in-the-Loop para validação do usuário antes de salvar no Drift

**Independent Test**: Chamar o fluxo com texto vago ("lanche tarde 25"), receber a categorização da IA, abrir o modal de confirmação, alterar a categoria manualmente e verificar persistência no Drift e na tabela `LocalAgentInsights`

### Testes da User Story 2 ⚠️
- [x] T018 [P] [US2] Testes unitários do cliente de predição com mock HTTP do Dio em `gastosync_app/test/features/budget_agent/data/budget_agent_api_test.dart`
- [x] T019 [P] [US2] Testes de widget do Modal Human-in-the-Loop (edição e confirmação) em `gastosync_app/test/features/transactions/presentation/widgets/human_in_the_loop_modal_test.dart`

### Implementação da User Story 2
- [x] T020 [P] [US2] Criar modelos Freezed para request e response de predição (`AgentPredictionRequest`, `AgentPredictionResponse`)
- [x] T021 [US2] Implementar serviço de comunicação `BudgetAgentService` acionando `POST /predict/categorize`
- [x] T022 [US2] Implementar widget adaptativo `HumanInTheLoopModal` (BottomSheet para mobile, Dialog para Web) com edição de categoria, valor e descrição
- [x] T023 [US2] Integrar confirmação do modal com a gravação simultânea na tabela `LocalTransactions` e `LocalAgentInsights` no Drift
- [x] T024 [US2] Implementar tratamento de fallback gracioso (timeout de 10s ou falha de rede) permitindo cadastro manual sem interrupção

**Checkpoint**: Fluxo B integrado com sucesso mantendo o usuário no controle total dos dados

---

## Phase 5: User Story 3 - Input por Texto Informal e OCR de Comprovantes (Priority: P2)

**Goal**: Permitir digitação em linguagem natural ("uber 22 reais") e envio de fotos de notas fiscais para extração automática

**Independent Test**: Digitar texto livre e carregar imagem de recibo, verificando se os campos são preenchidos corretamente no modal Human-in-the-Loop

### Implementação da User Story 3
- [x] T025 [P] [US3] Criar componente de entrada de texto informal `QuickExpenseInputField` no Dashboard
- [x] T026 [P] [US3] Implementar seletor/captura de imagem de comprovante via `image_picker`
- [x] T027 [US3] Implementar chamada multipart `POST /predict/ocr` no `BudgetAgentService` com timeout de 20s
- [x] T028 [US3] Conectar o retorno do OCR diretamente ao `HumanInTheLoopModal` para revisão humana

---

## Phase 6: User Story 4 - Visualização das 9 Métricas de Saúde Financeira e Gráficos (Priority: P2)

**Goal**: Calcular continuamente as 9 métricas financeiras locais e exibir no Dashboard adaptativo com gráficos `fl_chart`

**Independent Test**: Cadastrar múltiplas receitas e despesas e validar matematicamente os 9 cards e o gráfico de fluxo de caixa

### Implementação da User Story 4
- [x] T029 [P] [US4] Implementar classe de domínio `FinancialHealthEngine` com os algoritmos das 9 métricas
- [x] T030 [US4] Criar `financialMetricsStreamProvider` no Riverpod que consome as transações do Drift e emite o objeto `FinancialMetrics`
- [x] T031 [US4] Atualizar `DashboardScreen` conectando os 9 cards aos dados reativos reais do provider (substituindo dados mockados)
- [x] T032 [US4] Conectar o gráfico `LineChart` do `fl_chart` aos dados reais de receitas vs despesas dos últimos 6 meses
- [x] T033 [US4] Implementar card de insight dinâmico consumindo o último registro de `LocalAgentInsights`

---

## Phase 7: Polish, Testes Integrados & Homologação

**Purpose**: Qualidade transversal, responsividade e documentação

- [x] T034 [P] Testes de regressão multiplataforma (Android, iOS e Web)
- [x] T035 [P] Testes de persistência em modo offline simulando perda súbita de conexão
- [x] T036 Documentação técnica da aplicação Web e guia de build para Vercel/Firebase

---

## Phase 8: Fronteira Externa - Tarefas do Agente IA (Equipe de Backend / Terceiros)

> [!NOTE]
> Esta seção mapeia estritamente o backlog da equipe externa do agente (`gastosync_agent`) para rastreabilidade de contratos, sem necessidade de implementação no app Flutter.

- [x] T-IA01 Configuração de Ambiente e Chaves Groq (`gastosync_agent`)
- [x] T-IA02 Prompt Engineering (PLN/Texto para categorização Llama 3.3)
- [ ] T-IA03 Prompt Engineering (OCR/Visão para leitura de comprovantes)
- [ ] T-IA04 Modelagem do Agente Preditivo e Burn Rate
- [ ] T-IA05 Sanitização contra Prompt Injection na API FastAPI
- [ ] T-IA06 Definição e validação dos Contratos JSON (Pydantic schemas)
- [ ] T-IA07 Testes de Acurácia e Rate Limits da API Groq
- [ ] T-IA08 Documentação Técnica da API do Agente

---

## Dependências e Ordem de Execução

1. **Phase 1 (Setup)** e **Phase 2 (Fundação Drift)** DEVEM ser concluídas primeiro.
2. **Phase 3 (User Story 1 - MVP)** entrega a aplicação funcional 100% offline.
3. **Phase 4 (User Story 2 - Agente IA & Human-in-the-Loop)** conecta o cliente Dio ao backend Python.
4. **Phase 5 (User Story 3 - OCR & Texto Informal)** expande os canais de input.
5. **Phase 6 (User Story 4 - 9 Métricas)** conecta o Dashboard analítico reativo.
6. **Phase 7 (Polish)** finaliza a entrega e homologação.
