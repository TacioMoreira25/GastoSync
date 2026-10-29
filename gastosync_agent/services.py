from fastapi import FastAPI
from pydantic import BaseModel
from groq import Groq, AuthenticationError, PermissionDeniedError, RateLimitError, APITimeoutError
import os
from dotenv import load_dotenv
from pathlib import Path
from schemas import ChatbotRequest, Verification

load_dotenv()

prompt_path = Path(os.getenv("SYSTEM_PROMPT", "system_prompt.txt"))
prompt_path_fibo = Path(os.getenv("SYSTEM_PROMPT_FIBO", "system_prompt_fibo.txt"))
system_prompt_context_classificator = prompt_path.read_text(encoding="utf-8")
system_prompt_fibo = prompt_path_fibo.read_text(encoding="utf-8")

api_key = os.getenv("API_KEY_GROQ")
client = Groq(
    api_key=api_key
)



def classificator(prompt: str, model_index: int = 0) -> str:
    models = [
        "openai/gpt-oss-120b",
        "openai/gpt-oss-20b",
        "meta-llama/llama-guard-4-12b",
        "meta-models/muse-spark-open",
        "openai/gpt-oss-safeguard-20b",
        "qwen/qwen3.8-27b"
    ]
    
    models.reverse()
    
    response_verificatorModel = client.chat.completions.create(
        model=models[model_index],
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



def fibo(prompt: str, model_index: int = 0):
    models = [
        "openai/gpt-oss-120b",
        "openai/gpt-oss-20b",
        "meta-llama/llama-guard-4-12b",
        "meta-models/muse-spark-open",
        "openai/gpt-oss-safeguard-20b",
        "qwen/qwen3.8-27b"
    ]
    
    chatbot = client.chat.completions.create(
        model=models[model_index],
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




def chatbot(request: ChatbotRequest, model_index: int = 0):
    user_name = request.user
    prompt = request.prompt

    """
    Para a verificação de contexo:
        Se o erro for 1, há erros.
        Se o resulatdo for 0, NÃO há erros.
    """

    verification = Verification()

    verification.message = ""
    verification.erro = 0
    verification.user_prompt = prompt
    verification.chabot_response = ""

    try:
        response_ClassificatorModel = classificator(prompt=prompt)
    
        if response_ClassificatorModel == "False":
            verification.message = "❌ Mensagem fora do contexto!"
            verification.erro = 1
    
            return verification
        else:
            verification.message = "✅ Mensagem dentro do contexto!"
            verification.erro = 0
    
            verification.chabot_response = fibo(prompt) 
    
            return verification

    except IndexError as e:
        print('[ERRO] A lista de modelos está vazia.')

        verification.message = '[ERRO] A lista de modelos está vazia.'
        verification.erro = str(e)

        return verification

    except AuthenticationError as e:
        print('[ERRO] Sua chave da API expirou')

        verification.message = '[ERRO] Sua chave da API expirou'
        verification.erro = str(e)

        return verification

    except PermissionDeniedError as e:
        print('[ERRO] Sem permissão para acessar o recurso')

        verification.message = '[ERRO] Sem permissão para acessar o recurso'
        verification.erro = str(e)

        return verification

    except RateLimitError as e:
        print('[ERRO] Limite de tokens atingido')

        verification.message = '[ERRO] Limite de tokens atingido'
        verification.erro = str(e)

        return verification

    except APITimeoutError as e:
        print('[ERRO] A requisição excedeu o tempo limite')

        verification.message = '[ERRO] A requisição excedeu o tempo limite'
        verification.erro = str(e)

        return verification




