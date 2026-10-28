from pydantic import BaseModel
from uuid import UUID

class ChatbotRequest(BaseModel):
    user: str
    prompt: str
    session: int