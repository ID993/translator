import os
from io import BytesIO
from PIL import Image, ImageDraw, ImageFont, ImageFilter, ExifTags
import torch
from services.openai_llm import openai_translation
from services.anthropic_llm import anthropic_translation
from services.ocr import extract_word_boxes_easy_ocr, extract_word_boxes_pytesseract, merge_line_boxes, group_boxes_to_lines
from models.models_registry import MODEL_REGISTRY, get_model, get_tokenizer
import pytesseract
from utils.lang_detector import get_lang
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


def translate_image_texts(texts, src_lang, tgt_lang, model_name):
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
    logger.info(
        f"\nTokenizer:\n{[tokenizer.decode(t, skip_special_tokens=True) for t in generated_tokens]}\n")
    return [tokenizer.decode(t, skip_special_tokens=True) for t in generated_tokens]


def get_font_size(translated_lines, merged_boxes):
    heights = []
    for (translated_text, box) in zip(translated_lines, merged_boxes):
        x, y, w, h = map(int, box)
        heights.append(h)

    font_size = int((sum(heights)/len(heights))*0.75)-15
    logger.info(f"\nFONT SIZE: {font_size}\n")
    return font_size


def erase_and_replace_text(image, src_lang, tgt_lang, composite):
    engine, model_name = composite.split('_:_')
    word_regions = extract_word_boxes_easy_ocr(image)
    # word_regions = extract_word_boxes_pytesseract(image)

    lines = group_boxes_to_lines(word_regions, y_threshold=30)

    line_texts = []
    merged_boxes = []
    for line in lines:
        merged_text, box = merge_line_boxes(line)
        line_texts.append(merged_text)
        merged_boxes.append(box)

    if not line_texts:
        raise ValueError("No text detected in image to translate.")

    translated_lines = []
    if engine == "ml":
        translated_lines = translate_image_texts(
            line_texts, src_lang, tgt_lang, model_name)
    elif engine == "llm" and model_name == "chatgpt":
        logger.info("\nUSING OPEN AI\n")
        translated_lines = openai_translation(line_texts, src_lang, tgt_lang)
    elif engine == "llm" and model_name == "claude":
        logger.info("\nUSING ANTHROPIC\n")
        translated_lines = anthropic_translation(
            line_texts, src_lang, tgt_lang)

    font_size = get_font_size(translated_lines, merged_boxes)

    white_image = image.copy()
    draw_white = ImageDraw.Draw(white_image)
    draw_white.rectangle([(0, 0), white_image.size], fill="white")

    draw = ImageDraw.Draw(image)
    for (translated_text, box) in zip(translated_lines, merged_boxes):
        x, y, w, h = map(int, box)
        region = image.crop((x, y, x + w, y + h))
        blurred_region = region.filter(
            ImageFilter.GaussianBlur(radius=30))  # 30
        image.paste(blurred_region, (x, y))

        font = ImageFont.truetype("arial.ttf", font_size)
        bbox_text = font.getbbox(translated_text)
        text_width = bbox_text[2] - bbox_text[0]
        text_height = bbox_text[3] - bbox_text[1]

        text_x = x  # + (w - text_width)
        text_y = y + (h - text_height) / 2

        draw.text((text_x, text_y), translated_text, fill="black", font=font)
        draw_white.text((text_x, text_y), translated_text,
                        fill="black", font=font)
    return image, white_image


def correct_image_orientation(image):
    try:
        exif = image._getexif()
        if exif is None:
            return image

        for orientation in ExifTags.TAGS.keys():
            if ExifTags.TAGS[orientation] == "Orientation":
                break
        exif_dict = dict(exif.items())
        orientation_value = exif_dict.get(orientation, None)
        logger.info(f"\nIMAGE ORIENTATION VALUE:\n{orientation_value}\n")
        if orientation_value == 3:
            image = image.rotate(180, expand=True)
        elif orientation_value == 6:
            image = image.rotate(270, expand=True)
        elif orientation_value == 8:
            image = image.rotate(90, expand=True)
    except Exception as e:
        logger.info("No EXIF orientation data or error:", e)
    return image


def translate_image_file(file, src_lang, tgt_lang, composite):

    image = file.convert("RGB")

    translated_image_original, translated_image_white = erase_and_replace_text(
        image, src_lang, tgt_lang, composite)

    img_io_original = BytesIO()
    img_io_white = BytesIO()
    translated_image_original.save(img_io_original, format="PNG")
    translated_image_white.save(img_io_white, format="PNG")
    img_io_original.seek(0)
    img_io_white.seek(0)
    return img_io_original, img_io_white
