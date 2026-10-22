# GastoSync

**GastoSync** é uma plataforma multiplataforma (**Android, iOS e Web**) de gestão financeira pessoal com arquitetura **100% Offline-First** integrada a um **Agente Preditivo e Orçamentário por Inteligência Artificial**.

O projeto combina a velocidade e confiabilidade de um banco de dados reativo local (**SQLite via Drift**) com o poder analítico de LLMs executados em baixa latência (**Groq Cloud API**), mantendo o usuário sempre no controle através de validação **Human-in-the-Loop**.

---

## Principais Funcionalidades

- **Operação 100% Offline-First (Fluxo A)**:
  - Cadastro, filtragem e exclusão de receitas e despesas diretamente no SQLite local (`Drift`), funcionando mesmo em modo avião.
  - Atualização instantânea da interface e dos gráficos via *reactive streams* (`Riverpod` + `Drift`), sem necessidade de recarregar a tela.
- **Agente Preditivo & Human-in-the-Loop (Fluxo B)**:
  - **Entrada em Linguagem Natural**: Digite frases rápidas como *"almoço com equipe no habibs 85"* ou *"uber 22 reais"* e receba categorização automática, valor extraído, nível de confiança e dica orçamentária.
  - **Leitura de Comprovantes via OCR/Visão**: Envie fotos de cupons fiscais e recibos para extração automática de estabelecimento, data, valor e categoria.
  - **Revisão Obrigatória (Human-in-the-Loop)**: Nenhuma sugestão da IA é salva às cegas; um modal adaptativo (`BottomSheet` no mobile / `Dialog` na Web) permite revisar e editar qualquer campo antes de gravar no banco local.
  - **Fallback Gracioso**: Caso o dispositivo esteja sem internet ou o backend exceda o tempo limite (10s texto / 20s OCR), o app realiza pré-processamento local e abre o modal de confirmação sem travar o fluxo do usuário.
- **Painel Analítico com as 9 Métricas de Saúde Financeira**:
  1. **Saldo Líquido Acumulado**
  2. **Receita Mensal Total**
  3. **Despesa Mensal Total**
  4. **Taxa de Poupança (%)**
  5. **Reserva de Emergência (em meses)**
  6. **Comprometimento da Renda (%)**
  7. **Burn Rate Diário (velocidade de gastos)**
  8. **Projeção de Fim de Mês**
  9. **Score de Saúde Financeira (0 a 100)**
- **Design Adaptativo Multiplataforma (Material 3)**:
  - **Mobile (`< 600dp`)**: Layout em coluna única, navegação inferior (`NavigationBar`) e modais em `BottomSheet`.
  - **Web / Desktop (`>= 800dp`)**: Grade multi-colunas, barra lateral (`NavigationRail`) e modais centralizados (`Dialog`).

---

## Arquitetura do Monorepo

```text
gasto-sync/
├── .agents/skills/    # Skills do Spec Kit configuradas para execução controlada
├── .specify/          # Constituição arquitetural e scripts de governança (SDD)
├── .specs/            # Especificações de features, plano técnico e tasks
│   └── 001-fluxos-operacao-gastosync/
│       ├── spec.md    # Cenários de uso, requisitos funcionais e critérios de aceite
│       ├── plan.md    # Arquitetura, schema Drift, fórmulas e contratos REST
│       └── tasks.md   # Plano de execução passo a passo por User Story
├── gastosync_app/     # Cliente Flutter Multiplataforma (Android, iOS, Web)
└── gastosync_agent/   # Backend Python (FastAPI + Groq SDK) para orquestração de IA
```

---

## Stack Tecnológica

### 1. Cliente Multiplataforma (`gastosync_app`)
| Camada | Tecnologia | Papel no Projeto |
| :--- | :--- | :--- |
| **Framework & UI** | Flutter 3.x / Material 3 | Interface adaptativa com suporte a Light/Dark Mode |
| **Gerência de Estado** | Flutter Riverpod | Injeção de dependências e consumo reativo de `StreamProvider` |
| **Navegação** | GoRouter | Roteamento declarativo com `StatefulShellRoute.indexedStack` |
| **Persistência Local** | Drift (SQLite) | Single Source of Truth local (`LocalTransactions`, `LocalBudgets`, `LocalMetrics`, `LocalAgentInsights`) |
| **Visualização de Dados** | fl_chart | Gráficos interativos de fluxo de caixa (Receitas vs. Despesas dos últimos 6 meses) |
| **Rede & Resiliência** | Dio | Cliente HTTP com interceptors sanitizados, timeouts estritos e fallback offline |

### 2. Backend Orquestrador de IA (`gastosync_agent`)
| Camada | Tecnologia | Papel no Projeto |
| :--- | :--- | :--- |
| **API REST** | Python 3.11+ / FastAPI | Exposição dos endpoints preditivos e validação via Pydantic |
| **Segurança** | Guardrail Classifier | Filtragem de contexto e proteção contra *Prompt Injection* |
| **Inferência LLM** | Groq Cloud SDK (LPU) | Categorização textual, extração de comprovantes (OCR) e análise de *Burn Rate* |

---

## Como Executar o Projeto

### Pré-requisitos
- **Flutter SDK** `^3.13.0`
- **Python** `3.11+`
- Uma chave de API da [Groq Cloud](https://console.groq.com/) (apenas para o backend `gastosync_agent`)

### 1. Rodando o Backend de IA (`gastosync_agent`)

```bash
cd gastosync_agent

# Crie e ative o ambiente virtual
python -m venv .venv
source .venv/bin/activate  # No Windows: .venv\Scripts\activate

# Instale as dependências
pip install -r requiriments.txt

# Configure as variáveis de ambiente
cp .env.example .env
# Edite o arquivo .env e insira sua API_KEY_GROQ

# Inicie o servidor FastAPI na porta 8000
uvicorn main:app --reload --port 8000
```
A documentação interativa (Swagger UI) ficará disponível em `http://localhost:8000/docs`.

### 2. Rodando o Aplicativo Flutter (`gastosync_app`)

```bash
cd gastosync_app

# Instale os pacotes
flutter pub get

# Execute no navegador (Web) ou dispositivo conectado (Android/iOS)
flutter run -d chrome --dart-define=GASTOSYNC_API_URL=http://localhost:8000
```

> **Nota**: O aplicativo funciona integralmente mesmo se o backend Python não estiver rodando, acionando automaticamente o modo de contingência Offline-First.

### 3. Executando os Testes Automatizados

```bash
cd gastosync_app
flutter test
```

---

## Governança e Desenvolvimento Orientado a Especificações (SDD)

Este repositório utiliza **Spec-Driven Development (SDD)**. Antes de alterar fluxos críticos ou contratos de dados, consulte:
- **Constituição do Projeto**: [`.specify/memory/constitution.md`](.specify/memory/constitution.md)
- **Especificação Funcional**: [`.specs/001-fluxos-operacao-gastosync/spec.md`](.specs/001-fluxos-operacao-gastosync/spec.md)
- **Plano Técnico e Contratos da API**: [`.specs/001-fluxos-operacao-gastosync/plan.md`](.specs/001-fluxos-operacao-gastosync/plan.md)
- **Guia de Deploy Web (Vercel / Firebase)**: [`gastosync_app/docs/WEB_DEPLOYMENT_GUIDE.md`](gastosync_app/docs/WEB_DEPLOYMENT_GUIDE.md)
