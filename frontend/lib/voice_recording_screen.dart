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
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _ttsService = TtsService();
  }

  @override
  void dispose() {
    _ttsService.dispose();
    _recorder.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _sendRecording() async {
    if (_recordFilePath == null) return;
    setState(() {
      _isLoading = true;
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

      var response = await request.send();
      if (response.statusCode == 200) {
        final body = jsonDecode(await response.stream.bytesToString());
        if (body.containsKey('detected_lang')) {
          setState(() {
            _suggestion = body['detected_lang'] as String;
            _translatedAudioTtx = null;
            _playbackLang = null;
          });
        } else if (body.containsKey('translation')) {
          setState(() {
            _translatedAudioTtx = body['translation'] as String;
            _playbackLang = _targetLang;
            _suggestion = null;
          });
        }
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

  @override
  Widget build(BuildContext context) {
    if (detection == "location") {
      _sourceLang = Provider.of<LocationProvider>(context).language;
    }
    logger.d("LANG: $_sourceLang");
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
                padding: const EdgeInsets.symmetric(vertical: 8.0),
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
                        onChanged: (v) => setState(() => _sourceLang = v),
                        validator: (v) => v == null ? 'Please select' : null,
                      ),
                    ),
                    const SizedBox(width: 10),
                    IconButton(
                      icon: const Icon(Icons.swap_horiz),
                      onPressed: () async {
                        if (_formKey.currentState!.validate()) {
                          setState(() {
                            final tmp = _sourceLang;
                            _sourceLang = _targetLang;
                            _targetLang = tmp;
                          });
                          await _sendRecording();
                        }
                      },
                    ),
                    const SizedBox(width: 10),
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
                        onChanged: (v) => setState(() => _targetLang = v),
                        validator: (v) => v == null ? 'Please select' : null,
                      ),
                    ),
                  ],
                ),
              ),
              if (_suggestion != null)
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Text(
                    "Did you mean ${_languagesNames[_suggestion!]}?",
                    style: const TextStyle(color: Colors.orange, fontSize: 14),
                  ),
                ),
              const SizedBox(height: 20),
              Text(
                statusText,
                textAlign: TextAlign.center,
                style: statusStyle,
              ),
              const SizedBox(height: 8),
              if (_translatedAudioTtx != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Text(
                          "Translation:\n$_translatedAudioTtx",
                          style: const TextStyle(
                              fontSize: 18, fontStyle: FontStyle.italic),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.volume_up),
                        onPressed: (_translatedAudioTtx != null &&
                                _playbackLang != null)
                            ? () {
                                _ttsService.speak(
                                  _translatedAudioTtx!,
                                  _playbackLang!,
                                );
                              }
                            : null,
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 20),
              if (!_isRecording && _recordFilePath == null)
                ElevatedButton(
                  onPressed: _startRecording,
                  child: const Text("Start Recording"),
                ),
              if (_isRecording)
                ElevatedButton(
                  onPressed: _stopRecording,
                  child: const Text("Stop Recording"),
                ),
              if (_recordFilePath != null && !_isRecording) ...[
                ElevatedButton(
                  onPressed: _isPlaying ? null : _playRecording,
                  child: const Text("Play Recording"),
                ),
                const SizedBox(height: 10),
                ElevatedButton(
                  onPressed: _deleteRecording,
                  child: const Text("Delete Recording"),
                ),
                const SizedBox(height: 10),
                ElevatedButton(
                  onPressed: () {
                    if (_formKey.currentState!.validate()) {
                      _sendRecording();
                    }
                  },
                  child: const Text("Send Recording"),
                ),
              ],
              const SizedBox(height: 20),
              if (_isLoading) const Center(child: CircularProgressIndicator()),
            ],
          ),
        ),
      ),
    );
  }
}
