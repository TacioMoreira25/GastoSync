import json
import base64
import logging
from collections.abc import Callable
from typing import TypeVar
from pydantic import ValidationError

from groq import (
    Groq, AuthenticationError, PermissionDeniedError, RateLimitError,
    APITimeoutError, APIConnectionError, InternalServerError, BadRequestError,
)
from config import API_KEY_GROQ, CLASSIFIER_MODELS, FIBO_MODELS, CATEGORIZE_MODELS, OCR_MODELS, read_prompt
from schemas import ChatbotRequest, Verification, CategorizeRequest, CategorizeResponse, OCRResponse

logger = logging.getLogger(__name__)
T = TypeVar('T')

class AIServiceError(Exception):
    def __init__(self, message: str, status_code: int = 503):
        super().__init__(message)
        self.status_code = status_code


def run_with_fallback(models: list[str], operation: str, call: Callable[[str], T]) -> tuple[T, str]:
    if not models:
        raise AIServiceError('Nenhum modelo configurado.', 503)

    for model in models:
        try:
            return call(model), model
        except AuthenticationError as exc:
            logger.error('Falha de autenticação no provedor, etapa=%s', operation)
            raise AIServiceError('Serviço de IA indisponível por erro de configuração.', 503) from exc
        except (PermissionDeniedError, RateLimitError, APITimeoutError,
                APIConnectionError, InternalServerError, BadRequestError) as exc:
            logger.warning('Falha recuperável na etapa=%s, modelo=%s, tipo=%s',
                           operation, model, type(exc).__name__)
            continue
        except (ValueError, KeyError, IndexError, TypeError, ValidationError) as exc:
            logger.warning('Resposta inválida na etapa=%s, modelo=%s, tipo=%s',
                           operation, model, type(exc).__name__)
            continue

    raise AIServiceError(f'Nenhum modelo conseguiu concluir a etapa {operation}.', 503)


class ChatbotService:
    def __init__(self, client: Groq, classifier_prompt: str, fibo_prompt: str, categorize_prompt: str = "", ocr_prompt: str = ""):
        self.client = client
        self.classifier_prompt = classifier_prompt
        self.fibo_prompt = fibo_prompt
        self.categorize_prompt = categorize_prompt
        self.ocr_prompt = ocr_prompt

    def classificator(self, prompt: str) -> tuple[bool, str]:
        def execute(model: str) -> bool:
            response = self.client.chat.completions.create(
                model=model,
                messages=[
                    {'role': 'system', 'content': self.classifier_prompt},
                    {'role': 'user', 'content': prompt},
                ],
            )
            content = response.choices[0].message.content
            if not isinstance(content, str):
                raise ValueError('Classificador retornou conteúdo vazio')
            result = content.strip().lower()
            if result not in ('true', 'false'):
                raise ValueError('Classificador deve responder true ou false')
            return result == 'true'

        return run_with_fallback(CLASSIFIER_MODELS, 'Classificator', execute)

    def fibo(self, prompt: str) -> tuple[str, str]:
        def execute(model: str) -> str:
            response = self.client.chat.completions.create(
                model=model,
                response_format={'type': 'json_object'},
                messages=[
                    {'role': 'system', 'content': self.fibo_prompt},
                    {'role': 'user', 'content': prompt},
                ],
            )
            content = response.choices[0].message.content
            if not isinstance(content, str):
                raise ValueError('Fibo retornou conteúdo vazio')
            parsed = json.loads(content)

            if not isinstance(parsed, dict):
                raise ValueError('Fibo deve retornar objeto JSON')

            chatbot_response = parsed.get('response')

            if not isinstance(chatbot_response, str):
                raise ValueError('Fibo deve retornar uma resposta textual')

            return chatbot_response

        return run_with_fallback(FIBO_MODELS, 'Fibo', execute)

    @staticmethod
    def parse_json_response(response, schema):
        content = response.choices[0].message.content
        if not isinstance(content, str):
            raise ValueError('Modelo retornou conteúdo vazio')
        parsed = json.loads(content)
        if not isinstance(parsed, dict):
            raise ValueError('Resposta deve ser um objeto JSON')
        return schema.model_validate(parsed)

    def categorize(self, request: CategorizeRequest) -> CategorizeResponse:
        def execute(model: str) -> CategorizeResponse:
            response = self.client.chat.completions.create(
                model=model,
                response_format={'type': 'json_object'},
                messages=[
                    {'role': 'system', 'content': self.categorize_prompt},
                    {'role': 'user', 'content': json.dumps({
                        'description': request.description,
                        'amount': request.amount,
                    }, ensure_ascii=False)},
                ],
            )
            return self.parse_json_response(response, CategorizeResponse)
        result, model = run_with_fallback(CATEGORIZE_MODELS, 'Categorize', execute)
        logger.info('Categorização concluída, modelo=%s', model)
        return result

    def ocr(self, image_bytes: bytes, mime_type: str) -> OCRResponse:
        encoded = base64.b64encode(image_bytes).decode('ascii')
        image_url = f'data:{mime_type};base64,{encoded}'
        def execute(model: str) -> OCRResponse:
            response = self.client.chat.completions.create(
                model=model,
                response_format={'type': 'json_object'},
                messages=[
                    {'role': 'system', 'content': self.ocr_prompt},
                    {'role': 'user', 'content': [
                        {'type': 'text', 'text': 'Extraia os dados deste comprovante e retorne exclusivamente JSON válido.'},
                        {'type': 'image_url', 'image_url': {'url': image_url}},
                    ]},
                ],
            )
            return self.parse_json_response(response, OCRResponse)
        result, model = run_with_fallback(OCR_MODELS, 'OCR', execute)
        logger.info('OCR concluído, modelo=%s', model)
        return result

    def chatbot(self, request: ChatbotRequest) -> Verification:
        approved, classifier_model = self.classificator(request.prompt)
        logger.info('Classificação concluída, modelo=%s, session=%s', classifier_model, request.session)
        if not approved:
            return Verification(
                message='Mensagem fora do contexto!', erro='1',
                user_prompt=request.prompt,
            )
        response, model = self.fibo(request.prompt)
        return Verification(
            message='Mensagem dentro do contexto!', erro='0',
            user_prompt=request.prompt, llm=model, chabot_response=response,
        )


def build_service() -> ChatbotService:
    if not API_KEY_GROQ:
        raise RuntimeError('API_KEY_GROQ não configurada no .env')
    classifier_prompt = read_prompt('SYSTEM_PROMPT', 'system_prompt.txt')
    fibo_prompt = read_prompt('SYSTEM_PROMPT_FIBO', 'system_prompt_fibo.txt')
    categorize_prompt = read_prompt('SYSTEM_PROMPT_CATEGORIZE', 'system_prompt_categorize.txt')
    ocr_prompt = read_prompt('SYSTEM_PROMPT_OCR', 'system_prompt_ocr.txt')
    return ChatbotService(Groq(api_key=API_KEY_GROQ, max_retries=0, timeout=20.0),
                          classifier_prompt, fibo_prompt, categorize_prompt, ocr_prompt)
