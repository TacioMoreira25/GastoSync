import logging
from contextlib import asynccontextmanager
from fastapi import FastAPI
from routes.chatbot import router as chatbot_router
from routes.predict import router as predict_router
from services import build_service

logging.basicConfig(level=logging.INFO, format='%(asctime)s %(levelname)s %(name)s: %(message)s')

@asynccontextmanager
async def lifespan(app: FastAPI):
    app.state.chatbot_service = build_service()
    yield

app = FastAPI(title='Fibo API', version='1.0.0', lifespan=lifespan)
app.include_router(chatbot_router)
app.include_router(predict_router)

@app.get('/health', tags=['Health'])
def health():
    return {'status': 'ok'}
