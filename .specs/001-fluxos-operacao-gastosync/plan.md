# Implementation Plan: Arquitetura Técnica e Contratos dos Fluxos de Operação GastoSync

**Branch**: `001-fluxos-operacao-gastosync` | **Date**: 2026-10-20 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification de [spec.md](./spec.md) integrando o Fluxo A (Offline-First via Drift Streams) e Fluxo B (Agente Preditivo com Backend Python/Groq e Modal Human-in-the-Loop).

## Summary

O GastoSync é implementado em monorepo com três camadas bem delimitadas:
1. **Cliente Multiplataforma (`gastosync_app`)**: Desenvolvido em Flutter, gerencia ciclo de vida, rotas adaptativas (`GoRouter`), gerenciamento de estado reativo (`Riverpod`), persistência 100% local e offline-first no Mobile (`Drift` sobre SQLite nativo) e operação online autenticada via API REST no Web.
2. **Backend Core & Sync (`gastosync_api`)**: Microsserviço em **Go (Golang)** com **Fiber v2** e **pgx/v5**, containerizado via Docker multi-stage. Gerencia autenticação JWT com senhas em Bcrypt, controle de usuários e sincronização bidirecional ultra rápida com o banco de dados **PostgreSQL (Neon)**.
3. **Orquestrador de IA Satélite (`gastosync_agent`)**: Backend Python (FastAPI) mantido externamente, responsável por autenticação de segredos com Groq Cloud API, sanitização contra Prompt Injection e execução de LLM (Llama 3.3 70B). É consumido pelo app como caixa-preta via cliente HTTP `Dio`, de modo que falhas na IA nunca bloqueiam o fluxo financeiro.

## Technical Context

**Language/Version**: Dart 3.x+ / Flutter 3.x+ (Client) | **Go 1.23+** (Backend Core `gastosync_api`) | Python 3.11+ (Agent `gastosync_agent`)

**Primary Dependencies**:
- Client (`gastosync_app`): `flutter_riverpod`, `riverpod_annotation`, `drift`, `sqlite3_flutter_libs`, `dio`, `go_router`, `fl_chart`, `freezed_annotation`, `json_annotation`, `intl`, `flutter_secure_storage`
- Backend Core (`gastosync_api` - Go): `github.com/gofiber/fiber/v2`, `github.com/jackc/pgx/v5/pgxpool`, `golang.org/x/crypto/bcrypt`, `github.com/golang-jwt/jwt/v5`, `github.com/joho/godotenv`
- Agent Backend (`gastosync_agent` - Python): `fastapi`, `uvicorn`, `pydantic`, `groq`

**Storage & Hosting Topology (100% Gratuito & Seguro)**:
- **Mobile Local Storage**: SQLite Local via Drift (`LocalTransactions`, `LocalBudgets`, `LocalMetrics`, `LocalAgentInsights`) nativo via FFI.
- **Web Client Hosting**: **Cloudflare Pages** (Banda ilimitada, proteção DDoS corporativa, CDN global).
- **Backend Core Hosting (`gastosync_api`)**: **Render.com** via Docker multi-stage (~10 MB de consumo de RAM).
- **Agent IA Hosting (`gastosync_agent`)**: **Render.com** (Web Service Python separado).
- **Cloud Database**: **Neon Serverless Postgres** (1 GB permanente, SSL/TLS obrigatório, scale-to-zero).

**Testing**: `flutter_test`, `drift/native` (testes de persistência em memória), mocks HTTP Dio, `go test ./...` para `gastosync_api`.

**Target Platform**: Android, iOS, Web.

**Performance Goals**:
- Escrita local e emissão de stream no Drift (Mobile) < 100ms.
- Renderização inicial do Dashboard < 300ms.
- Autenticação e sincronia REST < 1.5s.
- Timeout de requisições de texto à IA: 10s; OCR de comprovantes: 20s.

