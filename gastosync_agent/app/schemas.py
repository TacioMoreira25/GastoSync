from pydantic import BaseModel, Field, field_validator, ConfigDict

from datetime import datetime
from typing import Literal

class ChatbotRequest(BaseModel):
    user: str = Field(min_length=1, max_length=100)
    prompt: str = Field(min_length=1, max_length=4000)
    session: int = Field(ge=1)

    @field_validator('user', 'prompt')
    @classmethod
    def reject_blank(cls, value: str) -> str:
        value = value.strip()
        if not value:
            raise ValueError('Não pode conter apenas espaços')
        return value

class Verification(BaseModel):
    message: str
    erro: str
    causes: str = ''
    user_prompt: str
    llm: str = ''
    chabot_response: str = ''  # nome preservado para compatibilidade

ExpenseCategory = Literal["Alimentação", "Transporte", "Moradia", "Saúde", "Lazer", "Educação", "Outros"]

class CategorizeRequest(BaseModel):
    description: str = Field(min_length=1, max_length=1000)
    amount: float | None = Field(default=None, ge=0, allow_inf_nan=False)
    user_id: str | None = None


class CategorizeResponse(BaseModel):
    model_config = ConfigDict(extra="forbid")

    category: ExpenseCategory
    confidence: float = Field(ge=0, le=1, allow_inf_nan=False)
    normalized_description: str
    estimated_amount: float | None
    budget_tip: str


class OCRResponse(BaseModel):
    model_config = ConfigDict(extra="forbid")

    merchant: str | None
    amount: float | None = Field(ge=0, allow_inf_nan=False)
    date: datetime | None
    category: ExpenseCategory
    confidence: float = Field(ge=0, le=1, allow_inf_nan=False)
    budget_tip: str

