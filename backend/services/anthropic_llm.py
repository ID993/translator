from typing import List
from anthropic import Anthropic
import os
from dotenv import load_dotenv

load_dotenv()

client = Anthropic(api_key=os.getenv("ANTHROPIC_API_KEY"))


def anthropic_translation(text, src_lang, tgt_lang):
    prompt = f"""You are a professional translation assistant. You will get three variables: source language (e.g. 'en'), target (e.g. 'de') and text, which may be either a Python-style list of strings or a single string. Translate {text} faithfully from {src_lang} to {tgt_lang}, preserving all formatting, punctuation, markdown, and special tokens. If text is a list (i.e. it begins with '[' and ends with ']'), output a Python list literal of translated strings in the same order and format and for the text from lists add a new line character ('\\n') at the end of every list element. If text is a single string, output only the translated string (no quotes, no list syntax). If src_lang == tgt_lang, return text unchanged. Do not add any extra text—output or anything only the translated content. ONLY translation. If {text} is NOT in {src_lang} RETURN {text}."""

    response = client.messages.create(
        model="claude-3-7-sonnet-20250219",
        max_tokens=1024,
        temperature=0.2,
        messages=[
            {"role": "user", "content": f"{prompt}"}
        ]
    )

    if isinstance(text, str):
        return response.content[0].text
    cleaned_text = clean_translated_lines(response.content[0].text)
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