**Constraints & Security Rules**:
- **Princípio Offline-First no Mobile**: Nenhuma falha de rede pode interromper o registro ou visualização de métricas locais no celular.
- **Web Online Direto**: A versão Web opera online conectada via JWT diretamente à API REST; sem internet a aplicação Web não roda, evitando complexidades desnecessárias de Wasm/IndexedDB.
- **Isolamento de Falhas**: Falhas na IA não impactam autenticação, cadastro e leitura de dados financeiros.
- **Segurança de Dados**: O banco Postgres (Neon) NUNCA é exposto diretamente ao cliente; o acesso ocorre unicamente através da API com validação estrita do `user_id` no JWT.
- **Senhas Seguras**: Senhas criptografadas com hash Bcrypt.
- **Modal Human-in-the-Loop**: Obrigatório para validação de dados inferidos por IA antes de gravar.

## Constitution Check

- [x] **Offline-First Incondicional**: Drift atua como Single Source of Truth local.
- [x] **Separação Estrita de Responsabilidades**: App consome o backend estritamente via contratos REST/JSON.
- [x] **Human-in-the-Loop**: Sugestões preditivas e OCR passam por BottomSheet/Dialog de confirmação.
- [x] **Reatividade por Streams**: Riverpod `StreamProvider` consome queries do Drift.
- [x] **9 Métricas Canônicas**: Fórmulas matemáticas implementadas localmente em domínio Flutter.
- [x] **Design Adaptativo & Fidelidade ao Protótipo v2**: Shell adaptativo com Header escuro (`#0F172A`), 4 abas (`Início`, `Transações`, `Planejamento`, `Mais`), FAB central verde (`+`) e FAB flutuante da IA (`G✨`).

## Especificação Visual do Protótipo v2 (Design System)

- **Paleta de Cores**:
  - **Navy Escuro (Header, Hero Card e FAB IA)**: `#0F172A`
  - **Verde Esmeralda Primário (Destaques, Botão `+`, Barras Saudáveis, Receitas)**: `#10B981` / `#059669`
  - **Verde Claro Suave (Badges `Sincronizadas`, `Score Saudável`, Botão `+ Nova Categoria / Meta`)**: Fundo `#D1FAE5` / `#ECFDF5` com texto `#047857`
  - **Alerta / Limite Próximo (Barra Moradia 93%, Lazer 81%, Banner Burn Rate, `Pendente local`)**: `#D97706` / `#F59E0B` (fundo do banner `#FEF3C7` com borda `#FCD34D`)
  - **Fundo Geral das Telas**: `#F8FAFC` e Cards brancos `#FFFFFF` com borda sutil `#E2E8F0`.
