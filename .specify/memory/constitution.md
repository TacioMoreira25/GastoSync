# GastoSync Constitution

<!--
Sync Impact Report:
- Version change: v1.0.0 -> v1.1.0
- Modified principles:
  - II. Separação Estrita de Responsabilidades & Microsserviço de Backend Unificado (Auth/Sync + Agente IA)
  - V. Design Adaptativo Multiplataforma (Diferenciação Web Online vs. Mobile Offline-First)
  - VI. Resiliência de Rede, Segurança, Autenticação e Privacidade
- Added sections:
  - Arquitetura de Hospedagem & Topologia em Nuvem (Cloudflare Pages, Render, Neon Postgres)
- Ratification: 2026-10-20 | Last Amended: 2026-10-28
-->

## Core Principles

### I. Offline-First Incondicional no Mobile & Web Online Direta (NON-NEGOTIABLE)
- **Mobile (Android/iOS)**: O aplicativo Flutter (`gastosync_app`) DEVE operar de forma 100% autônoma e reativa localmente através do banco SQLite gerenciado pelo Drift. Inserções de receitas/despesas, consultas e recálculo de métricas essenciais DEVEM ser executados sem qualquer dependência de conectividade de rede. Sincronizações com a nuvem ocorrem de forma assíncrona quando houver sinal.
- **Web (Navegador)**: A versão Web opera como serviço online conectado diretamente à API REST com autenticação JWT. Sem conectividade de rede, a aplicação Web não inicializa dados fictícios nem força SQLite complexo via Wasm.

### II. Separação de Microsserviços & Isolamento de Falhas
O ecossistema é dividido em três camadas bem isoladas:
1. `gastosync_app`: Cliente Flutter multiplataforma (Mobile Offline-First e Web Online responsivo).
2. `gastosync_api` (Backend Core em Go): Microsserviço compilado em **Go (Golang)** com **Fiber/Gin** e driver **pgx/v5**, containerizado via Docker multi-stage. Responsável por autenticação (JWT/Bcrypt), persistência segura de usuários e sincronização bidirecional de alta performance com o **Neon Postgres**.
3. `gastosync_agent` (Serviço de IA Satélite em Python): Módulo mantido externamente para orquestração de prompts Groq (Llama 3.3) e OCR. Erros ou indisponibilidades no agente de IA NUNCA devem impedir o login, o cadastro manual de despesas ou a visualização de métricas financeiras.

### III. Human-in-the-Loop Obrigatório
Toda resposta ou insight preditivo gerado por modelos de inteligência artificial (Llama 3.3 70B via Groq) — incluindo categorização automática de descrições vagas e extração de comprovantes por OCR — DEVE passar por um modal de confirmação do usuário (BottomSheet em telas compactas e Dialog centralizado em telas amplas). Nenhuma sugestão de IA pode ser persistida como verdade final no banco de dados sem a validação ou edição explícita do usuário.

### IV. Reatividade por Streams e 9 Métricas de Saúde Financeira
A apresentação de dados no cliente DEVE ser orientada a streams reativas providas pelo Drift (no Mobile) e expostas via Riverpod `StreamProvider`. A interface de usuário (UI) e os gráficos (`fl_chart`) NUNCA devem exigir atualização manual de tela (`pull-to-refresh` ou recarregamento). Os algoritmos de negócio calculam continuamente as 9 métricas canônicas:
1. Saldo Líquido
2. Receita Mensal Total
3. Despesa Mensal Total
4. Taxa de Poupança (%)
5. Reserva de Emergência em Meses
6. Comprometimento da Renda (%)
7. Burn Rate Diário
8. Projeção de Fim de Mês
9. Score de Saúde Financeira (0-100)

### V. Design Adaptativo Multiplataforma
O design do aplicativo DEVE suportar nativamente e de maneira fluida as plataformas Web e Mobile (Android/iOS):
- Em dispositivos móveis / telas compactas (< 600dp): layout em coluna única, navegação inferior (`NavigationBar`), botão central verde (`+`), inputs e confirmações via `showModalBottomSheet`.
- Em desktop / navegador Web (≥ 800dp): barra lateral esquerda fixa escura (`#0F172A`, largura 250px) contendo logo, perfil e navegação, barra superior com status de sincronia e dashboard em grid de 2 colunas.

### VI. Resiliência de Rede, Segurança, Autenticação e Privacidade
- **Autenticação**: O acesso exige login seguro com e-mail e senha. As senhas DEVEM ser armazenadas exclusivamente como hash unidirecional (Bcrypt) no banco PostgreSQL.
- **Sessão**: O cliente autentica via Bearer Token JWT de curta/média duração.
- **Isolamento de Dados**: Toda consulta de banco DEVE ser estritamente filtrada por `user_id` derivado do token JWT validado no servidor. O cliente nunca recebe privilégio de consulta irrestrita.
- **Segurança de Segredos**: Chaves secretas (Groq API Key, credenciais de conexão do Neon Postgres, chaves de assinatura JWT) JAMAIS devem residir no cliente Flutter ou serem expostas em repositórios públicos.
- **Timeouts & Fallback**: O cliente HTTP (Dio) DEVE implementar timeouts rigorosos (10s para texto/IA e 20s para visão/OCR) e fallback amigável.

## Arquitetura de Hospedagem & Topologia em Nuvem

| Camada | Tecnologia | Plataforma de Hospedagem | Modelo de Custo |
| :--- | :--- | :--- | :--- |
| **Frontend Web** | Flutter Web (SPA compilada) | **Cloudflare Pages** | Gratuito Vitalício (Banda ilimitada, CDN global, DDoS Shield) |
| **Backend Core (`gastosync_api`)** | **Go (Golang)** + Fiber + pgx (Docker) | **Render.com** (Web Service Docker) | Gratuito Vitalício (~10MB RAM, binário estático) |
| **Serviço Satélite IA (`gastosync_agent`)** | Python (FastAPI / Groq SDK) | **Render.com** (Web Service) | Gratuito Vitalício |
| **Banco de Dados** | PostgreSQL 16+ com SSL | **Neon.tech** (Serverless Postgres) | Gratuito Vitalício (1 GB storage, scale-to-zero) |

## Restrições Técnicas & Stack

- **Linguagem & Framework**: Flutter 3.x+ / Dart 3.x+ (Client) | **Go 1.23+** (Backend Core) | Python 3.11+ (Agent IA).
- **Backend Core Libraries (Go)**: `github.com/gofiber/fiber/v2`, `github.com/jackc/pgx/v5`, `golang.org/x/crypto/bcrypt`, `github.com/golang-jwt/jwt/v5`.
- **Gerenciamento de Estado (Client)**: Flutter Riverpod & Riverpod Annotation.
- **Roteamento (Client)**: GoRouter com `StatefulShellRoute.indexedStack` e guard de autenticação.
- **Persistência Local (Mobile)**: Drift + SQLite nativo no Mobile.
- **Cliente HTTP**: Dio com interceptors para cabeçalhos de autenticação JWT, timeouts e serialização Freezed.
- **Dashboard & Gráficos**: `fl_chart`.

## Governança

Esta constituição estabelece as diretrizes invioláveis de arquitetura, segurança e qualidade para o ecossistema GastoSync. Qualquer proposta de alteração em contratos ou quebra de princípios de segurança e offline-first deve passar por emenda formal nesta constituição com revisão de versão semântica (MAJOR.MINOR.PATCH).

**Version**: 1.1.0 | **Ratified**: 2026-10-20 | **Last Amended**: 2026-10-28
