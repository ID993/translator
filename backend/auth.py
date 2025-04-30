# backend/auth.py
from functools import wraps
from flask import request, jsonify, g
from firebase_config import auth as firebase_auth  # your firebase_admin.auth


def firebase_required(f):
    @wraps(f)
    def wrapper(*args, **kwargs):

        auth_header = request.headers.get("Authorization")
        if not auth_header:
            return jsonify({"error": "Unauthorized"}), 401

        token = auth_header.replace("Bearer ", "")

        try:
            user_info = firebase_auth.verify_id_token(token)
        except Exception:
            return jsonify({"error": "Invalid token"}), 401

        g.user = user_info

        return f(*args, **kwargs)
    return wrapper
