from PIL import Image, ImageDraw, ImageFont, ImageFilter, ExifTags
import numpy as np
import easyocr
import pytesseract

ocr_reader = easyocr.Reader(['hr', 'en', 'es', 'de', 'fr', 'nl'], gpu=False)


def extract_word_boxes_easy_ocr(image):
    """
    Converts a PIL image to a NumPy array and runs OCR.
    Returns a list of tuples: (detected_text, (x, y, width, height))
    """
    image_np = np.array(image)
    results = ocr_reader.readtext(image_np)
    text_regions = []
    for res in results:
        word = res[1]  # Detected text
        bbox = res[0]  # Bounding box as list of 4 points
        if word.strip():
            # Use top-left and bottom-right points to calculate box dimensions.
            x, y = bbox[0]
            x2, y2 = bbox[2]
            text_regions.append((word, (x, y, x2 - x, y2 - y)))
    return text_regions


def extract_word_boxes_pytesseract(image):
    """
    Uses pytesseract to extract text and bounding boxes from a PIL image.
    Returns a list of tuples: (detected_text, (x, y, width, height))
    """
    data = pytesseract.image_to_data(
        image, output_type=pytesseract.Output.DICT)
    text_regions = []
    n_boxes = len(data['text'])
    for i in range(n_boxes):
        text = data['text'][i]
        if text.strip():
            x = data['left'][i]
            y = data['top'][i]
            w = data['width'][i]
            h = data['height'][i]
            text_regions.append((text, (x, y, w, h)))

    return text_regions


def group_boxes_to_lines(text_regions, y_threshold):
    """
    Groups individual OCR boxes (word-level) into lines (sentence-level) based on their y coordinate.
    text_regions: list of tuples (detected_text, (x, y, w, h))
    y_threshold: maximum difference in y to consider boxes as part of the same line.
    Returns a list of lines, where each line is a list of text_regions.
    """
    # Sort boxes by their y-coordinate (top of the box)
    text_regions.sort(key=lambda region: region[1][1])

    lines = []
    current_line = []
    current_y = None

    for region in text_regions:
        text, (x, y, w, h) = region
        if current_y is None:
            current_line.append(region)
            current_y = y
        else:
            if abs(y - current_y) < y_threshold:
                current_line.append(region)
            else:
                lines.append(current_line)
                current_line = [region]
                current_y = y
    if current_line:
        lines.append(current_line)

    return lines


def merge_line_boxes(line_regions):
    """
    Given a list of OCR regions (words) from one line, merge them into one bounding box.
    Returns a tuple: (merged_text, (x, y, merged_width, merged_height))
    """
    # Sort regions in the line by their x-coordinate.
    line_regions.sort(key=lambda region: region[1][0])
    texts = [region[0] for region in line_regions]
    merged_text = " ".join(texts)

    xs = [region[1][0] for region in line_regions]
    ys = [region[1][1] for region in line_regions]
    xws = [region[1][0] + region[1][2] for region in line_regions]
    yhs = [region[1][1] + region[1][3] for region in line_regions]

    x_min = min(xs)
    y_min = min(ys)
    x_max = max(xws)
    y_max = max(yhs)
    merged_box = (x_min, y_min, x_max - x_min, y_max - y_min)

    return merged_text, merged_box
