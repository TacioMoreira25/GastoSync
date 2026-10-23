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

### User Story 4 - Visualização Consolidada das 9 Métricas de Saúde Financeira e Planejamento (Priority: P2)

Como usuário focado em educação financeira, quero visualizar no Dashboard (aba `Início`) e na tela de `Planejamento` meus indicadores vitais de saúde financeira, limites mensais de orçamento por categoria e gráficos evolutivos de Burn Rate para entender meu comportamento de gastos.

**Why this priority**: Entrega a percepção de valor analítico, controle de tetos orçamentários e saúde patrimonial do usuário conforme o novo protótipo de alta fidelidade.

**Independent Test**: Inserir uma série de receitas, despesas e limites de categoria (`LocalBudgets`) e validar matematicamente os cards da tela `Início`, a curva de Burn Rate vs. Teto Mensal e as barras de progresso por categoria na aba `Planejamento`.

**Acceptance Scenarios**:

1. **Given** o histórico de transações locais, **When** a aba `Início` é renderizada, **Then** o sistema exibe:
   - **Hero Card escuro (`#0F172A`)**: Saldo Disponível (com toggle `Ocultar`), badge de evolução (`+12,4% vs. mês anterior`), Renda Mensal e Despesas do Mês.
   - **Resumo do Mês**: Cards de Taxa de Poupança (`%` + meta) e Reserva de Emergência (`R$` + meses cobertos) com botão `Ver tudo`.
   - **Card Burn Rate Mensal**: Velocidade (`R$/dia`), Projeção de Fim de Mês (`R$`), banner de alerta amarelo de redução diária e gráfico `fl_chart` comparando a linha verde de gasto acumulado com a linha pontilhada vermelha de `Teto mensal`.
   - **Card Últimas Transações & Insights**: Banner de insight dinâmico da IA seguido pelas últimas movimentações com status `Sincronizado` ou `Pendente local`.
2. **Given** a navegação para a aba `Planejamento`, **When** a sub-aba `Orçamentos & Metas` está ativa, **Then** o sistema exibe o badge `Score XX · Saudável`, o botão full-width `+ Nova Categoria / Meta` e os cards de progresso de cada categoria (`Alimentação`, `Moradia`, `Transporte`, `Lazer`, etc.) com barra colorida (verde quando confortável, laranja/vermelho próximo ao limite) e botão `Editar teto`.
3. **Given** a navegação para a aba `Mais`, **When** a tela é renderizada, **Then** exibe o perfil local (`Conta local ativa`), o card `Status Offline-First (SQLite Local)` indicando a integridade do banco e a contagem exata de transações pendentes de sincronia com botão `Sincronizar agora`, além das `Configurações financeiras` (Renda Base Mensal, Meta de Taxa de Poupança, Gerenciar Categorias e Exportar Relatório CSV).

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
- **FR-005**: O sistema DEVE fornecer o modal **`NOVO LANÇAMENTO / Adicionar transação`** acionado pelo botão verde central (`+`), contendo:
  - Bloco superior de **Entrada Inteligente**: campo de texto *"Ex: 'Almoço 45,90 no débito'..."* com botão cinza **`Preencher com IA`** e botão **`OCR`** com ícone de câmera (ao acionar, a IA preenche automaticamente os campos abaixo).
  - Seletor de tipo de transação: abas **`Despesa`** e **`Receita`**.
  - Campo de valor monetário em destaque (**`Valor R$ 0,00`**).
  - Campo de texto **`Descrição / Nome da transação`**.
  - Chips selecionáveis de **`Categoria`** (`Alimentação`, `Moradia`, `Transporte`, `Lazer`, `Saúde`) com botão **`+ Nova Categoria`**.
  - Seletor de **`Data`** com ícone de calendário.
  - Botão largo inferior verde **`Confirmar e Salvar`**.
- **FR-006**: O botão flutuante escuro (**`G✨`**) DEVE abrir o assistente conversacional do Agente de IA (**GastoSync Chat / Dúvidas & Análises Financeiras**), destinado a tirar dúvidas do usuário, sugerir estratégias de economia e avaliar o orçamento mensal, operando de forma integrada ao endpoint `/chatbot` do backend.
- **FR-007**: O sistema DEVE armazenar os insights e recomendações preditivas retornados pelo agente na tabela local `LocalAgentInsights`.
- **FR-008**: O sistema DEVE armazenar as métricas consolidadas na tabela `LocalMetrics` para histórico e performance de consultas offline.
- **FR-009**: O sistema DEVE sanitizar e validar campos obrigatórios (valor > 0, descrição não vazia, data válida).
- **FR-010**: O sistema DEVE renderizar os gráficos financeiros utilizando a biblioteca `fl_chart`, incluindo o gráfico de evolução diária de Burn Rate vs. Teto Mensal na aba `Início`.
- **FR-011**: O sistema DEVE garantir que nenhuma chave de API secreta (ex: Groq API Key) seja armazenada ou exposta no código-fonte do cliente Flutter.
- **FR-012**: O sistema DEVE apresentar o Cabeçalho Global Escuro (`#0F172A`) com mini-logo verde `G` + `GastoSync` na linha superior, saudação personalizada com o nome real do usuário autenticado/cadastrado localmente (`Olá, {Nome do Usuário}`) na linha principal, botão de notificações com indicador e avatar com as iniciais do usuário.
- **FR-013**: O sistema DEVE implementar navegação adaptativa conforme o viewport:
  - **Mobile (`< 600dp`)**: Barra de navegação inferior com 4 abas (`Início`, `Transações`, `Planejamento`, `Mais`), botão central verde (`+`) para lançamento manual rápido e botão flutuante escuro (`G✨`) para acionar o assistente de IA.
  - **Web / Desktop (`>= 800dp`)**: Barra lateral esquerda escura (`#0F172A`) contendo logo `G` + `GastoSync`, botão verde largo `+ Nova Transação`, as 4 abas de navegação, card inferior `Modo Offline-First · Sincronizado` e rodapé do usuário (`{Iniciais} · {Nome Completo} · Conta pessoal`), acompanhada de barra superior clara com badge `Local sincronizado`, sino de notificações e avatar com iniciais, e no Dashboard Web layout em 2 colunas (Hero Card à esquerda + Grid 2x2 `Resumo do Mês` com `Taxa de Poupança`, `Reserva de Emergência`, `Comprometimento` e `Score Financeiro` à direita; gráfico `Burn Rate` à esquerda inferior + `Últimas Transações & Insights` à direita inferior).
- **FR-014**: A tela de `Transações` DEVE exibir contador de sincronizadas no topo (`5 sincronizadas`), barra de busca por texto (`Pesquisar transações, categorias...`), chips de categoria sem scrollbar visível (`Todos`, `Alimentação`, `Moradia`, `Transporte`, `Lazer`, `Saúde`, `Renda`) e listagem com ícones temáticos e status (`Sincronizado` em verde vs `Pendente local` em laranja).

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
