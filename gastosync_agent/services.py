from fastapi import FastAPI, APIRouter
from pydantic import BaseModel
from groq import Groq, AuthenticationError, PermissionDeniedError, RateLimitError, APITimeoutError, InternalServerError, BadRequestError
from schemas import ChatbotRequest, Verification
import logging

import os
from dotenv import load_dotenv
from pathlib import Path

load_dotenv()

logger = logging.getLogger(__name__)

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
    
    llm = models[model_index]
    
    response_verificatorModel = client.chat.completions.create(
        model=llm,
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

    llm = models[model_index]
    
    chatbot = client.chat.completions.create(
        model=llm,
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

    return response, llm




def chatbot(request: ChatbotRequest, model_index: int = 0):
    user_name = request.user
    prompt = request.prompt
    INDEX_MODEL = model_index

    verification = Verification(
        message="", 
        erro="", 
        causes="", 
        user_prompt=prompt,
        llm="",
        chabot_response=""    
    )

    etapa = ""

    try:
        etapa = "Classificator"
        response_ClassificatorModel = classificator(prompt, INDEX_MODEL)
    
        if response_ClassificatorModel.strip().lower() == "false":
            verification.message = "❌ Mensagem fora do contexto!"
            verification.erro = "1"
    
            return verification
        else:
            verification.message = "✅ Mensagem dentro do contexto!"
            verification.erro = "0"

            etapa = "Fibo"
            verification.chabot_response, verification.llm = fibo(prompt, INDEX_MODEL) 
    
            return verification
        

    except IndexError as e:
        print(f'Etapa do erro: {etapa}')
        verification.message = '[ERRO] Todos os modelos disponíveis foram testados.'
        verification.erro = "IndexError"
        verification.causes = "índice maior que o tamanho da lista"

        return verification

    except AuthenticationError as e:
        print(f'Etapa do erro: {etapa}')
        verification.message = '401 Sua chave da API expirou'
        verification.erro = f'{e.status_code} | {type(e).__name__}'
        verification.causes = "A chave de API é inválida, expirou ou não foi enviada. .env não carregado (chave None)"

        return verification

    except PermissionDeniedError as e:
        print(f'Etapa do erro: {etapa}')
        verification.message = '403 Sem permissão para acessar o recurso'
        verification.erro = f'{e.status_code} | {type(e).__name__}'
        verification.causes = "A chave é válida, mas não tem permissão para o recurso. O modelo llm escolhido pode não estar liberado para a conta ou a região é bloqueada" # Colocar aqui qual o modelo llm que está sendo usado.

        if etapa == "Classificator":
            chatbot(request, INDEX_MODEL + 1)
        elif etapa == 'Fibo':
            verification.message = "✅ Mensagem dentro do contexto!"
            verification.erro = "0"

            etapa = "Fibo"
            verification.chabot_response, verification.llm = fibo(prompt, INDEX_MODEL + 1) 
    
            return verification


    except RateLimitError as e:
        print(f'Etapa do erro: {etapa}')
        verification.message = 'Limite de tokens atingido'
        verification.erro = f'{e.status_code} | {type(e).__name__}'
        verification.causes = "Limite de requisições ou tokens por minuto/dia excedido"

        if etapa == "Classificator":
            chatbot(request, INDEX_MODEL + 1)
        elif etapa == 'Fibo':
            verification.message = "✅ Mensagem dentro do contexto!"
            verification.erro = "0"

            etapa = "Fibo"
            verification.chabot_response, verification.llm = fibo(prompt, INDEX_MODEL + 1) 
    
            return verification

        
    except APITimeoutError as e:
        print(f'Etapa do erro: {etapa}')
        verification.message = 'A requisição excedeu o tempo limite'
        verification.erro = f'{type(e).__name__}'
        verification.causes = "Prompt ou histórico muito grande. Servidor lento ou rede instável. timeout configurado muito baixo"

        return verification

    except InternalServerError as e:
        print(f'Etapa do erro: {etapa}')
        verification.message = 'Problema no servidor'
        verification.erro = f'{e.status_code} | {type(e).__name__}'
        verification.causes = "Instabilidade ou sobrecarga do provedor"

        return verification

    except Exception as e:
        print(f'Etapa do erro: {etapa}')

        logger.exception('Erro inesperado no chatbot')

        verification.message = "Erro interno ao processar a solicitação."
        verification.erro = "InternalError"
        verification.causes = "Falha inesperada no serviço."

        return verification








