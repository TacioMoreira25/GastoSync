# Feature Specification: Fluxos de Operação GastoSync (Offline-First e Agente IA)

**Feature Branch**: `001-fluxos-operacao-gastosync`

**Created**: 2026-10-20

**Status**: Ready for Planning

**Input**: User description: "Fluxo A: Registro e Leitura Diária de Transações (100% Local / Offline-First via Drift Streams) e Fluxo B: Acionamento do Agente de IA Preditivo e Orçamentário com persistência de insight e modal Human-in-the-Loop."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Registro e Leitura Diária de Transações 100% Offline-First (Priority: P1)

Como usuário do GastoSync, quero registrar minhas receitas e despesas instantaneamente mesmo sem acesso à internet, tendo minhas métricas financeiras e gráficos atualizados em tempo real na tela sem necessidade de recarregar a aplicação.

**Why this priority**: É o núcleo de valor do produto (Fluxo A). O aplicativo deve ser confiável, ultrarrápido e utilizável em qualquer condição de conectividade.

**Independent Test**: Pode ser testado desconectando o dispositivo da rede (modo avião), inserindo uma transação e verificando imediatamente a escrita no Drift e a atualização dos cards de Saldo e Reserva via Stream.

**Acceptance Scenarios**:

1. **Given** que o usuário está na tela de transações (online ou offline), **When** insere uma nova despesa de R$ 150,00 com categoria "Alimentação", **Then** a transação é persistida imediatamente na tabela local do Drift com `isSynced = false`.
2. **Given** uma nova transação inserida com sucesso no Drift, **When** a tabela emite um evento pela Stream reativa, **Then** a interface do Dashboard recalcula instantaneamente o Saldo Líquido e a Taxa de Poupança sem recarregar a tela.

---

### User Story 2 - Sugestão Preditiva e Modal Human-in-the-Loop (Priority: P1)

Como usuário que insere uma despesa com descrição vaga ou não categorizada, quero que o assistente de IA analise o gasto via backend seguro e me sugira categoria, nível de confiança e uma dica orçamentária, permitindo que eu revise e confirme as informações antes de salvar.

**Why this priority**: É a essência do Fluxo B com inteligência artificial, garantindo controle e confiança do usuário através do princípio Human-in-the-Loop.

**Independent Test**: Inserir uma despesa com texto vago ("lanche tarde 25"), acionar a IA, observar a abertura do modal BottomSheet/Dialog com a resposta estruturada do Llama 3.3 70B, editar a categoria e confirmar a gravação no Drift.

**Acceptance Scenarios**:

1. **Given** uma despesa com descrição vaga cadastrada com conexão à internet ativa, **When** o cliente Dio envia a requisição para o backend orquestrador (`gastosync_agent`), **Then** o app recebe categoria preditiva, nível de confiança (%) e dica orçamentária.
2. **Given** o retorno da inferência estruturada da IA, **When** o modal Human-in-the-Loop é exibido, **Then** o usuário pode aceitar a sugestão ou modificar qualquer campo antes que o registro seja gravado definitivamente no Drift.
3. **Given** que a chamada ao backend falhe por timeout (10s) ou ausência de rede, **When** a exceção for capturada pelo Dio, **Then** o app apresenta fallback amigável permitindo categorização manual direta sem travar o app.

---

### User Story 3 - Input por Texto Informal e Extração de Comprovantes via OCR (Priority: P2)

Como usuário em trânsito, quero registrar gastos digitando frases naturais (ex: "almoço 45 reais no debito") ou tirando uma foto do cupom fiscal, para que a IA extraia o valor e detalhes automaticamente para minha validação.

**Why this priority**: Acelera drasticamente a entrada diária de dados, reduzindo a fricção e o abandono do registro financeiro.

**Independent Test**: Enviar uma frase informal no campo de texto rápido ou carregar uma imagem de comprovante e verificar se os campos são preenchidos corretamente no modal Human-in-the-Loop.

**Acceptance Scenarios**:

1. **Given** uma frase informal digitada pelo usuário, **When** submetida ao endpoint de predição, **Then** os campos `amount`, `description` e `category` são extraídos e apresentados no modal de confirmação.
2. **Given** uma foto de recibo capturada pela câmera ou galeria, **When** enviada para análise de visão, **Then** o backend processa o OCR e retorna os itens detectados para validação humana.

---

### User Story 4 - Visualização Consolidada das 9 Métricas de Saúde Financeira (Priority: P2)

Como usuário focado em educação financeira, quero visualizar no Dashboard um painel composto pelos 9 indicadores vitais de saúde financeira e gráficos evolutivos para entender meu comportamento de gastos.

**Why this priority**: Entrega a percepção de valor analítico e saúde patrimonial do usuário.

**Independent Test**: Inserir uma série de receitas e despesas e validar matematicamente cada um dos 9 cards e as curvas de receita/despesa no gráfico `fl_chart`.

**Acceptance Scenarios**:

1. **Given** o histórico de transações locais, **When** o Dashboard é renderizado, **Then** os 9 cards exibem: Saldo Líquido, Receita Total, Despesa Total, Taxa de Poupança (%), Reserva em Meses, Comprometimento da Renda (%), Burn Rate Diário, Projeção de Fim de Mês e Score de Saúde Financeira (0-100).
2. **Given** a alteração em uma despesa, **When** a stream do Drift atualiza os dados, **Then** a projeção de fim de mês e o score reagem automaticamente.

---

### Edge Cases

- **Ausência de Internet (Modo Offline)**: Ao acionar a IA sem conexão, o app deve exibir mensagem clara ("Assistente indisponível offline") e transicionar imediatamente para a tela de preenchimento manual local.
- **Timeout do Backend**: Requisições de texto que excedam 10 segundos ou OCR que excedam 20 segundos devem disparar cancelamento gracioso pelo Dio sem congelar a interface.
- **Valores e Entradas Inválidas**: Inserções com valor negativo ou igual a zero devem ser bloqueadas na camada de validação do formulário local.
- **Ambiguidades em Texto Informal**: Se a IA retornar confiança < 50%, o modal Human-in-the-Loop deve abrir com destaque visual de alerta solicitando confirmação manual obrigatória da categoria.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: O sistema DEVE persistir todas as transações diretamente no SQLite local via Drift antes de qualquer sincronização externa.
- **FR-002**: O sistema DEVE expor streams reativas (`watchAllTransactions`, `watchBudgets`, etc.) que notificam a interface automaticamente sobre qualquer alteração no banco.
- **FR-003**: O sistema DEVE calcular localmente as 9 Métricas de Saúde Financeira sem requisições a serviços externos.
- **FR-004**: O sistema DEVE fornecer um cliente HTTP (Dio) configurado com timeouts de 10s para texto e 20s para OCR, com base URL configurável para o backend `gastosync_agent`.
- **FR-005**: O sistema DEVE exibir o Modal Human-in-the-Loop como BottomSheet em telas móveis (< 600dp) e Dialog centralizado na Web (≥ 800dp).
- **FR-006**: O sistema DEVE permitir ao usuário editar `description`, `amount`, `category` e `type` no modal antes de persistir no banco local.
- **FR-007**: O sistema DEVE armazenar os insights e recomendações preditivas retornados pelo agente na tabela local `LocalAgentInsights`.
- **FR-008**: O sistema DEVE armazenar as métricas consolidadas na tabela `LocalMetrics` para histórico e performance de consultas offline.
- **FR-009**: O sistema DEVE sanitizar e validar campos obrigatórios (valor > 0, descrição não vazia, data válida).
- **FR-010**: O sistema DEVE renderizar os gráficos de fluxo de caixa (Receita vs Despesa) utilizando a biblioteca `fl_chart`.
- **FR-011**: O sistema DEVE garantir que nenhuma chave de API secreta (ex: Groq API Key) seja armazenada ou exposta no código-fonte do cliente Flutter.

### Key Entities

- **Transaction (`LocalTransactions`)**: Representa uma movimentação financeira individual. Atributos: `id`, `description`, `amount`, `date`, `type` (income/expense), `category`, `isSynced`.
- **Budget (`LocalBudgets`)**: Limite orçamentário mensal definido por categoria. Atributos: `id`, `category`, `limitAmount`, `month`, `year`.
- **MetricRecord (`LocalMetrics`)**: Snapshot consolidado das métricas de saúde financeira. Atributos: `id`, `calculatedAt`, `currentBalance`, `totalIncome`, `totalExpense`, `savingsRate`, `emergencyMonths`, `incomeCommitment`, `dailyBurnRate`, `monthEndProjection`, `healthScore`.
- **AgentInsight (`LocalAgentInsights`)**: Registro do insight fornecido pela IA para acompanhamento e auditoria. Atributos: `id`, `transactionId` (opcional), `rawSuggestion`, `confidenceScore`, `categorySuggested`, `budgetTip`, `createdAt`.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: O salvamento local de uma transação e atualização das streams na interface DEVE ocorrer em menos de 100 milissegundos.
- **SC-002**: 100% das operações de cadastro, listagem e visualização de métricas DEVEM funcionar perfeitamente em modo avião (sem rede).
- **SC-003**: Respostas de inferência preditiva via Dio quando online DEVEM ser exibidas no modal Human-in-the-Loop em menos de 2.5 segundos (rede normal).
- **SC-004**: 100% das transações geradas por IA DEVEM requerer confirmação ou edição do usuário antes da inserção final no Drift.
- **SC-005**: A interface DEVE se adaptar responsivamente sem quebras ou rolagem horizontal anômala entre 360dp (Mobile) e 1920dp (Web/Desktop).

## Assumptions

- O backend Python (`gastosync_agent`) será hospedado e mantido por outro membro da equipe, fornecendo os endpoints REST `/predict/categorize`, `/predict/ocr` e `/agent/budget-burn-rate`.
- O cliente Flutter conectará ao backend via HTTPS seguro utilizando URLs parametrizadas por variáveis de ambiente (`dotenv` ou `--dart-define`).
- O suporte Web do Drift usará fallback de memória em desenvolvimento e SQLite WASM em builds de produção para garantir compatibilidade multiplataforma.
