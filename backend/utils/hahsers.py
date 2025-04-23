import hashlib


def generate_hash(data):
    return hashlib.md5(data).hexdigest()


def generate_text_cache_key(text, src_lang, tgt_lang):
    return f"translation_text_{src_lang}_{tgt_lang}_{hashlib.md5(text.encode('utf-8')).hexdigest()}"


def generate_image_cache_key(image_bytes, src_lang, tgt_lang):
    with open(image_bytes, "rb") as f:
        return f"translation_image_{src_lang}_{tgt_lang}_{hashlib.sha256(f.read()).hexdigest()}"


def generate_audio_cache_key(audio_bytes, src_lang, tgt_lang):
    with open(audio_bytes, "rb") as f:
        return f"translation_audio_{src_lang}_{tgt_lang}_{hashlib.sha256(f.read()).hexdigest()}"
