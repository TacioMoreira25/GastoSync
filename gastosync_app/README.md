# GastoSync App (`gastosync_app`)

> Cliente multiplataforma em **Flutter** para Android e Web com arquitetura reativa e persistência Offline-First via Drift (SQLite nativo no Android e WASM/IndexedDB na Web).
>
> **Aplicação Web publicada:** [`https://gastosync.pages.dev`](https://gastosync.pages.dev)

---

## Stack Técnica

- **Framework**: Flutter 3.x / Dart 3.x
- **Gerenciamento de Estado**: `flutter_riverpod` (`StreamProvider` e `Notifier`)
- **Navegação**: `go_router` (`StatefulShellRoute` adaptativo para Mobile `< 800px` e Web Desktop `>= 800px`)
- **Persistência Local**: `drift` + `sqlite3_flutter_libs` (Mobile) e `sqlite3.wasm` + `drift_worker.js` (Web)
- **Comunicação HTTP**: `dio` conectado por padrão à API Core em produção (`https://gastosync-api.onrender.com`) e ao Agente IA (`https://gastosync-agent.onrender.com`)
- **Visualização de Dados**: `fl_chart` (9 Métricas de Saúde Financeira e curva de Burn Rate)

---

## Estrutura de Módulos (`lib/`)

```text
lib/
├── core/
│   ├── database/      # Tabelas Drift (LocalTransactions, LocalBudgets, LocalMetrics, LocalAgentInsights)
│   ├── network/       # Cliente Dio e interceptors HTTP
│   ├── router/        # Rotas GoRouter e shell de navegação responsiva (BottomBar / Sidebar)
│   ├── theme/         # Design tokens e temas Material 3 (AppTheme)
│   └── widgets/       # Cabeçalhos adaptativos e modal conversacional do assistente IA
└── features/
    ├── auth/          # Telas de Login/Cadastro e gestão de sessão JWT
    ├── budget_agent/  # Integração com a API de IA (categorização preditiva e OCR)
    ├── dashboard/     # Painel principal, 9 métricas financeiras e gráficos fl_chart
    ├── planning/      # Gestão de metas e limites orçamentários por categoria
    ├── settings/      # Perfil do usuário, status de sincronização e configurações
    └── transactions/  # Listagem, filtros e lançamento manual/inteligente de transações
```

---

## Execução e Testes

### Instalar dependências
```bash
flutter pub get
```

### Executar em modo de desenvolvimento
```bash
# Navegador Web
flutter run -d chrome
flutter run -d web-server --web-hostname=localhost --web-port=3000

# Dispositivo / Emulador Android
flutter run
```

### Executar suíte de testes
```bash
flutter test
```

### Build de Produção e Deploy Web
```bash
# APK de produção para Android
flutter build apk --release

# Bundle Web (Flutter build/web) e deploy no Cloudflare Pages
./cloudflare-build.sh
./cloudflare-deploy.sh
```
