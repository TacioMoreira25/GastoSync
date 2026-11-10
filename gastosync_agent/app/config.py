import os
from pathlib import Path
from dotenv import load_dotenv

BASE_DIR = Path(__file__).resolve().parent
load_dotenv(BASE_DIR / '.env')

API_KEY_GROQ = os.getenv('API_KEY_GROQ')
CLASSIFIER_MODELS = [s.strip() for s in os.getenv('CLASSIFIER_MODELS', 'openai/gpt-oss-120b,openai/gpt-oss-20b').split(',') if s.strip()]
FIBO_MODELS = [s.strip() for s in os.getenv('FIBO_MODELS', 'openai/gpt-oss-120b,openai/gpt-oss-20b').split(',') if s.strip()]

def read_prompt(env_name: str, default: str) -> str:
    path = Path(os.getenv(env_name, default))
    if not path.is_absolute():
        path = BASE_DIR / path
    try:
        content = path.read_text(encoding='utf-8').strip()
    except OSError as exc:
        raise RuntimeError(f'Não foi possível ler {env_name}: {path}') from exc
    if not content:
        raise RuntimeError(f'Prompt vazio: {path}')
    return content

CATEGORIZE_MODELS = [s.strip() for s in os.getenv('CATEGORIZE_MODELS', 'openai/gpt-oss-120b,openai/gpt-oss-20b').split(',') if s.strip()]
OCR_MODELS = [s.strip() for s in os.getenv('OCR_MODELS', 'meta-llama/llama-4-scout-17b-16e-instruct').split(',') if s.strip()]
MAX_IMAGE_BYTES = int(os.getenv('MAX_IMAGE_BYTES', str(5 * 1024 * 1024)))
