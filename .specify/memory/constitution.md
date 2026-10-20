# GastoSync Constitution

<!--
Sync Impact Report:
- Version change: initial template -> v1.0.0
- Added sections: Core Principles (Offline-First, Separação de Responsabilidades, Human-in-the-Loop, Reatividade e Métricas, Design Adaptativo, Testabilidade), Restrições Técnicas & Segurança, Governança
- Ratification: 2026-10-20
-->

## Core Principles

### I. Offline-First Incondicional (NON-NEGOTIABLE)
O aplicativo Flutter (`gastosync_app`) DEVE operar de forma 100% autônoma e reativa localmente através do banco SQLite gerenciado pelo Drift. Inserções de receitas/despesas, consultas e recálculo de métricas essenciais DEVEM ser executados sem qualquer dependência de conectividade de rede. Conexões de rede são estritamente assíncronas e tratadas como aprimoramento progressivo.

### II. Separação Estrita de Responsabilidades & Backend Caixa-Preta
O repositório é estruturado em monorepo com fronteiras bem definidas:
- `gastosync_app`: Responsabilidade primária do cliente. Gerencia ciclo de vida, navegação adaptativa, gerenciamento de estado (Riverpod), cache e persistência reativa (Drift).
- `gastosync_agent`: Backend Python (FastAPI/Groq) mantido por desenvolvedor externo. O aplicativo consome esse serviço estritamente como caixa-preta via contratos REST/JSON bem definidos com cliente Dio, sem acoplamento de código-fonte interno do agente.

### III. Human-in-the-Loop Obrigatório
Toda resposta ou insight preditivo gerado por modelos de inteligência artificial (Llama 3.3 70B via Groq) — incluindo categorização automática de descrições vagas e extração de comprovantes por OCR — DEVE passar por um modal de confirmação do usuário (BottomSheet em telas compactas e Dialog centralizado em telas amplas). Nenhuma sugestão de IA pode ser persistida como verdade final no banco de dados sem a validação ou edição explícita do usuário.

### IV. Reatividade por Streams e 9 Métricas de Saúde Financeira
A apresentação de dados DEVE ser orientada a streams reativas providas pelo Drift e expostas via Riverpod `StreamProvider`. A interface de usuário (UI) e os gráficos (`fl_chart`) NUNCA devem exigir atualização manual de tela (`pull-to-refresh` ou recarregamento). Os algoritmos de negócio calculam continuamente as 9 métricas canônicas:
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
- Em dispositivos móveis / telas compactas (< 600dp): layout em coluna única, navegação inferior (`NavigationBar`), inputs e confirmações via `showModalBottomSheet`.
- Em desktop / navegador Web (≥ 800dp): dashboard multi-colunas, barra de navegação lateral (`NavigationRail`), diálogos centralizados.

### VI. Resiliência de Rede, Segurança e Privacidade
Chaves secretas de provedores de IA (Groq API Key) JAMAIS devem residir no cliente Flutter; elas são de responsabilidade exclusiva do orquestrador Python. O cliente HTTP (Dio) DEVE implementar timeouts rigorosos (máximo de 10s para inferência de texto e 20s para visão/OCR), interceptors de logging sanitizados e tratamento de fallback gracioso caso o backend esteja indisponível.

## Restrições Técnicas & Stack

- **Linguagem & Framework**: Flutter 3.x+ / Dart 3.x+.
- **Gerenciamento de Estado**: Flutter Riverpod & Riverpod Annotation.
- **Roteamento**: GoRouter com `StatefulShellRoute.indexedStack`.
- **Persistência Local**: Drift + `sqlite3_flutter_libs` (SQLite nativo no mobile e SQLite WASM/IndexedDB na Web).
- **Cliente HTTP**: Dio com interceptors para cabeçalhos seguros, timeouts e serialização Freezed / JSON Serializable.
- **Dashboard & Gráficos**: `fl_chart`.

## Governança

Esta constituição estabelece as diretrizes invioláveis de arquitetura e qualidade para o ecossistema GastoSync. Qualquer proposta de alteração em contratos ou quebra de princípios de offline-first deve passar por emenda formal nesta constituição com revisão de versão semântica (MAJOR.MINOR.PATCH).

**Version**: 1.0.0 | **Ratified**: 2026-10-20 | **Last Amended**: 2026-10-20
