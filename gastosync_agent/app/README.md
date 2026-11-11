# Fibo API — Agente de IA do GastoSync

Serviço satélite em FastAPI integrado à **Groq** para classificação de contexto, consultoria financeira conversacional (**Fibo**), categorização preditiva de gastos e leitura óptica (**OCR**) de comprovantes e boletos.

---

## 1. Instalação Rápida

```bash
cd gastosync_agent/app
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
cp .env.example .env
```

---

## 2. Como configurar a Chave e os Modelos da Groq (`.env`)

1. **Obter a `API_KEY_GROQ`**:
   - Acesse [https://console.groq.com/keys](https://console.groq.com/keys), crie uma chave gratuita (`gsk_...`) e cole em `API_KEY_GROQ` no arquivo `.env`.
2. **Escolher ou atualizar os modelos (`*_MODELS`)**:
   - Consulte a lista oficial de modelos ativos na sua conta em [https://console.groq.com/docs/models](https://console.groq.com/docs/models).
   - No `.env`, você pode informar múltiplos modelos separados por vírgula (o serviço faz fallback automático na ordem listada):
     - `CLASSIFIER_MODELS` / `FIBO_MODELS` / `CATEGORIZE_MODELS`: `openai/gpt-oss-120b,openai/gpt-oss-20b,qwen/qwen3.8-27b`
     - `OCR_MODELS`: `qwen/qwen3.8-27b` (modelo multimodal oficial de visão/OCR da Groq)
3. **Prompts do Sistema (`system_prompt*.txt`)**:
   - Os 4 arquivos (`system_prompt.txt`, `system_prompt_fibo.txt`, `system_prompt_categorize.txt` e `system_prompt_ocr.txt`) já vêm configurados em `gastosync_agent/app/` prontos para uso com os contratos do app Flutter.

---

## 3. Execução e Testes

Para subir o servidor em modo de desenvolvimento:

```bash
uvicorn main:app --reload --port 8000
```

- Documentação interativa (Swagger): `http://127.0.0.1:8000/docs`
- Healthcheck: `GET http://127.0.0.1:8000/health`

Para rodar a suíte de testes automatizados:

```bash
pytest -v
```

---

## 4. Endpoints (Alinhados 100% com o App Flutter)

### 1. Chat Financeiro do Fibo (`POST /api/v1/agent/chat`)
```bash
curl -X POST http://127.0.0.1:8000/api/v1/agent/chat \
  -H 'Content-Type: application/json' \
  -d '{"message": "Como manter meu cartão dentro de 50% a 80% do limite?"}'
```

### 2. Categorização Preditiva de Gastos (`POST /api/v1/predict/categorize`)
```bash
curl -X POST http://127.0.0.1:8000/api/v1/predict/categorize \
  -H 'Content-Type: application/json' \
  -d '{"description": "Academia SmartFit 129,90 no cartão de crédito", "amount": 129.90, "user_id": "123"}'
```

### 3. Leitura Óptica de Comprovantes e Boletos (`POST /api/v1/predict/ocr`)
- `multipart/form-data`, campo `image`, formatos JPEG, PNG ou WebP até 5 MiB:
```bash
curl -X POST http://127.0.0.1:8000/api/v1/predict/ocr \
  -F "image=@comprovante.jpg"
```
