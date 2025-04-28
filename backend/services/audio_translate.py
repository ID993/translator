import speech_recognition as sr
from pydub import AudioSegment
from services.text_translate import translate_input_text

r = sr.Recognizer()


def extract_text_from_audio(audio_file, src_lang):
    with sr.AudioFile(audio_file) as source:
        audio_data = r.record(source)
    speech_to_text = r.recognize_google(audio_data, language=src_lang)
    speech_to_text = speech_to_text.lower()
    print(f"\nTHIS IS EXTRACTION TEXT: {speech_to_text}\n")
    return speech_to_text


def translate_audio_file(audio_file, src_lang, tgt_lang, model_name):
    print(f"\nRECIEVED AUDIO FILE: {audio_file}\n")
    wav_audio_dir = "./audio_uploads/WAV/"

    path, file = audio_file.split('\\')

    sound = AudioSegment.from_file(audio_file, format="m4a")
    base, ext = file.split('.')
    wav_file_name = f"{base}.wav"
    wav_audio = sound.export(wav_audio_dir+wav_file_name, format="wav")

    audio_text = extract_text_from_audio(wav_audio, src_lang)
    translated_speech = translate_input_text(
        audio_text, src_lang, tgt_lang, model_name)
    print(translated_speech)
    return translated_speech
