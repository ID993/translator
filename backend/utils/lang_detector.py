import re
import os
import fasttext
import pytesseract
import logging

logger = logging.getLogger(__name__)


UTILS_DIR = os.path.dirname(__file__)
BACKEND_DIR = os.path.dirname(UTILS_DIR)
MODEL_PATH = os.path.join(BACKEND_DIR, "models", "lid.176.bin")
model = fasttext.load_model(MODEL_PATH)

PARENT_LANGS = {
    'hr': ['bs', 'sr', 'sh'],
    'nl': ['af', 'fy'],
    'es': ['ca', 'gl'],
    'en': ['cy']
}


def normalize(text):
    text = text.lower()
    text = re.sub(r"[^\w\s]", " ", text)
    return " ".join(text.split())


def detect_language(text, k: int = 1):
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


def image_lang_detector(image):
    data = pytesseract.image_to_data(
        image, output_type=pytesseract.Output.DICT)
    image_text_list = [word for word in data["text"] if word.strip()]
    if not image_text_list:
        raise ValueError("No text detected in the image.")
    full_text = " ".join(image_text_list)
    detected_lang = get_lang(full_text)
    logger.info(
        f"Detected image language: {detected_lang}\nImage text: {full_text}\n")
    return detected_lang
