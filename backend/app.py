import os
from firebase_config import firebase_admin
from flask import Flask, request, jsonify, send_file, send_from_directory
from flask_cors import CORS
from firebase_admin import auth
from werkzeug.utils import secure_filename
from flask_caching import Cache
from PIL import Image
from services.image_translate import translate_image_file, correct_image_orientation
from services.audio_translate import translate_audio_file
from services.text_translate import translate_input_text
from utils.hahsers import generate_image_cache_key, generate_audio_cache_key, generate_text_cache_key

app = Flask(__name__)
CORS(app)

UPLOAD_FOLDER = "./uploads"
ORIGINAL_DIR = "./uploads/original"
TRANSLATED_DIR = "./uploads/translate"
app.config["UPLOAD_FOLDER"] = UPLOAD_FOLDER
app.config["ORIGINAL_DIR"] = ORIGINAL_DIR
app.config["TRANSLATED_DIR"] = TRANSLATED_DIR
cache = Cache(app, config={"CACHE_TYPE": "SimpleCache"})


def verify_firebase_token(token):
    try:
        decoded_token = auth.verify_id_token(token)
        return decoded_token
    except Exception as e:
        return None


@app.route("/")
def home():
    return "Backend is set up and running!"


@app.route("/protected", methods=["GET"])
def protected():
    token = request.headers.get("Authorization")
    data = request.headers.get("data")

    if not token:
        return jsonify({"error": "Unauthorized"}), 401

    token = token.replace("Bearer ", "")
    user_info = verify_firebase_token(token)

    if not user_info:
        return jsonify({"error": "Invalid token"}), 401

    return jsonify({"message": "Access granted!", "user": user_info, "data": data}), 200


@app.route("/upload", methods=["GET", "POST"])
def upload():
    token = request.headers.get("Authorization")

    if not token:
        return jsonify({"error": "Unauthorized"}), 401

    if "file" not in request.files:
        return jsonify({"error": "No file provided"}), 400

    file = request.files["file"]
    if file.filename == "":
        return jsonify({"error": "No selected file"}), 400

    filename = secure_filename(file.filename)
    filepath = os.path.join(app.config["UPLOAD_FOLDER"], filename)
    file.save(filepath)

    return jsonify({"message": "File uploaded successfully", "filename": filename})


@app.route("/uploads/translate/<path:filename>")
def serve_translated(filename):
    return send_from_directory("uploads/translate", filename)


@app.route("/translate-image", methods=["POST"])
def translate_image():
    if "file" not in request.files:
        return jsonify({"error": "No file provided"}), 400

    file = request.files["file"]
    src_lang = request.form.get("src_lang", "hr")
    tgt_lang = request.form.get("tgt_lang", "en")
    composite = request.form.get("composite", "ml_facebook/m2m100_1.2B")

    original_dir = "./uploads/original"
    os.makedirs(original_dir, exist_ok=True)
    base, ext = os.path.splitext(file.filename)
    original_path = os.path.join(original_dir, file.filename)
    file.save(original_path)

    img = Image.open(original_path)
    img = correct_image_orientation(img)

    cache_key = generate_image_cache_key(original_path, src_lang, tgt_lang)
    cached_translation = cache.get(cache_key)
    if cached_translation:
        print(f"\nCache: {cached_translation}\n")
        return jsonify(cached_translation)

    org_io, wht_io = translate_image_file(img, src_lang, tgt_lang, composite)

    out_dir = "./uploads/translate"
    os.makedirs(out_dir, exist_ok=True)
    org_name = f"{base}_translated_org_{src_lang}-{tgt_lang}.png"
    wht_name = f"{base}_translated_wht_{src_lang}-{tgt_lang}.png"
    org_path = os.path.join(out_dir, org_name)
    wht_path = os.path.join(out_dir, wht_name)

    with open(org_path, "wb") as f:
        f.write(org_io.getbuffer())
    with open(wht_path, "wb") as f:
        f.write(wht_io.getbuffer())

    public_base = request.url_root.rstrip("/") + "/uploads/translate"
    resp = {
        "original_image_url": f"{public_base}/{org_name}",
        "white_image_url":    f"{public_base}/{wht_name}"
    }

    cache.set(cache_key, resp, timeout=6)

    return jsonify(resp)

