import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:saver_gallery/saver_gallery.dart';
import 'package:path/path.dart' as path;
import 'package:http/http.dart' as http;
import 'package:flutter_settings_screens/flutter_settings_screens.dart';
import 'package:logger/logger.dart';
import 'dart:convert';

const Map<String, String> _languagesNames = {
  'hr': 'Croatian',
  'en': 'English',
  'es': 'Spanish',
  'de': 'German',
  'fr': 'French',
  'nl': 'Dutch',
  'it': 'Italian',
};

class ImageTranslationScreen extends StatefulWidget {
  const ImageTranslationScreen({super.key});

  @override
  State<ImageTranslationScreen> createState() => _ImageTranslationScreenState();
}

class _ImageTranslationScreenState extends State<ImageTranslationScreen> {
  final _formKey = GlobalKey<FormState>();
  File? _selectedImage;
  bool _isLoading = false;
  final ImagePicker _picker = ImagePicker();
  var logger = Logger();

  final _model = Settings.getValue<String>("model_type", defaultValue: "ml");
  final detection =
      Settings.getValue<String>("detection_mode", defaultValue: "automatic");

  final _languages = _languagesNames.keys.toList();

  String? _sourceLang;
  String? _targetLang;

  String? _originalImageUrl;
  String? _whiteImageUrl;
  bool _showWhite = false;

  final _baseUrl = dotenv.env['API_URL']!;

  Future<void> _pickImage() async {
    final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _selectedImage = File(pickedFile.path);
        _originalImageUrl = null;
        _whiteImageUrl = null;
      });
    }
  }

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
      _originalImageUrl = null;
      _whiteImageUrl = null;
    });
  }

  Future<void> _sendImage() async {
    if (_selectedImage == null) return;
    setState(() => _isLoading = true);

    try {
      var uri = Uri.parse("$_baseUrl/translate-image");
      var req = http.MultipartRequest('POST', uri)
        ..files.add(
            await http.MultipartFile.fromPath('file', _selectedImage!.path))
        ..fields['src_lang'] = _sourceLang!
        ..fields['tgt_lang'] = _targetLang!
        ..fields['model'] = _model!;

      var res = await req.send();

      if (res.statusCode == 200) {
        var body = await res.stream.bytesToString();
        var json = jsonDecode(body);
        setState(() {
          _originalImageUrl = json['original_image_url'];
          _whiteImageUrl = json['white_image_url'];
        });
      } else {
        if (!mounted) return;
        logger.d("Translation failed with status: ${res.statusCode}");
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("Status ${res.statusCode}")));
      }
    } catch (e) {
      if (!mounted) return;
      logger.d("Error during translation: $e");
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _removeImage() {
    setState(() {
      _selectedImage = null;
      _originalImageUrl = null;
      _whiteImageUrl = null;
      _isLoading = false;
      _showWhite = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Translate Image")),
      body: Form(
        key: _formKey,
        child: Column(
          children: [
            // -- LANGUAGES ROW --
            Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Source
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

                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.swap_horiz),
                    onPressed: () {
                      setState(() {
                        final t = _sourceLang;
                        _sourceLang = _targetLang;
                        _targetLang = t;
                      });
                    },
                  ),
                  const SizedBox(width: 8),

                  // Target
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

            // -- IMAGE VIEWER --
            Expanded(
              child: Container(
                width: double.infinity,
                color: Colors.black12,
                child: InteractiveViewer(
                  child: _originalImageUrl != null && _whiteImageUrl != null
                      ? Image.network(
                          _showWhite ? _whiteImageUrl! : _originalImageUrl!,
                          fit: BoxFit.contain,
                          key: ValueKey(_showWhite),
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

            // -- TOGGLE CHECKBOX --
            if (_originalImageUrl != null && _whiteImageUrl != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text("White BG"),
                    Checkbox(
                      value: _showWhite,
                      onChanged: (v) => setState(() => _showWhite = v ?? false),
                    ),
                  ],
                ),
              ),

            // -- LOADING INDICATOR --
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.all(8.0),
                child: CircularProgressIndicator(),
              ),

            // -- BUTTONS ROW --
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton(
                    onPressed:
                        _selectedImage == null ? _pickImage : _removeImage,
                    child: Text(
                      _selectedImage == null ? "Pick Image" : "Remove Image",
                    ),
                  ),
                  ElevatedButton(
                    onPressed: _selectedImage == null
                        ? _useCamera
                        : () {
                            // validate languages before sending
                            if (_formKey.currentState!.validate()) {
                              _sendImage();
                            }
                          },
                    child: Text(
                      _selectedImage == null ? "Use Camera" : "Send",
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
