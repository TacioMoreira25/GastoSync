import json
import base64
import logging
from collections.abc import Callable
from typing import TypeVar
from pydantic import ValidationError

from groq import (
    Groq, AuthenticationError, PermissionDeniedError, RateLimitError,
    APITimeoutError, APIConnectionError, InternalServerError, BadRequestError,
    NotFoundError,
)
from config import API_KEY_GROQ, CLASSIFIER_MODELS, FIBO_MODELS, CATEGORIZE_MODELS, OCR_MODELS, read_prompt
from schemas import (
    ChatTurn, ChatbotRequest, Verification, CategorizeRequest,
    CategorizeResponse, OCRResponse, AgentStatusResponse,
)

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
                APIConnectionError, InternalServerError, BadRequestError,
                NotFoundError) as exc:
            logger.warning('Falha recuperável na etapa=%s, modelo=%s, tipo=%s, erro=%s',
                           operation, model, type(exc).__name__, exc)
            continue
        except (ValueError, KeyError, IndexError, TypeError, ValidationError) as exc:
            logger.warning('Resposta inválida na etapa=%s, modelo=%s, tipo=%s, erro=%s',
                           operation, model, type(exc).__name__, exc)
            continue

    raise AIServiceError(f'Nenhum modelo conseguiu concluir a etapa {operation}.', 503)


