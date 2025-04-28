import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:logger/logger.dart';
import 'package:flutter_settings_screens/flutter_settings_screens.dart';

class TextTranslationScreen extends StatefulWidget {
  const TextTranslationScreen({super.key});

  @override
  State<TextTranslationScreen> createState() => _TextTranslationScreenState();
}

class _TextTranslationScreenState extends State<TextTranslationScreen> {
  bool _isLoading = false;
  final TextEditingController _inputController = TextEditingController();
  final TextEditingController _outputController = TextEditingController();
  String _translatedText = "";
  final List<String> _languages = ['hr', 'en', 'es', 'de', 'fr', 'nl', 'it'];
  var logger = Logger();
  String _sourceLang = 'hr';
  String _targetLang = 'en';

  final _baseUrl = dotenv.env['API_URL']!;

  final _model = Settings.getValue<String>("model_type", defaultValue: "ml");
  final detection =
      Settings.getValue<String>("detection_mode", defaultValue: "automatic");

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
    });
    try {
      logger.d(_baseUrl);
      var uri = Uri.parse("$_baseUrl/translate-text");
      Map<String, dynamic> payload = {
        'text': _inputController.text,
        'src_lang': _sourceLang,
        'tgt_lang': _targetLang,
        'model': _model,
      };

      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );

      if (response.statusCode == 200) {
        String translatedText = response.body;
        if (!mounted) return;
        setState(() {
          _translatedText = translatedText;
          _outputController.text = _translatedText;
        });
      } else {
        if (!mounted) return;
        logger.d("Translation failed with status: ${response.statusCode}");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text("Translation failed with status: ${response.statusCode}"),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      logger.d("Error during translation: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error during translation: $e"),
        ),
      );
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
    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        title: const Text("Translate Text"),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Column(
                    children: [
                      const Text("Source Language"),
                      DropdownButton<String>(
                        value: _sourceLang,
                        items: _languages
                            .map((lang) => DropdownMenuItem(
                                  value: lang,
                                  child: Text(lang.toUpperCase()),
                                ))
                            .toList(),
                        onChanged: (value) {
                          if (value != null) {
                            setState(() {
                              _sourceLang = value;
                            });
                            if (_inputController.text.isNotEmpty) {
                              _onInputChanged(_inputController.text);
                            }
                          }
                        },
                      ),
                    ],
                  ),
                  const SizedBox(width: 10),
                  IconButton(
                    icon: const Icon(Icons.swap_horiz),
                    onPressed: () async {
                      setState(() {
                        final temp = _sourceLang;
                        _sourceLang = _targetLang;
                        _targetLang = temp;
                      });
                      final text = _inputController.text;
                      if (text.isNotEmpty) {
                        _debounce?.cancel();
                        await _sendText();
                      }
                    },
                  ),
                  const SizedBox(width: 10),
                  Column(
                    children: [
                      const Text("Target Language"),
                      DropdownButton<String>(
                        value: _targetLang,
                        items: _languages
                            .map((lang) => DropdownMenuItem(
                                  value: lang,
                                  child: Text(lang.toUpperCase()),
                                ))
                            .toList(),
                        onChanged: (value) {
                          if (value != null) {
                            setState(() {
                              _targetLang = value;
                            });
                            if (_inputController.text.isNotEmpty) {
                              _onInputChanged(_inputController.text);
                            }
                          }
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
              child: TextField(
                controller: _inputController,
                onChanged: _onInputChanged,
                maxLines: 6,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: 'Enter text',
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
              child: TextField(
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
    );
  }
}
