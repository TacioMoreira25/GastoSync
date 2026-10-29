from pydantic import BaseModel
from uuid import UUID

class ChatbotRequest(BaseModel):
    user: str
    prompt: str
    session: int

class Verification(BaseModel):
    message: str
    erro: int
    user_prompt: str
    chabot_response: str 