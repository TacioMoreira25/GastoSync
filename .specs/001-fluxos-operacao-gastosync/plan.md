# Implementation Plan: Arquitetura Técnica e Contratos dos Fluxos de Operação GastoSync

**Branch**: `001-fluxos-operacao-gastosync` | **Date**: 2026-10-20 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification de [spec.md](./spec.md) integrando o Fluxo A (Offline-First via Drift Streams) e Fluxo B (Agente Preditivo com Backend Python/Groq e Modal Human-in-the-Loop).

## Summary

O GastoSync é implementado em monorepo com duas frentes isoladas:
1. **Cliente Multiplataforma (`gastosync_app`)**: Desenvolvido em Flutter, gerencia ciclo de vida, rotas adaptativas (`GoRouter`), gerenciamento de estado reativo (`Riverpod`) e persistência 100% local e offline-first (`Drift` sobre SQLite).
2. **Orquestrador de IA (`gastosync_agent`)**: Backend Python (FastAPI) mantido externamente, responsável por autenticação de segredos com Groq Cloud API, sanitização contra Prompt Injection e execução de LLM (Llama 3.3 70B). É consumido pelo app como caixa-preta via cliente HTTP `Dio`.

## Technical Context

**Language/Version**: Dart 3.x+ / Flutter 3.x+ (Client) | Python 3.11+ (Agent Backend)

**Primary Dependencies**:
- Client: `flutter_riverpod`, `riverpod_annotation`, `drift`, `sqlite3_flutter_libs`, `dio`, `go_router`, `fl_chart`, `freezed_annotation`, `json_annotation`, `intl`
- Agent Backend (Black-box): `fastapi`, `groq`, `pydantic`, `uvicorn`

**Storage**: SQLite Local via Drift (`LocalTransactions`, `LocalBudgets`, `LocalMetrics`, `LocalAgentInsights`) com suporte a native (Mobile) e memory/WASM (Web).

**Testing**: `flutter_test`, `drift/native` (testes de persistência em memória), mocks HTTP Dio com `mocktail`/`http_mock_adapter`.

**Target Platform**: Android, iOS, Web (navegadores modernos via Vercel/Firebase).

**Performance Goals**:
- Escrita local e emissão de stream no Drift < 100ms.
- Renderização inicial do Dashboard < 300ms.
- Timeout de requisições de texto à IA: 10s; OCR de comprovantes: 20s.

**Constraints**:
- Princípio Offline-First incondicional: Nenhuma falha de rede pode interromper o registro ou visualização de métricas locais.
- Chaves de API do Groq nunca expostas no Flutter.
- Modal Human-in-the-Loop obrigatório para validação de dados inferidos por IA.

## Constitution Check

- [x] **Offline-First Incondicional**: Drift atua como Single Source of Truth local.
- [x] **Separação Estrita de Responsabilidades**: App consome o backend estritamente via contratos REST/JSON.
- [x] **Human-in-the-Loop**: Sugestões preditivas e OCR passam por BottomSheet/Dialog de confirmação.
- [x] **Reatividade por Streams**: Riverpod `StreamProvider` consome queries do Drift.
- [x] **9 Métricas Canônicas**: Fórmulas matemáticas implementadas localmente em domínio Flutter.
- [x] **Design Adaptativo**: Shell adaptativo (`NavigationBar` vs `NavigationRail`).

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

## REST API Contracts (`gastosync_agent`)

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

