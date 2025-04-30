import re
import os
import fasttext


UTILS_DIR = os.path.dirname(__file__)
BACKEND_DIR = os.path.dirname(UTILS_DIR)
MODEL_PATH = os.path.join(BACKEND_DIR, "models", "lid.176.bin")
model = fasttext.load_model(MODEL_PATH)

PARENT_LANGS = {
    'hr': ['bs', 'sr'],
    'nl': ['af', 'fy'],
    'es': ['ca', 'gl'],
    'en': ['cy']
}


def normalize(text):
    text = text.lower()
    text = re.sub(r"[^\w\s]", " ", text)
    return " ".join(text.split())


def detect_language(text: str, k: int = 1):
    labels, probabilities = model.predict(normalize(text), k=k)
    results = [(lbl.replace("__label__", ""), prob)
               for lbl, prob in zip(labels, probabilities)]
    return results


def get_parent_language(chosen_lang, lang_map):
    for parent, similars in lang_map.items():
        if chosen_lang in similars:
            return parent
    return chosen_lang


def get_lang(text):
    lang = detect_language(text)[0][0]
    return get_parent_language(lang, PARENT_LANGS)
