# Fibo API

## Instalação

```bash
python -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
cp .env.example .env
```

Configure `API_KEY_GROQ` em `.env`. **Substitua os dois arquivos `system_prompt*.txt` pelos seus prompts reais**: os arquivos incluídos são exemplos e não definem o domínio do Fibo. Verifique na Groq se os modelos configurados estão disponíveis e suportam o modo JSON.

## Execução

```bash
uvicorn main:app --reload
```

Acesse `http://127.0.0.1:8000/docs`.

```bash
curl -X POST http://127.0.0.1:8000/chatbot \
  -H 'Content-Type: application/json' \
  -d '{"user":"teste","prompt":"Olá","session":1}'
```

## Observações

- `session` é validado e registrado em logs, mas não implementa histórico/memória.
- `user` é um identificador fornecido pelo cliente, não autenticação.
- `chabot_response` e `erro` preservam os nomes do schema anterior.
- `erro=1` significa mensagem fora do contexto e retorna HTTP 200.
- Exceções do provedor são traduzidas em HTTP 503; entradas inválidas retornam 422.
- O fallback tenta os modelos configurados para cada etapa independentemente; não garante sucesso se a conta estiver sem cota.
- Não exponha esta API publicamente sem autenticação, limites de requisição e configuração de CORS apropriada.


## Endpoints adicionais (GastoSync)
- `POST /api/v1/predict/categorize`: JSON `{ "description": "Almoço", "amount": 25.0, "user_id": "123" }` (user_id é recebido, mas não autentica o usuário).
- `POST /api/v1/predict/ocr`: multipart/form-data, campo `image`, formatos JPEG, PNG e WebP, limite 5 MiB.

Os dois endpoints retornam objetos JSON validados por Pydantic, sem envelope `Verification`. Configure `OCR_MODELS` com um modelo de visão disponível na sua conta Groq que aceite imagens e JSON.

Instale `python-multipart` via `pip install -r requirements.txt`. Configure `.env` a partir de `.env.example`; nunca publique credenciais. O OCR pode cometer erros: confira os dados antes de salvar transações.