# @app.route("/translate-image", methods=["POST", ])
# def translate_image():
#     if "file" not in request.files:
#         return jsonify({"error": "No file provided"}), 400

#     file = request.files["file"]
#     src_lang = request.form.get("src_lang", "hr")
#     tgt_lang = request.form.get("tgt_lang", "en")
#     model = request.form.get("model", "ml")

#     original_dir = "./uploads/original"
#     os.makedirs(original_dir, exist_ok=True)
#     base, ext = os.path.splitext(file.filename)
#     original_filename = f"{base}{ext}"
#     original_path = os.path.join(original_dir, original_filename)
#     file.save(original_path)

#     image = Image.open(original_path)

#     corrected_image = correct_image_orientation(image)
#     cache_key = generate_image_cache_key(original_path, src_lang, tgt_lang)

#     cached_translation = cache.get(cache_key)
#     if cached_translation:
#         print(f"\nCache: {cached_translation}\n")
#         return send_file(cached_translation, mimetype="image/png")

#     translated_img_io = translate_image_file(
#         corrected_image, src_lang, tgt_lang, model)

#     base, ext = os.path.splitext(file.filename)
#     output_dir = "./uploads/translate"
#     os.makedirs(output_dir, exist_ok=True)
#     output_filename = f"{base}_translated_{src_lang}-{tgt_lang}{ext}"
#     output_path = os.path.join(output_dir, output_filename)

#     with open(output_path, "wb") as out_file:
#         out_file.write(translated_img_io[0].getbuffer())

#     cache.set(cache_key, output_path, timeout=6)

#     return send_file(output_path, mimetype="image/png")


@app.route("/translate-audio", methods=["POST", "GET"])
def translate_audio():

    if "file" not in request.files:
        return jsonify({"error": "No file provided"}), 400

    file = request.files["file"]
    src_lang = request.form.get("src_lang", "hr")
    tgt_lang = request.form.get("tgt_lang", "en")
    composite = request.form.get("composite", "ml_facebook/m2m100_1.2B")

    original_audio_dir = "./audio_uploads/original"
    os.makedirs(original_audio_dir, exist_ok=True)
    base, ext = os.path.splitext(file.filename)
    original_audio_filename = f"{base}{ext}"
    original_audio_path = os.path.join(
        original_audio_dir, original_audio_filename)
    file.save(original_audio_path)

    cache_key = generate_audio_cache_key(
        original_audio_path, src_lang, tgt_lang)

    audio_file = original_audio_path

    cached_audio_translation = cache.get(cache_key)
    if cached_audio_translation:
        print(f"\nCache: {cached_audio_translation}\n")
        return cached_audio_translation

    translated_audio_text = translate_audio_file(
        audio_file, src_lang, tgt_lang, composite)

    # base, ext = os.path.splitext(file.filename)
    # output_dir = "./audio_uploads/translate"
    # os.makedirs(output_dir, exist_ok=True)
    # output_filename = f"{base}_translated_{src_lang}-{tgt_lang}{ext}"
    # output_path = os.path.join(output_dir, output_filename)

    # with open(output_path, "wb") as out_file:
    #     out_file.write(translated_audio_io.getbuffer())

    cache.set(cache_key, translated_audio_text, timeout=600)

    # return send_file(output_path, mimetype="audio/mp4")
    return translated_audio_text


@app.route("/translate-text", methods=["POST", "GET"])
def translate_text():
    data = request.get_json()
    print("Received JSON data:", data)

    if not data or "text" not in data:
        return jsonify({"error": "No text provided"}), 400

    text = data.get("text")
    src_lang = data.get("src_lang", "hr")
    tgt_lang = data.get("tgt_lang", "en")
    composite = data.get("composite", "ml_:_facebook/m2m100_1.2B")

    cache_key = generate_text_cache_key(text, src_lang, tgt_lang)

    cached_translation = cache.get(cache_key)
    if cached_translation:
        print(f"\nCache: {cached_translation}\n")
        return cached_translation

    translated_text = translate_input_text(
        text, src_lang, tgt_lang, composite)
    cache.set(cache_key, translated_text, timeout=600)

    return translated_text


if __name__ == "__main__":
    app.run(debug=True, host="0.0.0.0", port=5000)
