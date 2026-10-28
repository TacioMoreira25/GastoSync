from fastapi import FastAPI
from services import classificator, fibo, chatbot
from schemas import ChatbotRequest
from groq import AuthenticationError, Groq

app = FastAPI()

app.post('/chatbot')(chatbot)

