import speech_recognition as sr
from pydub import AudioSegment
from services.text_translate import translate_input_text


r = sr.Recognizer()


def m4a_to_wav(audio_file):
    print(f"\nRECIEVED AUDIO FILE: {audio_file}\n")
    wav_audio_dir = "./audio_uploads/WAV/"
    path, file = audio_file.split('\\')
    sound = AudioSegment.from_file(audio_file, format="m4a")
    base, ext = file.split('.')
    wav_file_name = f"{base}.wav"
    wav_audio = sound.export(wav_audio_dir+wav_file_name, format="wav")
    return wav_audio


def extract_text_from_audio(audio_file, src_lang):
    wav = m4a_to_wav(audio_file)
    with sr.AudioFile(wav) as source:
        audio_data = r.record(source)
    speech_to_text = r.recognize_google(audio_data, language=src_lang)
    speech_to_text = speech_to_text.lower()
    print(f"\nTHIS IS EXTRACTION TEXT: {speech_to_text}\n")
    return speech_to_text


def translate_audio_file(audio_text, src_lang, tgt_lang, composite):
    translated_speech = translate_input_text(
        audio_text, src_lang, tgt_lang, composite)
    print(translated_speech)
    return translated_speech
