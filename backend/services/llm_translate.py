from dotenv import load_dotenv
from openai import OpenAI
import requests
import os
from flask import jsonify

load_dotenv()
client = OpenAI()
HF_TOKEN = os.environ.get("HUGGINGFACE_API_TOKEN")
LLAMA_API_URL = os.environ.get("LLAMA_API_URL")

HEADERS = {
    "Authorization": f"Bearer {HF_TOKEN}"
}


def llm_translation(text, src_lang, tgt_lang):
    response = client.responses.create(
        model="gpt-4o",
        input=[
            {
                "role": "system",
                "content": [
                    {
                        "type": "input_text",
                        "text": f"""You are a professional translation assistant. You will get three variables: source language (e.g. 'en'), target (e.g. 'de') and text, which may be either a Python-style list of strings or a single string. Translate text faithfully from {src_lang} to {tgt_lang}, preserving all formatting, punctuation, markdown, and special tokens. If text is a list (i.e. it begins with '[' and ends with ']'), output a Python list literal of translated strings in the same order and format and for the text from lists add a new line character ('\\n') at the end of every list element. If text is a single string, output only the translated string (no quotes, no list syntax). If src_lang == tgt_lang, return text unchanged. Do not add any extra text—output or anything only the translated content. ONLY translation."""
                    }
                ]
            },
            {
                "role": "user",
                "content": [
                    {
                        "type": "input_text",
                        "text": f"{text}"
                    }
                ]
            }
        ],
        temperature=0.2,
        max_output_tokens=1024
    )
    if isinstance(text, str):
        return response.output_text
    cleaned_text = clean_translated_lines(response.output_text)
    return cleaned_text


def llama_translation(text, src_lang, tgt_lang):
    prompt = f"Translate this from {src_lang} to {tgt_lang}: {text}"
    payload = {
        "inputs": prompt,
        "parameters": {"max_new_tokens": 1024}
    }

    response = requests.post(LLAMA_API_URL, headers=HEADERS, json=payload)
    if response.status_code != 200:
        return jsonify({"error": "Hugging Face API error", "details": response.text}), 500

    try:
        generated_text = response.json()[0]["generated_text"]
        translation = generated_text.split(":")[-1].strip()
        return jsonify({"translation": translation})
    except Exception as e:
        return jsonify({"error": "Unexpected API response", "details": str(e)}), 500


def clean_translated_lines(raw_response):
    translated_lines = raw_response.split("\\n")
    cleaned_lines = []
    for line in translated_lines:

        if line.startswith("['") or line.startswith(", '"):
            line = line.removeprefix("['")
        if line.startswith("', '"):
            line = line.removeprefix("', '")
        if line.endswith("']"):
            line = line.removesuffix("']")
        cleaned_lines.append(line)
    return cleaned_lines
