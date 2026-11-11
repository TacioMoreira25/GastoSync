import logging
from contextlib import asynccontextmanager
from fastapi import Depends, FastAPI
from fastapi.middleware.cors import CORSMiddleware
from routes.chatbot import get_service, router as chatbot_router
from routes.predict import router as predict_router
from schemas import AgentStatusResponse
from services import ChatbotService, build_service

logging.basicConfig(level=logging.INFO, format='%(asctime)s %(levelname)s %(name)s: %(message)s')

@asynccontextmanager
async def lifespan(app: FastAPI):
    app.state.chatbot_service = build_service()
    yield

app = FastAPI(title='Fibo API', version='1.0.0', lifespan=lifespan)
app.add_middleware(
    CORSMiddleware,
    allow_origins=['*'],
    allow_credentials=False,
    allow_methods=['GET', 'POST', 'OPTIONS'],
    allow_headers=['*'],
)
app.include_router(chatbot_router)
app.include_router(predict_router)

@app.get('/health', tags=['Health'])
def health():
    return {'status': 'ok'}

@app.get('/api/v1/agent/status', response_model=AgentStatusResponse, tags=['Health'])
def agent_status(service: ChatbotService = Depends(get_service)) -> AgentStatusResponse:
    return service.get_status()
