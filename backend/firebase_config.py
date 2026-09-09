import os
from pathlib import Path

import firebase_admin
from dotenv import load_dotenv
from firebase_admin import auth, credentials


BACKEND_DIR = Path(__file__).resolve().parent
load_dotenv(BACKEND_DIR / ".env")

credentials_path = Path(
    os.getenv("FIREBASE_CREDENTIALS_PATH", "firebase-adminsdk.json")
)

if not credentials_path.is_absolute():
    credentials_path = BACKEND_DIR / credentials_path

try:
    firebase_admin.get_app()
except ValueError:
    cred = credentials.Certificate(str(credentials_path))
    firebase_admin.initialize_app(cred)