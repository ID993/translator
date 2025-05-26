import 'dart:io';
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:logger/web.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:logger/logger.dart';
import 'package:flutter_settings_screens/flutter_settings_screens.dart';
import './constants.dart';
import 'package:provider/provider.dart';
import './location_provider.dart';
import './tts_service.dart';

const Map<String, String> _languagesNames = {
  'hr': 'Croatian',
  'en': 'English',
  'es': 'Spanish',
  'de': 'German',
  'fr': 'French',
  'nl': 'Dutch',
  'it': 'Italian',
};

class VoiceRecordingScreen extends StatefulWidget {
  const VoiceRecordingScreen({super.key});

  @override
  State<VoiceRecordingScreen> createState() => _VoiceRecordingScreenState();
}

class _VoiceRecordingScreenState extends State<VoiceRecordingScreen> {
  final _formKey = GlobalKey<FormState>();
  final AudioRecorder _recorder = AudioRecorder();
  final AudioPlayer _audioPlayer = AudioPlayer();
  var logger = Logger();
  String? _recordFilePath;
  //File? _audioFile;
  bool _isRecording = false;
  bool _isPlaying = false;
  bool _isLoading = false;
  String? _translatedAudioTtx;
  late final TtsService _ttsService;
  String? _playbackLang;
  String? _suggestion;
  bool force = false;

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
  final _languages = _languagesNames.keys.toList();

  String? _sourceLang;
  String? _targetLang;

  final _baseUrl = dotenv.env['API_URL']!;

  Future<void> _startRecording() async {
    if (await _recorder.hasPermission()) {
      Directory tempDir = await getTemporaryDirectory();
      String filePath =
          '${tempDir.path}/recording_${DateTime.now().millisecondsSinceEpoch}.m4a';
      await _recorder.start(const RecordConfig(), path: filePath);
      if (!mounted) return;
      setState(() {
        _isRecording = true;
        _recordFilePath = filePath;
      });
    }
  }

  Future<void> _stopRecording() async {
    String? recordedPath = await _recorder.stop();
    if (!mounted) return;
    setState(() {
      _isRecording = false;
      _recordFilePath = recordedPath;
    });
  }

  // Future<void> _cancelRecording() async {
  //   await _recorder.cancel();
  //   if (!mounted) return;
  //   setState(() {
  //     _isRecording = false;
  //     _recordFilePath = null;
  //   });
  // }

  Future<void> _playRecording() async {
    if (_recordFilePath != null) {
      if (!mounted) return;
      setState(() {
        _isPlaying = true;
      });
      await _audioPlayer.play(DeviceFileSource(_recordFilePath!));
      _audioPlayer.onPlayerComplete.listen((event) {
        if (!mounted) return;
        setState(() {
          _isPlaying = false;
        });
      });
    }
  }

