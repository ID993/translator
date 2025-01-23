# Translator

Translator is a mobile application that allows users to:
- Take a picture or upload an image from the gallery to extract and translate text.
- Write or record text and get translations into the selected language.
- Display translated text over the original image.
- Select translation models and languages for more control.

This app is designed to simplify communication, making it ideal for travelers, students, and anyone needing fast and reliable translations.

## Features
- User authentication.
- OCR (Optical Character Recognition) for text extraction from images.
- Audio-to-text conversion and translation.
- Language detection and translation using Flask, ready-made translation models, and LLM APIs.
- Support for typed, audio, and image-based input.
- Temporary caching of translations for improved performance.

## Tech Stack
- **Frontend**: Flutter
- **Backend**: Flask
- **Authentication**: Firebase
- **APIs**: OpenAI, Firebase Firestore

## Getting Started
### Prerequisites
- Install [Flutter](https://flutter.dev/docs/get-started/install) and set it up.
- Install Python 3.9+ and Flask.
- Firebase account for authentication.

### Environment Variables
Create a `.env` file in the `backend` folder with the following:
- OPENAI_API_KEY=your_openai_key
- FIREBASE_CONFIG=your_firebase_config

### Setup
1. Clone the repository:
   - git clone https://github.com/ID993/translator.git
   - cd translator
2. Navigate to the frontend folder and run:
   - flutter pub get
   - flutter run
3. Navigate to the backend folder and run:
   - pip install -r requirements.txt
   - python app.py


