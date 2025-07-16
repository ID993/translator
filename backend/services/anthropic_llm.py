from typing import List
from anthropic import Anthropic, APIError, AuthenticationError, RateLimitError, APIConnectionError
import os
from dotenv import load_dotenv
import logging

logger = logging.getLogger(__name__)

load_dotenv()

client = Anthropic(api_key=os.getenv("ANTHROPIC_API_KEY"))

def check_anthropic_available():
    try:
        client.models.list()
        return {'available': True}

    except AuthenticationError as e:
        return {'available': False, 'error': {'code': 'authentication_error', 'message': str(e)}}
    except RateLimitError as e:
        return {'available': False, 'error': {'code': 'rate_limit_error', 'message': str(e)}}
    except APIConnectionError as e:
        return {'available': False, 'error': {'code': 'connection_error', 'message': str(e)}}
    except APIError as e:
        return {'available': False, 'error': {'code': 'api_error', 'message': str(e)}}
    

def anthropic_translation(text, src_lang, tgt_lang):
    health = check_anthropic_available()
    if not health['available']:
        err = health['error']
        raise APIError(f"{err['code']}: {err['message']}")
    
    prompt = f"""You are a professional translation assistant. You will get three variables: source language (e.g. 'en'), target (e.g. 'de') and text, which may be either a Python-style list of strings or a single string. Translate the following text from {src_lang} to {tgt_lang}: {text}. Preserve all formatting, punctuation, markdown, and special tokens. If text is a list (i.e. it begins with '[' and ends with ']'), output a Python list literal of translated strings in the same order and format and for the text from lists add a new line character ('\\n') at the end of every list element. If text is a single string, output only the translated string (no quotes, no list syntax). If src_lang == tgt_lang, return text unchanged. Do not add any extra text—output or anything only the translated content. ONLY translation. If received text ({text}) is not in source language ({src_lang}) DO NOT TRANSLATE and write that original text ({text})."""

    try:
        response = client.messages.create(
            model="claude-3-7-sonnet-20250219",
            max_tokens=1024,
            temperature=0.2,
            messages=[
                {"role": "user", "content": f"{prompt}"}
            ]
        )
    except APIError as e:
        raise APIError(f"api_error: {str(e)}")

    if isinstance(text, str):
        logger.info(f"Translation: {response.content[0].text}\n")
        return response.content[0].text
    cleaned_text = clean_translated_lines(response.content[0].text)
    logger.info(f"Translation CT: {cleaned_text}\n")
    return cleaned_text


def clean_translated_lines(raw_response: str) -> List[str]:
    lines = raw_response.replace("\\n", "\n").splitlines()

    cleaned: List[str] = []
    for line in lines:
        stripped = line.strip("[]'\", \t\r\n")
        if stripped:
            cleaned.append(stripped)
    return cleaned


def clean_translated_lines2(raw_response):
    translated_lines = raw_response.split("\\n")
    cleaned_lines = []
    for line in translated_lines:

        if line.startswith("['"):
            line = line.removeprefix("['")
        if line.startswith('["'):
            line = line.removeprefix('["')
        if line.startswith(", '"):
            line = line.removeprefix(", '")
        if line.startswith(', "'):
            line = line.removeprefix(', "')
        if line.startswith("', '"):
            line = line.removeprefix("', '")
        if line.startswith('", "'):
            line = line.removeprefix('", "')
        if line.endswith("']"):
            line = line.removesuffix("']")
        if line.endswith('"]'):
            line = line.removesuffix('"]')
        cleaned_lines.append(line)
    return cleaned_lines
