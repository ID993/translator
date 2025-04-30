import 'package:google_mlkit_language_id/google_mlkit_language_id.dart';

class LangDetector {
  final _identifier = LanguageIdentifier(confidenceThreshold: 0.1);

  Future<String> detectLang(String text) async {
    try {
      return await _identifier.identifyLanguage(text);
    } on Exception {
      return 'und';
    }
  }

  void close() => _identifier.close();
}
