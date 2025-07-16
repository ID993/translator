import speech_recognition as sr
from pydub import AudioSegment
from services.text_translate import translate_input_text
import logging


logger = logging.getLogger(__name__)


class SpeechRecognitionError(Exception):
    pass


r = sr.Recognizer()


def m4a_to_wav(audio_file):
    logger.info(f"\nRecieved audio file: {audio_file}\n")
    wav_audio_dir = "./uploads/audio/WAV/"
    path, file = audio_file.split('\\')
    sound = AudioSegment.from_file(audio_file, format="m4a")
    base, ext = file.split('.')
    wav_file_name = f"{base}.wav"
    wav_audio = sound.export(wav_audio_dir+wav_file_name, format="wav")
    return wav_audio


def extract_text_from_audio(audio_file, src_lang):
    r = sr.Recognizer()
    wav = m4a_to_wav(audio_file)
    with sr.AudioFile(wav) as source:
        audio_data = r.record(source)

    try:
        speech_to_text = r.recognize_google(audio_data, language=src_lang)
        speech_to_text = speech_to_text.lower()
        logger.info(f"Audio extraction text: {speech_to_text}\n")
        return speech_to_text
    except sr.UnknownValueError:
        logger.info("[ERROR] Could not understand the audio")
        raise SpeechRecognitionError("Could not understand the audio.")
    except sr.RequestError as e:
        logger.info(f"[ERROR] Google API request failed: {e}")
        raise SpeechRecognitionError("Speech recognition service failed.")


def translate_audio_file(audio_text, src_lang, tgt_lang, composite):
    translated_speech = translate_input_text(
        audio_text, src_lang, tgt_lang, composite)
    logger.info(translated_speech)
    return translated_speech
