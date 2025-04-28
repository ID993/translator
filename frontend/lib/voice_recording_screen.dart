import 'dart:io';
import 'package:flutter/material.dart';
import 'package:logger/web.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:logger/logger.dart';
import 'package:flutter_settings_screens/flutter_settings_screens.dart';

class VoiceRecordingScreen extends StatefulWidget {
  const VoiceRecordingScreen({super.key});

  @override
  State<VoiceRecordingScreen> createState() => _VoiceRecordingScreenState();
}

class _VoiceRecordingScreenState extends State<VoiceRecordingScreen> {
  final AudioRecorder _recorder = AudioRecorder();
  final AudioPlayer _audioPlayer = AudioPlayer();
  var logger = Logger();
  String? _recordFilePath;
  //File? _audioFile;
  bool _isRecording = false;
  bool _isPlaying = false;
  bool _isLoading = false;
  String? _translatedAudioTtx;

  final _model = Settings.getValue<String>("model_type", defaultValue: "ml");
  final detection =
      Settings.getValue<String>("detection_mode", defaultValue: "automatic");

  final List<String> _languages = ['hr', 'en', 'es', 'de', 'fr', 'nl', 'it'];

  String _sourceLang = 'hr';
  String _targetLang = 'en';

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
  void dispose() {
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
      logger.d(_baseUrl);
      var uri = Uri.parse("$_baseUrl/translate-audio");
      var request = http.MultipartRequest('POST', uri);
      logger.d(_recordFilePath);
      request.files
          .add(await http.MultipartFile.fromPath('file', _recordFilePath!));
      request.fields['src_lang'] = _sourceLang;
      request.fields['tgt_lang'] = _targetLang;
      request.fields['model'] = _model!;

      var response = await request.send();

      if (response.statusCode == 200) {
        String textFromAudio = await response.stream.bytesToString();
        logger.d(
            "successfully returned text from audio textFromAudio: $textFromAudio");
        if (!mounted) return;
        setState(() {
          _translatedAudioTtx = textFromAudio;
          logger.d(
              "successfully returned text from audio _translatedAudioTtx: $_translatedAudioTtx");
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

  @override
  Widget build(BuildContext context) {
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
      appBar: AppBar(
        title: const Text('Voice Recorder'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Column(
                    children: [
                      const Text("Source Language"),
                      DropdownButton<String>(
                        value: _sourceLang,
                        items: _languages
                            .map(
                              (lang) => DropdownMenuItem(
                                value: lang,
                                child: Text(lang.toUpperCase()),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          if (value != null) {
                            setState(() {
                              _sourceLang = value;
                            });
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
                      await _sendRecording();
                    },
                  ),
                  const SizedBox(width: 10),
                  Column(
                    children: [
                      const Text("Target Language"),
                      DropdownButton<String>(
                        value: _targetLang,
                        items: _languages
                            .map(
                              (lang) => DropdownMenuItem(
                                value: lang,
                                child: Text(lang.toUpperCase()),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          if (value != null) {
                            setState(() {
                              _targetLang = value;
                            });
                          }
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Text(
              statusText,
              textAlign: TextAlign.center,
              softWrap: true,
              style: statusStyle,
            ),
            const SizedBox(height: 8),
            if (_translatedAudioTtx != null)
              Text(
                "Translation:\n$_translatedAudioTtx",
                textAlign: TextAlign.center,
                softWrap: true,
                style:
                    const TextStyle(fontSize: 14, fontStyle: FontStyle.italic),
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
                onPressed: _sendRecording,
                child: const Text("Send Recording"),
              ),
            ],
            const SizedBox(height: 20),
            if (_isLoading)
              const Center(
                child: CircularProgressIndicator(),
              ),
          ],
        ),
      ),
    );
  }
}
