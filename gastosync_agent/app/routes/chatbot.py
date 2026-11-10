import logging
from fastapi import APIRouter, Depends, HTTPException, Request
from schemas import ChatbotRequest, Verification
from services import AIServiceError, ChatbotService

logger = logging.getLogger(__name__)
router = APIRouter(tags=['Chatbot'])

def get_service(request: Request) -> ChatbotService:
    return request.app.state.chatbot_service

@router.post('/chatbot', response_model=Verification)
def chatbot(payload: ChatbotRequest, service: ChatbotService = Depends(get_service)) -> Verification:
    try:
        return service.chatbot(payload)
    except AIServiceError as exc:
        raise HTTPException(status_code=exc.status_code, detail=str(exc)) from exc
    except Exception as exc:
        logger.exception('Erro inesperado na rota /chatbot')
        raise HTTPException(status_code=500, detail='Erro interno ao processar a solicitação.') from exc
