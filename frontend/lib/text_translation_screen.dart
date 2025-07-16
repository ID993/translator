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
  final _languages = _languagesNames.keys.toList(); //fastTextLangNames

  var logger = Logger();
  String? _sourceLang;
  String? _targetLang;
  String? _suggestion;
  bool force = false;

  final _baseUrl = dotenv.env['API_URL']!;

  final detection =
      Settings.getValue<String>("detection_mode", defaultValue: "no_location");

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
    if (_sourceLang == _targetLang) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text("Source and target languages must be different.")),
      );
      return;
    }
    setState(() {
      _isLoading = true;
      _suggestion = null;
    });

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
        'composite': composite,
        'force': force
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
        setState(() {
          _translatedText = body['translation'] as String;
          if (force) {
            _suggestion = null;
          } else {
            _suggestion = body['detected_lang'] as String;
          }
          _outputController.text = _translatedText;
        });
      } else {
        String errorMessage;
        try {
          final body = jsonDecode(response.body);
          errorMessage = body['error'] as String? ?? 'Unknown error';
        } catch (_) {
          errorMessage = 'Error ${response.statusCode}';
        }

        logger.d("Translation failed (${response.statusCode}): $errorMessage");
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(errorMessage)),
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
    force = false;
    if (text.isEmpty) {
      setState(() {
        _translatedText = "";
        _outputController.text = "";
        _suggestion = null;
      });
      return;
    }

    _debounce = Timer(const Duration(milliseconds: 1000), () async {
      logger.d("Debounce timer fired; sending text.");
      await _sendText();
    });
  }

  void _showUnsupportedDialog(String code) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Unsupported language"),
        content:
            Text("${fastTextLangNames[code] ?? code} isn't in supported list. "
                "Please choose a language from the dropdown first."),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text("OK"),
          )
        ],
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    if (detection == "location") {
      final localLang =
          Provider.of<LocationProvider>(context, listen: false).language;
      _sourceLang = localLang;
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isSupported(String code) => _languagesNames.containsKey(code);
    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: AppBar(title: const Text("Translate Text")),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.only(bottom: 16.0),
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
                          setState(() {
                            _sourceLang = value;
                            force = false;
                          });
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
                    const SizedBox(width: 12),
                    Column(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.swap_horiz),
                          onPressed: () async {
                            setState(() {
                              final tmp = _sourceLang;
                              _sourceLang = _targetLang;
                              _targetLang = tmp;
                              force = false;
                            });
                            final text = _inputController.text;
                            if (text.isNotEmpty &&
                                _formKey.currentState!.validate()) {
                              _debounce?.cancel();
                              await _sendText();
                            }
                          },
                        ),
                      ],
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _targetLang,
                        decoration: InputDecoration(
                          labelText: 'To',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(
                              horizontal: 12, vertical: 14),
                        ),
                        items: _languages.map((code) {
                          return DropdownMenuItem(
                            value: code,
                            child: Text(_languagesNames[code]!),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            _targetLang = value;
                          });
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
              if (_suggestion != null &&
                  _sourceLang != null &&
                  _suggestion != _sourceLang)
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: (0.1 * 255)),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Detected language: ${fastTextLangNames[_suggestion]}.",
                        style: TextStyle(
                            color: Colors.orange, fontWeight: FontWeight.w600),
                      ),
                      SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          ElevatedButton.icon(
                            onPressed: () {
                              final cand = _suggestion!;
                              if (!isSupported(cand)) {
                                _showUnsupportedDialog(cand);
                                return;
                              }
                              setState(() {
                                _sourceLang = cand;
                                _suggestion = null;
                                force = false;
                              });
                              _sendText();
                            },
                            icon: const Icon(Icons.check),
                            label: Text(
                              "Use ${fastTextLangNames[_suggestion]}",
                              style: TextStyle(fontSize: 14),
                            ),
                          ),
                          TextButton.icon(
                            onPressed: () {
                              final keep = _sourceLang!;
                              if (!isSupported(keep)) {
                                _showUnsupportedDialog(keep);
                                return;
                              }
                              setState(() {
                                _suggestion = null;
                                force = true;
                              });
                              _sendText();
                            },
                            icon: const Icon(Icons.block),
                            label: Text(
                              "Keep ${fastTextLangNames[_sourceLang]}",
                              style: TextStyle(fontSize: 14),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 10),
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
