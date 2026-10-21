from fastapi import FastAPI
from pydantic import BaseModel
from groq import Groq
import os
from dotenv import load_dotenv
from pathlib import Path

load_dotenv()

prompt_path = Path(os.getenv("SYSTEM_PROMPT", "system_prompt.txt"))
prompt_path_fibo = Path(os.getenv("SYSTEM_PROMPT_FIBO", "system_prompt_fibo.txt"))
system_prompt_context_classificator = prompt_path.read_text(encoding="utf-8")
system_prompt_fibo = prompt_path_fibo.read_text(encoding="utf-8")

class Prompt:
    user: str
    prompt: str
    session: int

app = FastAPI()

@app.get("/chatbot")
def chatbot(user_name: str, prompt: str, session: int = 1):
    """
    Para a verificação de contexo:
        Se o erro for 1, a mensagem está fora do contexto.
        Se o resulatdo for 0, a mensagem está dentro do contexto.
    """


    api_key = os.getenv("API_KEY_GROQ")
    client = Groq(
        api_key=api_key
    )

    response_verificatorModel = client.chat.completions.create(
        model="qwen/qwen3.8-27b",
        messages=[
            {
                "role": "system",
                "content": system_prompt_context_classificator
            },
            {
                "role": "user",
                "content": prompt
            }
        ]
    ).choices[0].message.content

    verification = {
        "message": "",
        "erro": None,
        "user_prompt": prompt,
        "chabot_response": None   
    }

    if response_verificatorModel == "False":
        verification["message"] = "❌ Mensagem fora do contexto!"
        verification["erro"] = 1

        return {"verification": verification}
    else:
        verification["message"] = "✅ Mensagem dentro do contexto!"
        verification["erro"] = 0

        chatbot = client.chat.completions.create(
            model="openai/gpt-oss-120b",
            messages=[
                {
                    "role": "system",
                    "content": system_prompt_fibo
                },
                {
                    "role": "user",
                    "content": prompt
                }
            ]
        )

        verification["chabot_response"] = chatbot.choices[0].message.content

        return verification



    

    
