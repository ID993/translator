import 'dart:async';
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:logger/logger.dart';
import 'package:flutter_settings_screens/flutter_settings_screens.dart';
import './constants.dart';
import 'package:provider/provider.dart';
import './location_provider.dart';
import './lang_detector.dart';

const Map<String, String> _languagesNames = {
  'hr': 'Croatian',
  'en': 'English',
  'es': 'Spanish',
  'de': 'German',
  'fr': 'French',
  'nl': 'Dutch',
  'it': 'Italian',
};

class TextTranslationScreen extends StatefulWidget {
  const TextTranslationScreen({super.key});

  @override
  State<TextTranslationScreen> createState() => _TextTranslationScreenState();
}

class _TextTranslationScreenState extends State<TextTranslationScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  final TextEditingController _inputController = TextEditingController();
  final TextEditingController _outputController = TextEditingController();
  String _translatedText = "";
  final _languages = _languagesNames.keys.toList();
  var logger = Logger();
  String? _sourceLang;
  String? _targetLang;
  String? _suggestion;

  // final detector = LangDetector();
  //     final code = await detector.detectLang(_inputController.text);
  //     logger.d("CODE: $code");
  //     detector.close();

  final _baseUrl = dotenv.env['API_URL']!;

  final detection =
      Settings.getValue<String>("detection_mode", defaultValue: "automatic");

  String? get engine => Settings.getValue<String>(
        kModelTypeKey,
        defaultValue: 'ml',
      );

  String? get model => (engine == 'ml')
      ? Settings.getValue<String>(kMlModelKey,
          defaultValue: 'facebook/m2m100_1.2B')
      : Settings.getValue<String>(kLlmModelKey, defaultValue: 'chatgpt');

  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _inputController.dispose();
    _outputController.dispose();
    super.dispose();
  }

  Future<void> _sendText() async {
    setState(() {
      _isLoading = true;
      _suggestion = null;
    });

    final detectionMode = Settings.getValue<String>(
      "detection_mode",
      defaultValue: "automatic",
    );

    if (detectionMode == "automatic") {
      final input = _inputController.text.trim();
      if (input.isNotEmpty) {
        final detector = LangDetector();
        final code = await detector.detectLang(input);
        detector.close();

        logger.d("Auto-detected language = $code");

        if (code != _sourceLang && _languagesNames.containsKey(code)) {
          setState(() {
            _suggestion = code;
            _isLoading = false;
          });
          return;
        }
      }
    }

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception("Not signed in");
      }
      final idToken = await user.getIdToken();
      final composite = '${engine}_:_$model';
      final uri = Uri.parse("$_baseUrl/translate-text");
      final payload = {
        'text': _inputController.text,
        'src_lang': _sourceLang,
        'tgt_lang': _targetLang,
        'model': engine,
        'composite': composite,
      };

      final response = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $idToken',
        },
        body: jsonEncode(payload),
      );

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        if (body.containsKey('translation')) {
          setState(() {
            _translatedText = body['translation'] as String;
            _outputController.text = _translatedText;
            _suggestion = null;
          });
        }
      } else {
        logger.d("Translation failed (${response.statusCode})");
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Status ${response.statusCode}")),
          );
        }
      }
    } catch (e) {
      logger.d("Error during translation: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e")),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _onInputChanged(String text) {
    _debounce?.cancel();

    if (text.isEmpty) {
      setState(() {
        _translatedText = "";
        _outputController.text = "";
      });
      return;
    }

    _debounce = Timer(const Duration(milliseconds: 1000), () async {
      logger.d("Debounce timer fired; sending text.");
      await _sendText();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (detection == "location") {
      _sourceLang = Provider.of<LocationProvider>(context).language;
    }
    logger.d("LANG: $_sourceLang");
    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: AppBar(title: const Text("Translate Text")),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _sourceLang,
                        decoration: InputDecoration(
                          labelText: 'From',
                          border: OutlineInputBorder(),
                        ),
                        items: _languages.map((code) {
                          return DropdownMenuItem(
                            value: code,
                            child: Text(_languagesNames[code]!),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() => _sourceLang = value);
                          if (_inputController.text.isNotEmpty &&
                              _formKey.currentState!.validate()) {
                            _debounce?.cancel();
                            _onInputChanged(_inputController.text);
                          }
                        },
                        validator: (value) =>
                            value == null ? 'Please select' : null,
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.swap_horiz),
                      onPressed: () async {
                        setState(() {
                          final tmp = _sourceLang;
                          _sourceLang = _targetLang;
                          _targetLang = tmp;
                        });
                        final text = _inputController.text;
                        if (text.isNotEmpty &&
                            _formKey.currentState!.validate()) {
                          _debounce?.cancel();
                          await _sendText();
                        }
                      },
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _targetLang,
                        decoration: InputDecoration(
                          labelText: 'To',
                          border: OutlineInputBorder(),
                        ),
                        items: _languages.map((code) {
                          return DropdownMenuItem(
                            value: code,
                            child: Text(_languagesNames[code]!),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() => _targetLang = value);
                          if (_inputController.text.isNotEmpty &&
                              _formKey.currentState!.validate()) {
                            _debounce?.cancel();
                            _onInputChanged(_inputController.text);
                          }
                        },
                        validator: (value) =>
                            value == null ? 'Please select' : null,
                      ),
                    ),
                  ],
                ),
              ),
              if (_suggestion != null && _languagesNames[_suggestion!] != null)
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Text(
                    "Did you mean ${_languagesNames[_suggestion!]}?",
                    style: const TextStyle(color: Colors.orange, fontSize: 14),
                  ),
                ),
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
                child: TextFormField(
                  controller: _inputController,
                  maxLines: 6,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    hintText: 'Enter text',
                  ),
                  onChanged: (text) {
                    if (_formKey.currentState!.validate()) {
                      _debounce?.cancel();
                      _onInputChanged(text);
                    }
                  },
                ),
              ),
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
                child: TextFormField(
                  controller: _outputController,
                  readOnly: true,
                  maxLines: 6,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    hintText: 'Translated text appears here',
                  ),
                ),
              ),
              if (_isLoading) const Center(child: CircularProgressIndicator()),
            ],
          ),
        ),
      ),
    );
  }
}