- **Estrutura de Navegação (`GoRouter` - Mobile & Web/Desktop)**:
  - **Shell Mobile (`< 600dp`)**: Header superior escuro (`#0F172A`) + Barra inferior com 4 abas (`Início`, `Transações`, `Planejamento`, `Mais`) + FAB central verde (`+`) + FAB flutuante escuro (`G✨`).
  - **Shell Web / Desktop (`>= 800dp`)**:
    - **Sidebar Esquerda Fixa (`#0F172A`, largura ~250px)**: Logo `G` + `GastoSync`, botão verde `+ Nova Transação`, itens de navegação (`Início`, `Transações`, `Planejamento`, `Mais`), card inferior `Modo Offline-First / Sincronizado` e perfil dinâmico com iniciais e nome do usuário (`{Iniciais} · {Nome} · Conta pessoal`).
    - **Top Bar Web Clara**: Badge verde `Local sincronizado`, ícone de sino com indicador vermelho e avatar dinâmico com as iniciais do usuário.
    - **Grid Web da Tela 1 (`Início`)**:
      - Linha superior: Hero Card escuro `SALDO DISPONÍVEL` (esquerda) + Grid 2x2 `Resumo do Mês` contendo os 4 cards (`Taxa de Poupança`, `Reserva de Emergência`, `Comprometimento` e `Score Financeiro 84/100`) (direita), além de seletor de período (`Outubro 2024`).
      - Linha inferior: Card `Burn Rate — Outubro` com gráfico de linha vs. Teto Mensal (esquerda, flex 3) + Card `Últimas Transações & Insights` (direita, flex 2).
  1. `/dashboard` (**Início**): Hero Card de Saldo Disponível + Resumo do Mês + Burn Rate Diário com gráfico de linha vs. Teto Mensal + Últimas Transações & Insights.
  2. `/transactions` (**Transações**): Header `MOVIMENTAÇÕES` com badge `X sincronizadas`, campo de busca textual, chips horizontais sem scrollbar (`Todos`, `Alimentação`, `Moradia`, `Transporte`, `Lazer`, `Saúde`, `Renda`) e lista de transações com ícones por categoria.
  3. `/planning` (**Planejamento**): Header `PLANEJAMENTO` com badge `Score XX · Saudável`, Segmented Control (`Orçamentos & Metas` | `Saúde Financeira`), botão full-width `+ Nova Categoria / Meta` e cards de progresso por categoria consumindo `LocalBudgets` + despesas do mês.
  4. `/more` (**Mais**): Header `CONTA`, card de perfil (`Marcos Pereira` + badge `Conta local ativa`), card `Status Offline-First (SQLite Local)` com contagem real de `isSynced == false` e botão `Sincronizar agora`, e lista `Configurações financeiras`.
- **Ações Globais**:
  - **Botão Central Verde (`+`)**: Abre o modal unificado **`Adicionar transação`** com bloco de **Entrada Inteligente** (*"Ex: 'Almoço 45,90 no débito'..."* + botões **`Preencher com IA`** e **`OCR`**), abas Despesa/Receita, Valor, Descrição, chips de Categoria (`+ Nova Categoria`), Data e botão **`Confirmar e Salvar`**.
  - **Botão Flutuante Escuro (`G✨`)**: Abre o assistente conversacional do Agente de IA (**GastoSync Chat / Dúvidas & Análises Financeiras**), destinado a responder dúvidas de orçamento, comportamento de gastos e dicas financeiras personalizadas conectando à rota do agente.

## Architecture & Data Flow

```text
┌────────────────────────────────────────────────────────────────────────┐
│                   1. CAMADA CLIENTE (FLUTTER)                          │
│                                                                        │
│   Dispositivo Mobile (Android/iOS)      Navegador Web (Desktop)        │
│                │                                    │                  │
│                └──────────────────┬─────────────────┘                  │
│                                   ▼                                    │
│                    Presentation & UI Layer                             │
│               (Riverpod State Management & GoRouter)                   │
│                       │                       │                        │
│         Fluxo A       │                       │ Fluxo B                │
│    (100% Local Drift) │                       │ (Dio REST Client)      │
│                       ▼                       ▼                        │
│           ┌──────────────────────┐   ┌──────────────────────┐          │
│           │ Banco SQLite (Drift) │   │     Cliente Dio      │          │
│           │ • Transactions       │   │ • Timeout 10s/20s    │          │
│           │ • Budgets / Metrics  │   │ • Tráfego HTTPS/TLS  │          │
│           │ • Stream Queries     │   │ • Fallback Offline   │          │
│           └──────────┬───────────┘   └──────────┬───────────┘          │
└──────────────────────┼──────────────────────────┼──────────────────────┘
                       │                          │
              Stream   │                          │ Requisicão
              Events   ▼                          ▼ REST JSON
     ┌────────────────────────────┐    ┌─────────────────────────────────┐
     │ PAINEL REATIVO DA UI       │    │ 2. BACKEND ORQUESTRADOR         │
     │ • Dashboard & 9 Métricas   │    │    (PYTHON / FASTAPI)           │
     │ • Gráficos via fl_chart    │    │ • Sanitização Prompt Injection  │
     │ • Modal Human-in-the-Loop  │    │ • Gestão segura de Groq API Key │
     └────────────────────────────┘    └────────────────┬────────────────┘
                                                        │ Groq SDK
                                                        ▼
                                       ┌─────────────────────────────────┐
                                       │ 3. PROVEDOR DE IA (GROQ CLOUD)  │
                                       │ • Llama 3.3 70B em LPU          │
                                       └─────────────────────────────────┘
```

