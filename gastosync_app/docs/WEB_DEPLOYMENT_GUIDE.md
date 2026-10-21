# Guia de Arquitetura Web e Deploy (Vercel / Firebase Hosting) — GastoSync

## 1. Visão Geral da Aplicação Web (`gastosync_app`)

O cliente **GastoSync** foi projetado com arquitetura **100% Offline-First e Multiplataforma** (Android, iOS e Web), mantendo paridade funcional completa entre dispositivos móveis e navegadores desktop/mobile:

- **Layout Adaptativo (Material 3)**:
  - **Mobile (`< 600dp`)**: Coluna única, barra de navegação inferior (`NavigationBar`) e confirmações Human-in-the-Loop em `ModalBottomSheet`.
  - **Tablet / Desktop / Web (`>= 800dp`)**: Grade multi-colunas para as 9 Métricas de Saúde Financeira, barra lateral (`NavigationRail` recolhida ou estendida em `>= 1200dp`) e confirmações em `Dialog` centralizado.
- **Persistência Local Reativa (Drift)**:
  - No Android/iOS, o Drift utiliza `sqlite3_flutter_libs` em arquivo nativo (`gastosync.sqlite`) executado em background isolate.
  - Na Web, o Drift opera reativamente em memória / SQLite WASM sem exigir conexão ativa com o backend para leitura, escrita ou cálculo das 9 métricas financeiras.
- **Comunicação com o Orquestrador IA (`gastosync_agent`)**:
  - Realizada exclusivamente via cliente HTTP `Dio` parametrizado por `--dart-define=GASTOSYNC_API_URL=https://api.seudominio.com`.
  - Timeouts estritos: **10 segundos** para categorização de texto (`POST /api/v1/predict/categorize`) e **20 segundos** para OCR de comprovantes (`POST /api/v1/predict/ocr`).
  - Nenhuma chave secreta (`GROQ_API_KEY`) reside no bundle Web/Mobile do Flutter (conformidade OWASP MASVS).

---

## 2. Build de Produção para Web

Na raiz do diretório `gastosync_app`, execute:

```bash
cd gastosync_app
flutter pub get
flutter build web --release --dart-define=GASTOSYNC_API_URL=https://gastosync-agent.seudominio.com
```

Os artefatos estáticos otimizados serão gerados em `gastosync_app/build/web`.

---

## 3. Deploy na Vercel

1. Crie um arquivo `vercel.json` dentro de `gastosync_app/build/web` (ou configure no painel da Vercel apontando para `gastosync_app`):

```json
{
  "rewrites": [
    { "source": "/(.*)", "destination": "/index.html" }
  ],
  "headers": [
    {
      "source": "/(.*)",
      "headers": [
        { "key": "X-Content-Type-Options", "value": "nosniff" },
        { "key": "X-Frame-Options", "value": "DENY" }
      ]
    }
  ]
}
```

2. Faça o deploy via Vercel CLI:

```bash
cd gastosync_app/build/web
npx vercel --prod
```

---

## 4. Deploy no Firebase Hosting

1. Inicialize o Firebase na pasta `gastosync_app`:

```bash
cd gastosync_app
firebase init hosting
```

2. Configure o `firebase.json` para apontar para `build/web` com suporte a Single-Page Application (SPA):

```json
{
  "hosting": {
    "public": "build/web",
    "ignore": ["firebase.json", "**/.*", "**/node_modules/**"],
    "rewrites": [
      {
        "source": "**",
        "destination": "/index.html"
      }
    ]
  }
}
```

3. Publique a versão de produção:

```bash
flutter build web --release --dart-define=GASTOSYNC_API_URL=https://gastosync-agent.seudominio.com
firebase deploy --only hosting
```