  Future<void> _deleteRecording() async {
    if (_recordFilePath != null) {
      File(_recordFilePath!).deleteSync();
      if (!mounted) return;
      setState(() {
        _recordFilePath = null;
        _translatedAudioTtx = null;
        _suggestion = null;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _ttsService = TtsService();
    if (detection == "location") {
      final localLang =
          Provider.of<LocationProvider>(context, listen: false).language;
      _sourceLang = localLang;
    }
  }

  @override
  void dispose() {
    _ttsService.dispose();
    _recorder.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _sendRecording() async {
    logger.d("SRC: $_sourceLang, TGT: $_targetLang");
    logger.d("SUGG: $_suggestion");
    logger.d("FORCE: $force");
    if (_recordFilePath == null) return;
    if (_sourceLang == _targetLang) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text("Source and target languages must be different.")),
      );
      return;
    }
    setState(() {
      _isLoading = true;
      //_suggestion = null;
    });
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception("Not signed in");
      }
      final idToken = await user.getIdToken();
      final composite = '${engine}_:_$model';
      logger.d("COMPOSITE: $composite");
      var uri = Uri.parse("$_baseUrl/translate-audio");
      var request = http.MultipartRequest('POST', uri)
        ..headers['Authorization'] = 'Bearer $idToken';

      request.files
          .add(await http.MultipartFile.fromPath('file', _recordFilePath!));
      request.fields['src_lang'] = _sourceLang!;
      request.fields['tgt_lang'] = _targetLang!;
      request.fields['composite'] = composite;
      request.fields['force'] = force ? '1' : '0';

      var response = await request.send();
      final responseString = await response.stream.bytesToString();
      if (response.statusCode == 200) {
        final body = jsonDecode(responseString);
        setState(() {
          if (force) {
            _suggestion = null;
          } else {
            _suggestion = body['detected_lang'] as String;
          }
          _translatedAudioTtx = body['translation'] as String;
          _playbackLang = _targetLang;
        });
        logger.d("DETECTED LANG: $_suggestion");
      } else {
        if (!mounted) return;
        String errorMessage;
        try {
          final errorJson = jsonDecode(responseString);
          errorMessage = errorJson['error'] ??
              "Translation failed with status: ${response.statusCode}";
        } catch (_) {
          errorMessage =
              "Translation failed with status: ${response.statusCode}";
        }
        logger.d("Translation failed: $errorMessage");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMessage)),
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
  Widget build(BuildContext context) {
    bool isSupported(String code) => _languagesNames.containsKey(code);
    String statusText;
    TextStyle statusStyle;
    if (_isRecording) {
      statusText = "Recording...";
      statusStyle = const TextStyle(
          fontSize: 16, fontWeight: FontWeight.bold, color: Colors.red);
    } else if (_recordFilePath != null) {
      statusText = "Recording available";
      statusStyle = const TextStyle(
          fontSize: 16, fontWeight: FontWeight.bold, color: Colors.green);
    } else {
      statusText = "No recording";
      statusStyle = const TextStyle(fontSize: 16);
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Voice Recorder')),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 16.0),
                child: Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _sourceLang,
                        decoration: const InputDecoration(
                          labelText: 'From',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(
                              horizontal: 12, vertical: 14),
                        ),
                        items: _languages
                            .map((code) => DropdownMenuItem(
                                  value: code,
                                  child: Text(_languagesNames[code]!),
                                ))
                            .toList(),
                        onChanged: (v) => setState(() {
                          _sourceLang = v;
                          force = false;
                        }),
                        validator: (v) => v == null ? 'Please select' : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.swap_horiz),
                          tooltip: "Swap languages",
                          onPressed: () async {
                            if (_formKey.currentState!.validate()) {
                              setState(() {
                                final tmp = _sourceLang;
                                _sourceLang = _targetLang;
                                _targetLang = tmp;
                                force = false;
                              });
                              await _sendRecording();
                            }
                          },
                        ),
                      ],
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _targetLang,
                        decoration: const InputDecoration(
                          labelText: 'To',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(
                              horizontal: 12, vertical: 14),
                        ),
                        items: _languages
                            .map((code) => DropdownMenuItem(
                                  value: code,
                                  child: Text(_languagesNames[code]!),
                                ))
                            .toList(),
                        onChanged: (v) => setState(() {
                          _targetLang = v;
                        }),
                        validator: (v) => v == null ? 'Please select' : null,
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
                        "Detected language: ${fastTextLangNames[_suggestion]}",
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
                                _translatedAudioTtx = null;
                              });
                              _sendRecording();
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
                                  _translatedAudioTtx = null;
                                  force = true;
                                });
                                _sendRecording();
                              },
                              icon: const Icon(Icons.block),
                              label: Text(
                                "Keep ${fastTextLangNames[_sourceLang]}",
                                style: TextStyle(
                                  fontSize: 14,
                                ),
                              )),
                        ],
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: 10),
              Text(
                statusText,
                textAlign: TextAlign.center,
                style: statusStyle,
              ),
              const SizedBox(height: 8),
              // if (_translatedAudioTtx != null && _translatedAudioTtx != "")
              if (_translatedAudioTtx?.isNotEmpty == true)
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("Translation:",
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              _translatedAudioTtx!,
                              style: const TextStyle(
                                  fontSize: 18, fontStyle: FontStyle.italic),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.volume_up),
                            tooltip: "Play translation",
                            onPressed: () {
                              _ttsService.speak(
                                  _translatedAudioTtx!, _playbackLang!);
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: 20),
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (!_isRecording && _recordFilePath == null)
                    ElevatedButton.icon(
                      icon: const Icon(Icons.fiber_manual_record),
                      label: const Text("Start Recording"),
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.redAccent),
                      onPressed: _startRecording,
                    ),
                  if (_isRecording)
                    ElevatedButton.icon(
                      icon: const Icon(Icons.stop),
                      label: const Text("Stop Recording"),
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orangeAccent),
                      onPressed: _stopRecording,
                    ),
                  if (_recordFilePath != null && !_isRecording) ...[
                    ElevatedButton.icon(
                      icon: Icon(_isPlaying ? Icons.pause : Icons.play_arrow),
                      label: Text(_isPlaying ? "Playing..." : "Play Recording"),
                      onPressed: _isPlaying ? null : _playRecording,
                    ),
                    const SizedBox(height: 10),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.delete),
                      label: const Text("Delete Recording"),
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey.shade300),
                      onPressed: _deleteRecording,
                    ),
                    const SizedBox(height: 10),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.send),
                      label: const Text("Send for Translation"),
                      style: ElevatedButton.styleFrom(
                          backgroundColor:
                              const Color.fromARGB(255, 78, 123, 199)),
                      onPressed: () {
                        if (_formKey.currentState!.validate()) {
                          _sendRecording();
                        }
                      },
                    ),
                  ],
                ],
              ),

              const SizedBox(height: 20),
              if (_isLoading) const Center(child: CircularProgressIndicator()),
            ],
          ),
        ),
      ),
    );
  }
}
