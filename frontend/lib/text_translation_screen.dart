import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:logger/logger.dart';
import 'package:flutter_settings_screens/flutter_settings_screens.dart';
import './constants.dart';
import 'package:provider/provider.dart';
import './location_provider.dart';

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
    });
    try {
      logger.d("ENGMOD: ${engine}_:_$model");
      final composite = '${engine}_:_$model';
      logger.d("COMPOSITE: $composite");
      var uri = Uri.parse("$_baseUrl/translate-text");
      Map<String, dynamic> payload = {
        'text': _inputController.text,
        'src_lang': _sourceLang,
        'tgt_lang': _targetLang,
        'model': engine,
        'composite': composite,
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
