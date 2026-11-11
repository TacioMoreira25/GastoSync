from collections import defaultdict, deque
import logging
import time
from contextlib import asynccontextmanager
from fastapi import Depends, FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from config import ENABLE_DOCS, MAX_JSON_BODY_BYTES, RATE_LIMIT_PER_MINUTE
from routes.chatbot import get_service, router as chatbot_router
from routes.predict import router as predict_router
from schemas import AgentStatusResponse
from services import ChatbotService, build_service

logging.basicConfig(level=logging.INFO, format='%(asctime)s %(levelname)s %(name)s: %(message)s')

_ip_requests: dict[str, deque[float]] = defaultdict(deque)


def _get_client_ip(request: Request) -> str:
    forwarded = request.headers.get('x-forwarded-for')
    if forwarded:
        return forwarded.split(',')[0].strip()
    return request.client.host if request.client else 'unknown'


@asynccontextmanager
async def lifespan(app: FastAPI):
    app.state.chatbot_service = build_service()
    yield


app = FastAPI(
    title='Fibo API',
    version='1.0.0',
    lifespan=lifespan,
    docs_url='/docs' if ENABLE_DOCS else None,
    redoc_url='/redoc' if ENABLE_DOCS else None,
    openapi_url='/openapi.json' if ENABLE_DOCS else None,
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=['*'],
    allow_credentials=False,
    allow_methods=['GET', 'POST', 'OPTIONS'],
    allow_headers=['*'],
)


@app.middleware('http')
async def security_and_rate_limit_middleware(request: Request, call_next):
    path = request.url.path

    # 1. Limite de tamanho para payloads JSON nas rotas de texto (evita DoS)
    if request.method == 'POST' and path in ('/api/v1/agent/chat', '/api/v1/predict/categorize'):
        content_length = request.headers.get('content-length')
        if content_length and content_length.isdigit() and int(content_length) > MAX_JSON_BODY_BYTES:
            return JSONResponse(
                status_code=413,
                content={'detail': 'Payload excede o tamanho máximo permitido (32 KB).'},
            )

    # 2. Rate Limit por IP nas rotas que consomem cota da Groq (proteção anti-bot/spam)
    if path.startswith('/api/v1/'):
        now = time.monotonic()
        client_ip = _get_client_ip(request)
        bucket = _ip_requests[client_ip]
        while bucket and now - bucket[0] > 60.0:
            bucket.popleft()
        if len(bucket) >= RATE_LIMIT_PER_MINUTE:
            return JSONResponse(
                status_code=429,
                content={'detail': 'Limite de requisições por minuto atingido. Aguarde alguns segundos.'},
                headers={'Retry-After': '60'},
            )
        bucket.append(now)

    response = await call_next(request)

    # 3. Headers de Segurança HTTP (OWASP API Security)
    response.headers['X-Content-Type-Options'] = 'nosniff'
    response.headers['X-Frame-Options'] = 'DENY'
    response.headers['Referrer-Policy'] = 'no-referrer'
    response.headers['Cache-Control'] = 'no-store'
    return response


app.include_router(chatbot_router)
app.include_router(predict_router)


@app.get('/health', tags=['Health'])
def health():
    return {'status': 'ok'}


@app.get('/api/v1/agent/status', response_model=AgentStatusResponse, tags=['Health'])
def agent_status(service: ChatbotService = Depends(get_service)) -> AgentStatusResponse:
    return service.get_status()
