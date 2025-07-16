import torch
from services.openai_llm import openai_translation
from services.anthropic_llm import anthropic_translation
from models.models_registry import MODEL_REGISTRY
import logging

logger = logging.getLogger(__name__)
LANGUAGE_MAP = {
    "hr": "hr_HR",
    "en": "en_XX",
    "es": "es_XX",
    "de": "de_DE",
    "fr": "fr_XX",
    "nl": "nl_XX",
    "it": "it_IT",
}


def ml_translate(texts, src_lang, tgt_lang, model_name):
    entry = MODEL_REGISTRY.get(model_name)
    if not entry:
        raise ValueError(f"Unsupported model: {model_name}")

    tokenizer = entry["tokenizer"]
    model = entry["model"]

    logger.info(f"Using model: {model.config.name_or_path}")

    if model_name == "facebook/mbart-large-50-many-to-many-mmt":
        mapped_src_lang = LANGUAGE_MAP.get(src_lang)
        mapped_tgt_lang = LANGUAGE_MAP.get(tgt_lang)

        tokenizer.src_lang = mapped_src_lang
        tgt_lang_id = tokenizer.lang_code_to_id[mapped_tgt_lang]

    elif model_name == "facebook/m2m100_1.2B":
        tokenizer.src_lang = src_lang
        tgt_lang_id = tokenizer.get_lang_id(tgt_lang)

    else:
        raise ValueError(f"Unsupported model: {model_name}")

    inputs = tokenizer(texts, return_tensors="pt",
                       padding=True, truncation=False)

    with torch.no_grad():
        generated_tokens = model.generate(
            **inputs, forced_bos_token_id=tgt_lang_id)

    return [tokenizer.decode(t, skip_special_tokens=True) for t in generated_tokens]


def translate_input_text(text, src_lang, tgt_lang, composite):
    engine, model_name = composite.split('_:_')
    logger.info(f"Model name: {engine} {model_name}\n")
    if engine == "ml":
        logger.info(
            f"Using machine learnining model:\n{model_name}, {text}, {src_lang}, {tgt_lang}\n")
        return ml_translate([text], src_lang, tgt_lang, model_name)[0]
    elif engine == "llm" and model_name == "chatgpt":
        logger.info(f"Using OpenAI:\n{text}, {src_lang}, {tgt_lang}\n")
        return openai_translation(text, src_lang, tgt_lang)
    elif engine == "llm" and model_name == "claude":
        logger.info(f"Using Anthropic:\n{text}, {src_lang}, {tgt_lang}\n")
        return anthropic_translation(text, src_lang, tgt_lang)
    else:
        raise ValueError(f"Unknown model {composite}")
