import os
from io import BytesIO
from PIL import Image, ImageDraw, ImageFont, ImageFilter, ExifTags
import torch
from services.llm_translate import llm_translation
from services.ocr import extract_word_boxes_easy_ocr, extract_word_boxes_pytesseract, merge_line_boxes, group_boxes_to_lines
from models.m2m100 import get_model, get_tokenizer


model = get_model()
tokenizer = get_tokenizer()


def translate_image_texts(texts, src_lang, tgt_lang):
    tokenizer.src_lang = src_lang
    inputs = tokenizer(texts, return_tensors="pt",
                       padding=True, truncation=True)
    tgt_lang_id = tokenizer.get_lang_id(tgt_lang)
    with torch.no_grad():
        generated_tokens = model.generate(
            **inputs, forced_bos_token_id=tgt_lang_id)
    print(
        f"\nTokenizer:\n{[tokenizer.decode(t, skip_special_tokens=True) for t in generated_tokens]}\n")
    print(
        f"\n{len([tokenizer.decode(t, skip_special_tokens=True) for t in generated_tokens])}\n")
    return [tokenizer.decode(t, skip_special_tokens=True) for t in generated_tokens]


def erase_and_replace_text(image, src_lang, tgt_lang, model):
    # word_regions = extract_word_boxes_easy_ocr(image)
    word_regions = extract_word_boxes_pytesseract(image)

    lines = group_boxes_to_lines(word_regions, y_threshold=30)

    line_texts = []
    merged_boxes = []
    for line in lines:
        merged_text, box = merge_line_boxes(line)
        line_texts.append(merged_text)
        merged_boxes.append(box)

    translated_lines = []
    if model == "ml":
        print("\nUSING MACHINE LEARNING\n")
        translated_lines = translate_image_texts(
            line_texts, src_lang, tgt_lang)
    elif model == "llm":
        print("\nUSING LONG LANGUAGE MODEL\n")
        translated_lines = llm_translation(line_texts, src_lang, tgt_lang)

    draw = ImageDraw.Draw(image)
    for (translated_text, box) in zip(translated_lines, merged_boxes):
        x, y, w, h = map(int, box)
        region = image.crop((x, y, x + w, y + h))
        blurred_region = region.filter(ImageFilter.GaussianBlur(radius=15))
        image.paste(blurred_region, (x, y))

        font_size = max(10, int(h))

        font_path = "arial.ttf"
        # if os.path.exists(font_path):
        #     print("font exists")
        #     font = ImageFont.truetype(font_path, font_size)
        # else:
        #     print("font not exists")
        #     font = ImageFont.load_default(size=24)

        font = ImageFont.truetype(font_path, font_size)
        bbox_text = font.getbbox(translated_text)
        text_width = bbox_text[2] - bbox_text[0]
        text_height = bbox_text[3] - bbox_text[1]

        text_x = x  # + (w - text_width)
        text_y = y + (h - text_height) / 2

        draw.text((text_x, text_y), translated_text, fill="black", font=font)

    return image


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
        print(f"\nIMAGE ORIENTATION VALUE:\n{orientation_value}\n")
        if orientation_value == 3:
            image = image.rotate(180, expand=True)
        elif orientation_value == 6:
            image = image.rotate(270, expand=True)
        elif orientation_value == 8:
            image = image.rotate(90, expand=True)
    except Exception as e:
        print("No EXIF orientation data or error:", e)
    return image


def translate_image_file(file, src_lang, tgt_lang, model):

    image = file.convert("RGB")

    translated_image = erase_and_replace_text(image, src_lang, tgt_lang, model)

    img_io = BytesIO()
    translated_image.save(img_io, format="PNG")
    img_io.seek(0)
    return img_io


# def translate_input_text(text, src_lang, tgt_lang):
#     tokenizer.src_lang = src_lang
#     inputs = tokenizer(text, return_tensors="pt",
#                        padding=True, truncation=True)
#     tgt_lang_id = tokenizer.get_lang_id(tgt_lang)
#     with torch.no_grad():
#         generated_tokens = model.generate(
#             **inputs,
#             forced_bos_token_id=tgt_lang_id,
#             max_length=256,
#             num_beams=5,
#             early_stopping=True
#         )
#     return tokenizer.decode(generated_tokens[0], skip_special_tokens=True)
