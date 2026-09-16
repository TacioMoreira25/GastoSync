# GastoSync - Monorepo

Sistema de gestão financeira pessoal multiplataforma com agente preditivo e orçamentário por IA.

## Estrutura do Repositório

```text
gastosync/
├── gastosync_app/     # Cliente Flutter Multiplataforma (Web, Android, iOS)
└── gastosync_agent/   # Backend Python para orquestração de LLM via Groq API
```

### Tecnologias do Cliente (`gastosync_app`)
- **UI & Design**: Material Design 3 (Light/Dark Mode), Google Fonts (Inter)
- **Gerenciamento de Estado**: Flutter Riverpod & Riverpod Annotation
- **Navegação Adaptativa**: GoRouter com `StatefulShellRoute.indexedStack` (NavigationRail / NavigationBar)
- **Persistência Reativa**: Drift + sqlite3_flutter_libs (Offline-First)
- **Dashboard & Gráficos**: fl_chart
- **Serialização & Imutabilidade**: Freezed & JSON Serializable
- **Rede**: Dio (configurado com BaseOptions para comunicação REST)
