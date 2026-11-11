from datetime import datetime
import re
from typing import Literal
from pydantic import BaseModel, ConfigDict, Field, field_validator, model_validator

_INJECTION_PATTERNS = re.compile(
    r'(ignore\s+(all\s+)?(previous|prior|above)\s+instructions|'
    r'esqueça\s+(todas\s+as\s+)?instruções\s+anteriores|'
    r'system\s*prompt|reveal\s+your\s+instructions|'
    r'você\s+agora\s+é\s+um|act\s+as\s+a\s+different|'
    r'<\s*script\b|javascript\s*:)',
    re.IGNORECASE,
)


def sanitize_prompt_input(value: str) -> str:
    cleaned = re.sub(r'[\x00-\x08\x0b\x0c\x0e-\x1f\x7f]', '', value).strip()
    if _INJECTION_PATTERNS.search(cleaned):
        raise ValueError('Entrada bloqueada por conter padrões suspeitos de Prompt Injection.')
    return cleaned


class ChatTurn(BaseModel):
    role: Literal['user', 'assistant']
    content: str = Field(min_length=1, max_length=4000)

    @field_validator('content')
    @classmethod
    def validate_turn_content(cls, value: str) -> str:
        cleaned = sanitize_prompt_input(value)
        if not cleaned:
            raise ValueError('Conteúdo do histórico não pode ser vazio.')
        return cleaned


class ChatbotRequest(BaseModel):
    model_config = ConfigDict(
        json_schema_extra={
            'example': {
                'message': 'E se eu gastar R$ 900 no mês, ainda fica saudável?',
                'history': [
                    {'role': 'user', 'content': 'Tenho R$ 1500 de limite no cartão principal.'},
                    {'role': 'assistant', 'content': 'O ideal é manter o uso entre 50% (R$ 750) e 80% (R$ 1200) do limite.'},
                ],
                'financial_context': 'Renda mensal: R$ 4500 | Despesas no mês: R$ 1800 | Limite Cartão Principal: R$ 1500',
            }
        }
    )

    message: str = Field(min_length=1, max_length=4000)
    history: list[ChatTurn] = Field(default_factory=list, max_length=10)
    financial_context: str | None = Field(default=None, max_length=2000)

    @field_validator('message')
    @classmethod
    def reject_blank(cls, value: str) -> str:
        cleaned = sanitize_prompt_input(value)
        if not cleaned:
            raise ValueError('Envie o campo message com a sua dúvida financeira.')
        return cleaned


class Verification(BaseModel):
    reply: str = ''
    response: str = ''
    message: str
    erro: str


ExpenseCategory = Literal[
    "Alimentação", "Transporte", "Moradia", "Saúde",
    "Lazer", "Educação", "Investimentos", "Outros"
]


class CategorizeRequest(BaseModel):
    description: str = Field(min_length=1, max_length=1000)
    amount: float | None = Field(default=None, ge=0, allow_inf_nan=False)
    user_id: str | None = None

    @field_validator('description')
    @classmethod
    def validate_description(cls, value: str) -> str:
        cleaned = sanitize_prompt_input(value)
        if not cleaned:
            raise ValueError('A descrição não pode ser vazia.')
        return cleaned


class CategorizeResponse(BaseModel):
    model_config = ConfigDict(extra="ignore")

    category: ExpenseCategory
    confidence: float = Field(ge=0, le=1, allow_inf_nan=False)
    normalized_description: str
    estimated_amount: float | None
    budget_tip: str
    payment_method: str | None = None


class OCRResponse(BaseModel):
    model_config = ConfigDict(extra="ignore")

    merchant: str | None = None
    amount: float | None = Field(default=None, ge=0, allow_inf_nan=False)
    date: datetime | None = None
    category: ExpenseCategory = "Outros"
    confidence: float = Field(default=0.5, ge=0, le=1, allow_inf_nan=False)
    budget_tip: str = "Revise os dados extraídos do comprovante antes de salvar."
    payment_method: str | None = None

    @field_validator('category', mode='before')
    @classmethod
    def normalize_category(cls, value):
        valid = {"Alimentação", "Transporte", "Moradia", "Saúde", "Lazer", "Educação", "Investimentos", "Outros"}
        if isinstance(value, str) and value.strip() in valid:
            return value.strip()
        return "Outros"

    @field_validator('date', mode='before')
    @classmethod
    def parse_flexible_date(cls, value):
        if value is None or isinstance(value, datetime):
            return value
        if isinstance(value, str):
            cleaned = value.strip()
            if not cleaned:
                return None
            for fmt in ('%d/%m/%Y %H:%M:%S', '%d/%m/%Y %H:%M', '%d/%m/%Y', '%Y-%m-%d'):
                try:
                    return datetime.strptime(cleaned, fmt)
                except ValueError:
                    continue
        return value


class AgentStatusResponse(BaseModel):
    status: str = 'ok'
    provider: str = 'Groq Cloud'
    active_text_model: str
    fallback_text_models: list[str]
    active_ocr_model: str
    fallback_ocr_models: list[str]
    total_requests: int = 0
    total_tokens_used: int = 0
    fallback_triggers: int = 0
    last_model_used: str = ''
    daily_request_limit: int = 1000
    minute_token_limit: int = 12000
