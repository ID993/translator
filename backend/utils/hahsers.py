import hashlib


def generate_hash(data):
    return hashlib.md5(data).hexdigest()


def generate_text_cache_key(text, src_lang, tgt_lang, model_name):
    return f"text_{src_lang}_{tgt_lang}_{model_name}_{hashlib.md5(text.encode("utf-8")).hexdigest()}"


def generate_image_cache_key(image_bytes, src_lang, tgt_lang, model_name):
    with open(image_bytes, "rb") as f:
        return f"image_{src_lang}_{tgt_lang}_{model_name}_{hashlib.sha256(f.read()).hexdigest()}"


def generate_audio_cache_key(audio_bytes, src_lang, tgt_lang, model_name):
    with open(audio_bytes, "rb") as f:
        return f"audio_{src_lang}_{tgt_lang}_{model_name}_{hashlib.sha256(f.read()).hexdigest()}"
