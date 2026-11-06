from pydantic import BaseModel
from uuid import UUID

class ChatbotRequest(BaseModel):
    user: str
    prompt: str
    session: int

class Verification(BaseModel):
    message: str # message about the error
    erro: str # Status code HTTP. If the error is about user prompt context, the status code is 1 to an error and 0 to no erro
    causes: str # The comum causes to that error
    user_prompt: str # the user prompt, that he sended to the chatbot
    llm: str # the used model for response the user
    chabot_response: str # llm response