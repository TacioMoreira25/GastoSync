import logging
from fastapi import APIRouter, Depends, File, UploadFile, HTTPException
from schemas import CategorizeRequest, CategorizeResponse, OCRResponse
from services import AIServiceError, ChatbotService
from routes.chatbot import get_service
from config import MAX_IMAGE_BYTES

logger = logging.getLogger(__name__)
router = APIRouter(prefix='/api/v1/predict', tags=['Predict'])

@router.post('/categorize', response_model=CategorizeResponse)
def categorize_expense(payload: CategorizeRequest, service: ChatbotService = Depends(get_service)):
    try:
        return service.categorize(payload)
    except AIServiceError as exc:
        raise HTTPException(status_code=exc.status_code, detail=str(exc)) from exc

@router.post('/ocr', response_model=OCRResponse)
async def extract_ocr(image: UploadFile = File(...), service: ChatbotService = Depends(get_service)):
    allowed = {'image/jpeg', 'image/png', 'image/webp'}
    generic_types = {'application/octet-stream', 'image/jpg', None, ''}
    if image.content_type not in allowed and image.content_type not in generic_types:
        raise HTTPException(status_code=415, detail='Formato não suportado: envie JPEG, PNG ou WebP.')
    try:
        data = await image.read(MAX_IMAGE_BYTES + 1)
    finally:
        await image.close()
    if not data:
        raise HTTPException(status_code=400, detail='Imagem vazia.')
    if len(data) > MAX_IMAGE_BYTES:
        raise HTTPException(status_code=413, detail='Imagem excede o tamanho máximo permitido.')
    signatures = {'image/jpeg': data.startswith(b'\xff\xd8\xff'),
                  'image/png': data.startswith(b'\x89PNG\r\n\x1a\n'),
                  'image/webp': data[:4] == b'RIFF' and data[8:12] == b'WEBP'}
    detected_mime = next((mime for mime, matches in signatures.items() if matches), None)
    if not detected_mime:
        raise HTTPException(status_code=400, detail='Conteúdo não corresponde ao formato da imagem.')
    if image.content_type in allowed and image.content_type != detected_mime:
        raise HTTPException(status_code=400, detail='Conteúdo não corresponde ao formato da imagem.')
    try:
        return service.ocr(data, detected_mime)
    except AIServiceError as exc:
        raise HTTPException(status_code=exc.status_code, detail=str(exc)) from exc
