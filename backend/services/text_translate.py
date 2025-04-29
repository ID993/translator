import torch
from services.openai_llm import openai_translation
from services.anthropic_llm import anthropic_translation
from models.m2m100 import get_model, get_tokenizer


def ml_translate(texts, src_lang, tgt_lang, model_name):
    tokenizer = get_tokenizer(model_name)
    model = get_model(model_name)
    tokenizer.src_lang = src_lang
    inputs = tokenizer(texts, return_tensors="pt",
                       padding=True, truncation=True)
    tgt_lang_id = tokenizer.get_lang_id(tgt_lang)
    with torch.no_grad():
        generated_tokens = model.generate(
            **inputs, forced_bos_token_id=tgt_lang_id)
    print(
        f"\nTokenizer:\n{[tokenizer.decode(t, skip_special_tokens=True) for t in generated_tokens]}\n")
    return [tokenizer.decode(t, skip_special_tokens=True) for t in generated_tokens]


def translate_input_text(text, src_lang, tgt_lang, composite):
    print(f"\nCOMPOSITE: {composite}")
    engine, model_name = composite.split('_:_')
    print(f"\nMODEL NAME: {engine} {model_name}\n")
    if engine == "ml":
        print(
            f"\nUSING MACHINE LEARNING {model_name}: {text}, {src_lang}, {tgt_lang}\n")
        return ml_translate([text], src_lang, tgt_lang, model_name)[0]
    elif engine == "llm" and model_name == "chatgpt":
        print(f"\nUSING OPEN AI: {text}, {src_lang}, {tgt_lang}\n")
        return openai_translation(text, src_lang, tgt_lang)
    elif engine == "llm" and model_name == "claude":
        print(f"\nUSING ANTHROPIC: {text}, {src_lang}, {tgt_lang}\n")
        return anthropic_translation(text, src_lang, tgt_lang)
    else:
        raise ValueError(f"Unknown model {composite}")