class ChatbotService:
    def __init__(self, client: Groq, classifier_prompt: str, fibo_prompt: str, categorize_prompt: str = "", ocr_prompt: str = ""):
        self.client = client
        self.classifier_prompt = classifier_prompt
        self.fibo_prompt = fibo_prompt
        self.categorize_prompt = categorize_prompt
        self.ocr_prompt = ocr_prompt
        self.total_requests = 0
        self.total_tokens_used = 0
        self.fallback_triggers = 0
        self.last_model_used = CLASSIFIER_MODELS[0] if CLASSIFIER_MODELS else ''

    def _record_usage(self, response, model: str, models_list: list[str]):
        self.total_requests += 1
        self.last_model_used = model
        if models_list and model != models_list[0]:
            self.fallback_triggers += 1
        usage = getattr(response, 'usage', None)
        tokens = getattr(usage, 'total_tokens', 0) if usage else 0
        if isinstance(tokens, int) and tokens > 0:
            self.total_tokens_used += tokens

    def get_status(self) -> AgentStatusResponse:
        return AgentStatusResponse(
            active_text_model=FIBO_MODELS[0] if FIBO_MODELS else 'N/A',
            fallback_text_models=FIBO_MODELS[1:] if len(FIBO_MODELS) > 1 else [],
            active_ocr_model=OCR_MODELS[0] if OCR_MODELS else 'N/A',
            fallback_ocr_models=OCR_MODELS[1:] if len(OCR_MODELS) > 1 else [],
            total_requests=self.total_requests,
            total_tokens_used=self.total_tokens_used,
            fallback_triggers=self.fallback_triggers,
            last_model_used=self.last_model_used,
        )

    def classificator(self, prompt: str, history: list[ChatTurn] | None = None) -> tuple[bool, str]:
        recent_turns = (history or [])[-4:]
        context_prefix = ""
        if recent_turns:
            formatted = "\n".join(f"{t.role}: {t.content}" for t in recent_turns)
            context_prefix = f"Histórico recente da conversa:\n{formatted}\n\nNova mensagem do usuário:\n"

        def execute(model: str) -> bool:
            response = self.client.chat.completions.create(
                model=model,
                messages=[
                    {'role': 'system', 'content': self.classifier_prompt},
                    {'role': 'user', 'content': f"{context_prefix}{prompt}"},
                ],
            )
            self._record_usage(response, model, CLASSIFIER_MODELS)
            content = response.choices[0].message.content
            if not isinstance(content, str):
                raise ValueError('Classificador retornou conteúdo vazio')
            cleaned = content.strip()
            if '</think>' in cleaned:
                cleaned = cleaned.split('</think>', 1)[1].strip()
            result = cleaned.lower()
            if result not in ('true', 'false'):
                raise ValueError('Classificador deve responder true ou false')
            return result == 'true'

        return run_with_fallback(CLASSIFIER_MODELS, 'Classificator', execute)

    def fibo(
        self,
        prompt: str,
        history: list[ChatTurn] | None = None,
        financial_context: str | None = None,
    ) -> tuple[str, str]:
        system_content = self.fibo_prompt
        if financial_context and financial_context.strip():
            system_content = f"{self.fibo_prompt}\n\nResumo financeiro atual do usuário no app:\n{financial_context.strip()}"

        messages = [{'role': 'system', 'content': system_content}]
        for turn in (history or [])[-8:]:
            messages.append({'role': turn.role, 'content': turn.content})
        messages.append({'role': 'user', 'content': prompt})

        def execute(model: str) -> str:
            response = self.client.chat.completions.create(
                model=model,
                response_format={'type': 'json_object'},
                messages=messages,
            )
            self._record_usage(response, model, FIBO_MODELS)
            content = response.choices[0].message.content
            if not isinstance(content, str):
                raise ValueError('Fibo retornou conteúdo vazio')
            parsed = json.loads(content)

            if not isinstance(parsed, dict):
                raise ValueError('Fibo deve retornar objeto JSON')

            chatbot_response = parsed.get('response') or parsed.get('reply')

            if not isinstance(chatbot_response, str):
                raise ValueError('Fibo deve retornar uma resposta textual')

            return chatbot_response

        return run_with_fallback(FIBO_MODELS, 'Fibo', execute)

    @staticmethod
    def parse_json_response(response, schema):
        content = response.choices[0].message.content
        if not isinstance(content, str):
            raise ValueError('Modelo retornou conteúdo vazio')
        cleaned = content.strip()
        if '</think>' in cleaned:
            cleaned = cleaned.split('</think>', 1)[1].strip()
        start = cleaned.find('{')
        end = cleaned.rfind('}')
        if start != -1 and end != -1 and end >= start:
            cleaned = cleaned[start:end + 1]
        parsed = json.loads(cleaned)
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
            self._record_usage(response, model, CATEGORIZE_MODELS)
            return self.parse_json_response(response, CategorizeResponse)
        result, model = run_with_fallback(CATEGORIZE_MODELS, 'Categorize', execute)
        logger.info('Categorização concluída, modelo=%s', model)
        return result

    def ocr(self, image_bytes: bytes, mime_type: str) -> OCRResponse:
        encoded = base64.b64encode(image_bytes).decode('ascii')
        image_url = f'data:{mime_type};base64,{encoded}'
        prompt_text = f'{self.ocr_prompt}\n\nExtraia os dados deste comprovante e retorne exclusivamente JSON válido.'
        def execute(model: str) -> OCRResponse:
            response = self.client.chat.completions.create(
                model=model,
                messages=[
                    {'role': 'user', 'content': [
                        {'type': 'text', 'text': prompt_text},
                        {'type': 'image_url', 'image_url': {'url': image_url}},
                    ]},
                ],
            )
            self._record_usage(response, model, OCR_MODELS)
            return self.parse_json_response(response, OCRResponse)
        result, model = run_with_fallback(OCR_MODELS, 'OCR', execute)
        logger.info('OCR concluído, modelo=%s', model)
        return result

    def chatbot(self, request: ChatbotRequest) -> Verification:
        approved, classifier_model = self.classificator(request.message, request.history)
        logger.info('Classificação concluída, modelo=%s', classifier_model)
        if not approved:
            out_of_scope_msg = 'Só posso ajudar com dúvidas de finanças pessoais, despesas, boletos, cartões e orçamento do GastoSync.'
            return Verification(
                reply=out_of_scope_msg,
                response=out_of_scope_msg,
                message='Mensagem fora do contexto!',
                erro='1',
            )
        response, model = self.fibo(request.message, request.history, request.financial_context)
        logger.info('Fibo concluído, modelo=%s', model)
        return Verification(
            reply=response,
            response=response,
            message='Mensagem dentro do contexto!',
            erro='0',
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