## Database Schema (Drift)

```dart
// 1. Transações Financeiras
class LocalTransactions extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get description => text().withLength(min: 1, max: 255)();
  RealColumn get amount => real()();
  DateTimeColumn get date => dateTime()();
  TextColumn get type => text()(); // 'income' | 'expense'
  TextColumn get category => text()();
  BoolColumn get isSynced => boolean().withDefault(const Constant(false))();
}

// 2. Metas e Limites Orçamentários
class LocalBudgets extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get category => text()();
  RealColumn get limitAmount => real()();
  IntColumn get month => integer()();
  IntColumn get year => integer()();
}

// 3. Snapshots de Métricas Consolidadas
class LocalMetrics extends Table {
  IntColumn get id => integer().autoIncrement()();
  DateTimeColumn get calculatedAt => dateTime()();
  RealColumn get currentBalance => real()();
  RealColumn get totalIncome => real()();
  RealColumn get totalExpense => real()();
  RealColumn get savingsRate => real()();
  RealColumn get emergencyMonths => real()();
  RealColumn get incomeCommitment => real()();
  RealColumn get dailyBurnRate => real()();
  RealColumn get monthEndProjection => real()();
  RealColumn get healthScore => real()(); // 0 a 100
}

// 4. Histórico de Insights do Agente de IA
class LocalAgentInsights extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get transactionId => integer().nullable()();
  TextColumn get rawSuggestion => text()();
  RealColumn get confidenceScore => real()();
  TextColumn get categorySuggested => text()();
  TextColumn get budgetTip => text()();
  DateTimeColumn get createdAt => dateTime()();
}
```

## Algoritmos das 9 Métricas de Saúde Financeira

1. **Saldo Líquido**: $\sum(\text{Receitas}) - \sum(\text{Despesas})$.
2. **Receita Mensal Total**: $\sum(\text{Receitas do Mês Vigente})$.
3. **Despesa Mensal Total**: $\sum(\text{Despesas do Mês Vigente})$.
4. **Taxa de Poupança (%)**: $(\text{Receita Mensal} - \text{Despesa Mensal}) / \text{Receita Mensal} \times 100$.
5. **Reserva de Emergência em Meses**: $\text{Saldo Líquido Acumulado} / \text{Média Mensal de Despesas (últimos 3 meses)}$.
6. **Comprometimento da Renda (%)**: $\text{Despesa Mensal} / \text{Receita Mensal} \times 100$.
7. **Burn Rate Diário**: $\text{Despesa Total do Mês} / \text{Dias Transcorridos do Mês Atual}$.
8. **Projeção de Fim de Mês**: $\text{Despesa Atual} + (\text{Burn Rate Diário} \times \text{Dias Restantes do Mês})$.
9. **Score de Saúde Financeira (0-100)**: Fórmula ponderada local:
   $$\text{Score} = (\text{Poupança} \times 0.3) + (\min(\text{Reserva em Meses} / 6, 1) \times 35) + ((1 - \min(\text{Comprometimento}, 1)) \times 35)$$

## REST API Contracts (`gastosync_api` — Go Core API)

### 1. Registro de Usuário (`POST /api/v1/auth/register`)
- **Request Payload**:
  ```json
  {
    "name": "Marcos Paulo",
    "email": "marcos@exemplo.com",
    "password": "SenhaForte123!"
  }
  ```
