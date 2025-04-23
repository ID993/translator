import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:saver_gallery/saver_gallery.dart';
import 'package:path/path.dart' as path;
import 'package:http/http.dart' as http;
import 'package:flutter_settings_screens/flutter_settings_screens.dart';
import 'package:logger/logger.dart';

class ImageTranslationScreen extends StatefulWidget {
  const ImageTranslationScreen({super.key});

  @override
  State<ImageTranslationScreen> createState() => _ImageTranslationScreenState();
}

class _ImageTranslationScreenState extends State<ImageTranslationScreen> {
  File? _selectedImage;
  Uint8List? _translatedImage;
  bool _isLoading = false;
  final ImagePicker _picker = ImagePicker();
  var logger = Logger();

  final _model = Settings.getValue<String>("model_type", defaultValue: "ml");
  final detection =
      Settings.getValue<String>("detection_mode", defaultValue: "automatic");

  final List<String> _languages = ['hr', 'en', 'es', 'de', 'fr', 'nl'];

  String _sourceLang = 'hr';
  String _targetLang = 'en';

  Future<void> _pickImage() async {
    final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _selectedImage = File(pickedFile.path);
        _translatedImage = null;
      });
    }
  }

  // Future<void> _useCamera() async {
  //   final pickedFile = await _picker.pickImage(source: ImageSource.camera);
  //   if (pickedFile != null) {
  //     setState(() {
  //       _selectedImage = File(pickedFile.path);
  //       _translatedImage = null;
  //     });
  //   }
  // }
  Future<void> _useCamera() async {
    final XFile? picked = await _picker.pickImage(source: ImageSource.camera);
    if (!mounted || picked == null) return;

    final CroppedFile? cropped = await ImageCropper().cropImage(
      sourcePath: picked.path,
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: 'Edit Photo',
          toolbarColor: Theme.of(context).primaryColor,
          toolbarWidgetColor: Colors.white,
          initAspectRatio: CropAspectRatioPreset.original,
          lockAspectRatio: false,
          aspectRatioPresets: [
            CropAspectRatioPreset.original,
            CropAspectRatioPreset.square,
            CropAspectRatioPreset.ratio4x3,
            CropAspectRatioPreset.ratio16x9,
          ],
        ),
        IOSUiSettings(
          title: 'Edit Photo',
          aspectRatioLockEnabled: false,
          resetAspectRatioEnabled: true,
          aspectRatioPresets: [
            CropAspectRatioPreset.original,
            CropAspectRatioPreset.square,
          ],
        ),
      ],
    );
    if (!mounted || cropped == null) return;

    final SaveResult result = await SaverGallery.saveFile(
      filePath: cropped.path,
      fileName: path.basename(cropped.path),
      skipIfExists: false,
    );
    if (!mounted) return;

    if (!result.isSuccess) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Failed to save photo to gallery: ${result.errorMessage ?? "unknown error"}'),
        ),
      );
      return;
    }

    setState(() {
      _selectedImage = File(cropped.path);
      _translatedImage = null;
    });
  }

  Future<void> _sendImage() async {
    if (_selectedImage == null) return;
    setState(() {
      _isLoading = true;
    });
    try {
      logger.d(_selectedImage!.path);
      var uri = Uri.parse("http://192.168.0.157:5000/translate-image");
      // var uri = Uri.parse(
      //     "https://3a44-89-164-230-31.ngrok-free.app/translate-image");

      var request = http.MultipartRequest('POST', uri);
      request.files
          .add(await http.MultipartFile.fromPath('file', _selectedImage!.path));
      request.fields['src_lang'] = _sourceLang;
      request.fields['tgt_lang'] = _targetLang;
      request.fields['model'] = _model!;

      var response = await request.send();

      if (response.statusCode == 200) {
        Uint8List bytes = await response.stream.toBytes();
        if (!mounted) return;
        setState(() {
          _translatedImage = bytes;
        });
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text("Translation failed with status: ${response.statusCode}"),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
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

  void _removeImage() {
    setState(() {
      _selectedImage = null;
      _translatedImage = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Translate Image"),
      ),
      body: Column(
        children: [
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
                        }
                      },
                    ),
                  ],
                ),
                const SizedBox(width: 10),
                IconButton(
                  icon: const Icon(Icons.swap_horiz),
                  onPressed: () {
                    setState(() {
                      final temp = _sourceLang;
                      _sourceLang = _targetLang;
                      _targetLang = temp;
                    });
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
                        }
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: Container(
              width: double.infinity,
              color: Colors.black12,
              child: InteractiveViewer(
                child: _translatedImage != null
                    ? Image.memory(
                        _translatedImage!,
                        fit: BoxFit.contain,
                      )
                    : _selectedImage != null
                        ? Image.file(
                            _selectedImage!,
                            fit: BoxFit.contain,
                          )
                        : const Center(child: Text("No image selected.")),
              ),
            ),
          ),
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(8.0),
              child: CircularProgressIndicator(),
            ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  onPressed: _selectedImage == null ? _pickImage : _removeImage,
                  child: Text(
                      _selectedImage == null ? "Pick Image" : "Remove Image"),
                ),
                ElevatedButton(
                  onPressed: _selectedImage == null ? _useCamera : _sendImage,
                  child: Text(_selectedImage == null ? "Use Camera" : "Send"),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
