import os
from firebase_config import firebase_admin
from flask import Flask, request, jsonify, send_file, send_from_directory, g
from flask_cors import CORS
from firebase_admin import auth
from auth import firebase_required
from werkzeug.utils import secure_filename
from flask_caching import Cache
from PIL import Image
from services.image_translate import translate_image_file, correct_image_orientation
from services.audio_translate import translate_audio_file, extract_text_from_audio, SpeechRecognitionError
from services.text_translate import translate_input_text
from utils.hahsers import generate_image_cache_key, generate_audio_cache_key, generate_text_cache_key
from utils.lang_detector import get_lang, image_lang_detector

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
@firebase_required
def protected():
    data = request.headers.get("data")
    return jsonify({
        "message": "Access granted!",
        "user":    g.user,
        "data":    data
    }), 200


@app.route("/uploads/translate/<path:filename>")
def serve_translated(filename):
    return send_from_directory("uploads/translate", filename)


@app.route("/translate-image", methods=["POST"])
@firebase_required
def translate_image():
    try:
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

        # if no text raise exception or error
        detected = image_lang_detector(img)

        cache_key = generate_image_cache_key(original_path, src_lang, tgt_lang)
        cached_translation = cache.get(cache_key)
        if cached_translation:
            print(f"\nCache: {cached_translation}\n")
            return jsonify(cached_translation)

        org_io, wht_io = translate_image_file(
            img, src_lang, tgt_lang, composite)

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
        response = {
            "original_image_url": f"{public_base}/{org_name}",
            "white_image_url":    f"{public_base}/{wht_name}"
        }

        cache.set(cache_key, response, timeout=600)
        return jsonify(response)

    except ValueError as e:
        return jsonify({"error": str(e)}), 400
    except Exception as e:
        return jsonify({"error": "Internal server error"}), 500


@app.route("/translate-audio", methods=["POST", "GET"])
@firebase_required
def translate_audio():
    try:
        if "file" not in request.files:
            return jsonify({"error": "No file provided"}), 400

        file = request.files["file"]
        src_lang = request.form.get("src_lang", "hr")
        tgt_lang = request.form.get("tgt_lang", "en")
        composite = request.form.get("composite", "ml_facebook/m2m100_1.2B")
        force_flag = request.form.get("force", "0") == "1"

        original_audio_dir = "./audio_uploads/original"
        os.makedirs(original_audio_dir, exist_ok=True)
        base, ext = os.path.splitext(file.filename)
        original_audio_filename = f"{base}{ext}"
        original_audio_path = os.path.join(
            original_audio_dir, original_audio_filename)
        file.save(original_audio_path)

        audio_file = original_audio_path
        text = extract_text_from_audio(audio_file, src_lang)
        detected = get_lang(text)

        cache_key = generate_audio_cache_key(
            original_audio_path, src_lang, tgt_lang)

        cached_audio_translation = cache.get(cache_key)

        if cached_audio_translation:
            print(f"\nCache: {cached_audio_translation}\nDETECTED: {detected}")
            return jsonify({"translation": cached_audio_translation, "detected_lang": detected}), 200

        if not force_flag and detected != src_lang:
            return jsonify({"translation": "", "detected_lang": detected}), 200

        translated_audio_text = translate_audio_file(
            text, src_lang, tgt_lang, composite)
        cache.set(cache_key, translated_audio_text, timeout=600)
        return jsonify({"translation": translated_audio_text, "detected_lang": detected}), 200

    except SpeechRecognitionError as e:
        return jsonify({"error": str(e)}), 400


@app.route("/translate-text", methods=["POST", "GET"])
@firebase_required
def translate_text():
    data = request.get_json()
    print("Received JSON data:", data)

    if not data or "text" not in data:
        return jsonify({"error": "No text provided"}), 400

    text = data.get("text")
    src_lang = data.get("src_lang", "hr")
    tgt_lang = data.get("tgt_lang", "en")
    composite = data.get("composite", "ml_:_facebook/m2m100_1.2B")
    force_flag = data.get("force", "0")

    detected = get_lang(text)
    cache_key = generate_text_cache_key(text, src_lang, tgt_lang)
    cached_translation = cache.get(cache_key)
    if cached_translation:
        print(f"\nCache: {cached_translation}\n")
        return jsonify({"translation": cached_translation, "detected_lang": detected}), 200

    if not force_flag and detected != src_lang:
        return jsonify({"translation": "", "detected_lang": detected}), 200

    translated_text = translate_input_text(
        text, src_lang, tgt_lang, composite)
    cache.set(cache_key, translated_text, timeout=600)
    return jsonify({"translation": translated_text, "detected_lang": detected}), 200


if __name__ == "__main__":
    app.run(debug=True, host="0.0.0.0", port=5000)