- **Response Payload (201 Created)**:
  ```json
  {
    "token": "eyJhbGciOiJIUzI1NiIs...",
    "user": {
      "id": "uuid-gerado",
      "name": "Marcos Paulo",
      "email": "marcos@exemplo.com"
    }
  }
  ```

### 2. Autenticação / Login (`POST /api/v1/auth/login`)
- **Request Payload**:
  ```json
  {
    "email": "marcos@exemplo.com",
    "password": "SenhaForte123!"
  }
  ```
- **Response Payload (200 OK)**:
  ```json
  {
    "token": "eyJhbGciOiJIUzI1NiIs...",
    "user": {
      "id": "uuid-gerado",
      "name": "Marcos Paulo",
      "email": "marcos@exemplo.com"
    }
  }
  ```

### 3. Sincronização Push (`POST /api/v1/sync/push`)
- **Headers**: `Authorization: Bearer <JWT_TOKEN>`
- **Request Payload**: Lista de transações e orçamentos locais pendentes (`isSynced == false`).
- **Response Payload (200 OK)**: Confirmação dos IDs sincronizados no Neon Postgres.

### 4. Sincronização Pull & Listagem (`GET /api/v1/sync/pull`)
- **Headers**: `Authorization: Bearer <JWT_TOKEN>`
- **Response Payload (200 OK)**: Transações e limites de orçamento do usuário autenticado (`user_id` extraído exclusivamente do JWT).

---

## REST API Contracts (`gastosync_agent` — Python IA Satélite)

### 1. Categorização e Previsão de Despesa Vaga
- **Rota**: `POST /api/v1/predict/categorize`
- **Headers**: `Content-Type: application/json`
- **Request Payload**:
  ```json
  {
    "description": "almoco com equipe no habibs 85",
    "amount": 85.0,
    "user_id": "optional-uuid"
  }
  ```
- **Response Payload (200 OK)**:
  ```json
  {
    "category": "Alimentação",
    "confidence": 0.94,
    "normalized_description": "Almoço com equipe no Habib's",
    "estimated_amount": 85.0,
    "budget_tip": "Seus gastos com refeições fora de casa atingiram 72% do teto mensal previsto."
  }
  ```

### 2. Extração de Comprovante (OCR / Visão)
- **Rota**: `POST /api/v1/predict/ocr`
- **Headers**: `Content-Type: multipart/form-data`
- **Request Form**: `image` (binary, jpeg/png)
- **Response Payload (200 OK)**:
  ```json
  {
    "merchant": "Posto Ipiranga",
    "amount": 220.50,
    "date": "2026-10-20T14:32:00Z",
    "category": "Transporte",
    "confidence": 0.89,
    "budget_tip": "Combustível está alinhado com o seu histórico quinzenal."
  }
  ```

### 3. Análise Orçamentária e Burn Rate
- **Rota**: `GET /api/v1/agent/budget-burn-rate?month=10&year=2026`
- **Response Payload (200 OK)**:
  ```json
  {
    "status": "warning",
    "burn_rate_status": "acima_da_media",
    "recommendation": "Reduza despesas variáveis nos próximos 11 dias para atingir a meta de poupança de 20%."
  }
  ```

## Estratégia de Fallback e Resiliência HTTP

```dart
try {
  final response = await dioClient.post('/predict/categorize', data: payload);
  final suggestion = AgentPredictionResponse.fromJson(response.data);
  // Abre Modal Human-in-the-Loop com dados sugeridos pela IA
  await _showHumanInTheLoopModal(context, suggestion);
} on DioException catch (e) {
  // Tratamento gracioso sem bloqueio da UI
  final reason = e.type == DioExceptionType.connectionTimeout
      ? 'Tempo limite excedido na resposta da IA.'
      : 'Sem conexão com o assistente preditivo.';
  _showFallbackManualModal(context, reason);
}
```

