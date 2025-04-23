import torch
from services.llm_translate import llm_translation
from models.m2m100 import get_model, get_tokenizer


def ml_translate(texts, src_lang, tgt_lang):
    tokenizer = get_tokenizer()
    model = get_model()
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


def translate_input_text(text, src_lang, tgt_lang, model_name):
    if model_name == "ml":
        print(f"\nUSING MACHINE LEARNING: {text}, {src_lang}, {tgt_lang}\n")
        return ml_translate([text], src_lang, tgt_lang)[0]
    elif model_name == "llm":
        print(f"\nUSING LONG LANGUAGE MODEL: {text}, {src_lang}, {tgt_lang}\n")
        return llm_translation(text, src_lang, tgt_lang)
    else:
        raise ValueError(f"Unknown model {model_name}")
