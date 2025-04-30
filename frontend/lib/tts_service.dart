import 'package:flutter_tts/flutter_tts.dart';
import 'package:logger/logger.dart';

class TtsService {
  final FlutterTts _tts = FlutterTts();

  List<String> _locales = [];
  var logger = Logger();

  TtsService() {
    _init();
    _tts.setSpeechRate(0.5);
    _tts.setPitch(1.0);
  }

  Future<void> _init() async {
    final langs = await _tts.getLanguages;
    if (langs != null) {
      _locales = List<String>.from(langs);
    }

    logger.d("Available TTS locales: $_locales");

    await _tts.setSpeechRate(0.5);
    await _tts.setPitch(1.0);
  }

  Future<void> speak(String text, String langCode) async {
    if (text.trim().isEmpty) return;

    await _tts.setLanguage(langCode);
    await _tts.stop();
    await _tts.speak(text);
  }

  Future<void> stop() => _tts.stop();
  void dispose() => _tts.stop();
}
