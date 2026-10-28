from fastapi import FastAPI
from pydantic import BaseModel
from groq import AuthenticationError, Groq
import os
from dotenv import load_dotenv
from pathlib import Path
from schemas import ChatbotRequest

load_dotenv()

prompt_path = Path(os.getenv("SYSTEM_PROMPT", "system_prompt.txt"))
prompt_path_fibo = Path(os.getenv("SYSTEM_PROMPT_FIBO", "system_prompt_fibo.txt"))
system_prompt_context_classificator = prompt_path.read_text(encoding="utf-8")
system_prompt_fibo = prompt_path_fibo.read_text(encoding="utf-8")

api_key = os.getenv("API_KEY_GROQ")
client = Groq(
    api_key=api_key
)

models = [
        "openai/gpt-oss-120b",
        "openai/gpt-oss-20b",
        "meta-llama/llama-guard-4-12b",
        "meta-models/muse-spark-open",
        "openai/gpt-oss-safeguard-20b",
        "qwen/qwen3.8-27b"
]

def classificator(prompt: str) -> str:
    models = models.reverse()
    
    response_verificatorModel = client.chat.completions.create(
        model=models[1],
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

    return response_verificatorModel



def fibo(prompt: str):
    chatbot = client.chat.completions.create(
        model="openai/gpt-oss-120b",
        response_format={'type': 'json_object'},
        messages=[
            {
                "role": "system",
                "content": system_prompt_fibo
            },
            {
                "role": "user",
                "content": prompt
            }
        ],
        # documents=
    )

    response = chatbot.choices[0].message.content

    return response




def chatbot(request: ChatbotRequest):
    user_name = request.user
    prompt = request.prompt

    """
    Para a verificação de contexo:
        Se o erro for 1, a mensagem está fora do contexto.
        Se o resulatdo for 0, a mensagem está dentro do contexto.
    """

    verification = {
        "message": "",
        "erro": None,
        "user_prompt": prompt,
        "chabot_response": None   
    }

    try:
        response_ClassificatorModel = classificator(prompt=prompt)
    
        if response_ClassificatorModel == "False":
            verification["message"] = "❌ Mensagem fora do contexto!"
            verification["erro"] = "PromptOutOfContextError"
    
            return {"verification": verification}
        else:
            verification["message"] = "✅ Mensagem dentro do contexto!"
            verification["erro"] = "None"
    
            chatbot = fibo(prompt)
    
            verification["chabot_response"] = chatbot.choices[0].message.content
    
            return verification

    except IndexError as e:
        print(f'[ERRO] A lista de modelos está vazia.')

        verification["message"] = f'[ERRO] A lista de modelos está vazia.'
        verification['erro'] = e

        return verification

    except AuthenticationError as e:
        print(f'[ERRO] Sua chave da API expirou')

        verification["message"] = f'[ERRO] Sua chave da API expirou'
        verification['erro'] = e

        return verification