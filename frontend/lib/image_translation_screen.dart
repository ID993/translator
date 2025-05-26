// import 'dart:io';
// import 'package:firebase_auth/firebase_auth.dart';
// import 'package:provider/provider.dart';
// import './location_provider.dart';
// import 'package:flutter/material.dart';
// import 'package:flutter_dotenv/flutter_dotenv.dart';
// import 'package:image_picker/image_picker.dart';
// import 'package:image_cropper/image_cropper.dart';
// import 'package:saver_gallery/saver_gallery.dart';
// import 'package:path/path.dart' as path;
// import 'package:http/http.dart' as http;
// import 'package:flutter_settings_screens/flutter_settings_screens.dart';
// import 'package:logger/logger.dart';
// import 'dart:convert';
// import './constants.dart';

// const Map<String, String> _languagesNames = {
//   'hr': 'Croatian',
//   'en': 'English',
//   'es': 'Spanish',
//   'de': 'German',
//   'fr': 'French',
//   'nl': 'Dutch',
//   'it': 'Italian',
// };

// class ImageTranslationScreen extends StatefulWidget {
//   const ImageTranslationScreen({super.key});

//   @override
//   State<ImageTranslationScreen> createState() => _ImageTranslationScreenState();
// }

// class _ImageTranslationScreenState extends State<ImageTranslationScreen> {
//   final _formKey = GlobalKey<FormState>();
//   File? _selectedImage;
//   bool _isLoading = false;
//   final ImagePicker _picker = ImagePicker();
//   var logger = Logger();

//   final detection =
//       Settings.getValue<String>("detection_mode", defaultValue: "no_location");

//   String? get engine => Settings.getValue<String>(
//         kModelTypeKey,
//         defaultValue: 'ml',
//       );

//   String? get model => (engine == 'ml')
//       ? Settings.getValue<String>(kMlModelKey,
//           defaultValue: 'facebook/m2m100_1.2B')
//       : Settings.getValue<String>(kLlmModelKey, defaultValue: 'chatgpt');

//   final _languages = _languagesNames.keys.toList();

//   String? _sourceLang;
//   String? _targetLang;

//   String? _originalImageUrl;
//   String? _whiteImageUrl;
//   bool _showWhite = false;

//   String? _suggestion;
//   bool force = false;

//   final _baseUrl = dotenv.env['API_URL']!;

//   Future<void> _pickImage() async {
//     final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
//     if (pickedFile != null) {
//       setState(() {
//         _selectedImage = File(pickedFile.path);
//         _originalImageUrl = null;
//         _whiteImageUrl = null;
//         _suggestion = null;
//       });
//     }
//   }

//   Future<void> _useCamera() async {
//     final XFile? picked = await _picker.pickImage(source: ImageSource.camera);
//     if (!mounted || picked == null) return;

//     final CroppedFile? cropped = await ImageCropper().cropImage(
//       sourcePath: picked.path,
//       uiSettings: [
//         AndroidUiSettings(
//           toolbarTitle: 'Edit Photo',
//           toolbarColor: Theme.of(context).primaryColor,
//           toolbarWidgetColor: Colors.white,
//           initAspectRatio: CropAspectRatioPreset.original,
//           lockAspectRatio: false,
//           aspectRatioPresets: [
//             CropAspectRatioPreset.original,
//             CropAspectRatioPreset.square,
//             CropAspectRatioPreset.ratio4x3,
//             CropAspectRatioPreset.ratio16x9,
//           ],
//         ),
//         IOSUiSettings(
//           title: 'Edit Photo',
//           aspectRatioLockEnabled: false,
//           resetAspectRatioEnabled: true,
//           aspectRatioPresets: [
//             CropAspectRatioPreset.original,
//             CropAspectRatioPreset.square,
//           ],
//         ),
//       ],
//     );
//     if (!mounted || cropped == null) return;

//     final SaveResult result = await SaverGallery.saveFile(
//       filePath: cropped.path,
//       fileName: path.basename(cropped.path),
//       skipIfExists: false,
//     );
//     if (!mounted) return;

//     if (!result.isSuccess) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//           content: Text(
//               'Failed to save photo to gallery: ${result.errorMessage ?? "unknown error"}'),
//         ),
//       );
//       return;
//     }

//     setState(() {
//       _selectedImage = File(cropped.path);
//       _originalImageUrl = null;
//       _whiteImageUrl = null;
//       _suggestion = null;
//     });
//   }

//   Future<void> _sendImage() async {
//     logger.d("SRC: $_sourceLang, TGT: $_targetLang");
//     logger.d("SUGG: $_suggestion");
//     logger.d("FORCE: $force");
//     if (_selectedImage == null) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text("Please select an image to translate.")),
//       );
//       return;
//     }

//     if (_sourceLang == _targetLang) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//             content: Text("Source and target languages must be different.")),
//       );
//       return;
//     }
//     setState(() => _isLoading = true);

//     try {
//       final user = FirebaseAuth.instance.currentUser;
//       if (user == null) {
//         throw Exception("Not signed in");
//       }
//       final idToken = await user.getIdToken();
//       final composite = '${engine}_:_$model';

//       var uri = Uri.parse("$_baseUrl/translate-image");
//       var request = http.MultipartRequest('POST', uri)
//         ..headers['Authorization'] = 'Bearer $idToken'
//         ..files.add(
//             await http.MultipartFile.fromPath('file', _selectedImage!.path))
//         ..fields['src_lang'] = _sourceLang!
//         ..fields['tgt_lang'] = _targetLang!
//         ..fields['composite'] = composite
//         ..fields['force'] = force ? '1' : '0';

//       var response = await request.send();
//       final responseString = await response.stream.bytesToString();
//       if (response.statusCode == 200) {
//         var json = jsonDecode(responseString);
//         setState(() {
//           if (force) {
//             _suggestion = null;
//           } else {
//             _suggestion = json['detected_lang'] as String;
//           }
//           _originalImageUrl = json['original_image_url'];
//           _whiteImageUrl = json['white_image_url'];
//         });
//       } else {
//         if (!mounted) return;
//         String errorMessage;
//         try {
//           final errorJson = jsonDecode(responseString);
//           errorMessage = errorJson['error'] ??
//               "Translation failed with status: ${response.statusCode}";
//         } catch (_) {
//           errorMessage =
//               "Translation failed with status: ${response.statusCode}";
//         }
//         logger.d("Translation failed: $errorMessage");
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(content: Text(errorMessage)),
//         );
//       }
//     } catch (e) {
//       if (!mounted) return;
//       logger.d("Error during translation: $e");
//       ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(content: Text("Error during translation: $e")));
//     } finally {
//       setState(() => _isLoading = false);
//     }
//   }

//   void _removeImage() {
//     setState(() {
//       _selectedImage = null;
//       _originalImageUrl = null;
//       _whiteImageUrl = null;
//       _isLoading = false;
//       _showWhite = false;
//       _suggestion = null;
//       _sourceLang = null;
//       _targetLang = null;
//       force = false;
//     });
//   }

//   void _showUnsupportedDialog(String code) {
//     showDialog(
//       context: context,
//       builder: (_) => AlertDialog(
//         title: const Text("Unsupported language"),
//         content:
//             Text("${fastTextLangNames[code] ?? code} isn't in supported list. "
//                 "Please choose a language from the dropdown first."),
//         actions: [
//           TextButton(
//             onPressed: () => Navigator.of(context).pop(),
//             child: const Text("OK"),
//           )
//         ],
//       ),
//     );
//   }

//   @override
//   void initState() {
//     super.initState();
//     if (detection == "location") {
//       final localLang =
//           Provider.of<LocationProvider>(context, listen: false).language;
//       _sourceLang = localLang;
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     bool isSupported(String code) => _languagesNames.containsKey(code);
//     return Scaffold(
//       appBar: AppBar(title: const Text("Translate Image")),
//       body: Form(
//         key: _formKey,
//         child: Column(
//           children: [
//             Padding(
//               padding: const EdgeInsets.all(8),
//               child: Row(
//                 mainAxisAlignment: MainAxisAlignment.spaceEvenly,
//                 children: [
//                   Expanded(
//                     child: DropdownButtonFormField<String>(
//                       value: _sourceLang,
//                       decoration: InputDecoration(
//                         labelText: 'From',
//                         border: OutlineInputBorder(),
//                       ),
//                       items: _languages.map((code) {
//                         return DropdownMenuItem(
//                           value: code,
//                           child: Text(_languagesNames[code]!),
//                         );
//                       }).toList(),
//                       onChanged: (v) => setState(() {
//                         _sourceLang = v;
//                         _originalImageUrl = null;
//                         _whiteImageUrl = null;
//                         force = false;
//                       }),
//                       validator: (v) => v == null ? 'Please select' : null,
//                     ),
//                   ),
//                   const SizedBox(width: 8),
//                   IconButton(
//                     icon: const Icon(Icons.swap_horiz),
//                     onPressed: () {
//                       setState(() {
//                         final t = _sourceLang;
//                         _sourceLang = _targetLang;
//                         _targetLang = t;
//                         _originalImageUrl = null;
//                         _whiteImageUrl = null;
//                         force = false;
//                       });
//                       _sendImage();
//                     },
//                   ),
//                   const SizedBox(width: 8),
//                   Expanded(
//                     child: DropdownButtonFormField<String>(
//                       value: _targetLang,
//                       decoration: InputDecoration(
//                         labelText: 'To',
//                         border: OutlineInputBorder(),
//                       ),
//                       items: _languages.map((code) {
//                         return DropdownMenuItem(
//                           value: code,
//                           child: Text(_languagesNames[code]!),
//                         );
//                       }).toList(),
//                       onChanged: (v) => setState(() => _targetLang = v),
//                       validator: (v) => v == null ? 'Please select' : null,
//                     ),
//                   ),
//                 ],
//               ),
//             ),
//             if (_suggestion != null &&
//                 _sourceLang != null &&
//                 _suggestion != _sourceLang)
//               Container(
//                 margin: const EdgeInsets.symmetric(vertical: 12),
//                 padding: const EdgeInsets.all(12),
//                 decoration: BoxDecoration(
//                   color: Colors.orange.withValues(alpha: (0.1 * 255)),
//                   borderRadius: BorderRadius.circular(8),
//                 ),
//                 child: Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     Text(
//                       "Detected language: ${fastTextLangNames[_suggestion]}",
//                       style: TextStyle(
//                           color: Colors.orange, fontWeight: FontWeight.w600),
//                     ),
//                     SizedBox(height: 8),
//                     Wrap(
//                       spacing: 8,
//                       runSpacing: 4,
//                       children: [
//                         ElevatedButton.icon(
//                           onPressed: () {
//                             final cand = _suggestion!;
//                             if (!isSupported(cand)) {
//                               _showUnsupportedDialog(cand);
//                               return;
//                             }
//                             setState(() {
//                               _sourceLang = cand;
//                               _suggestion = null;
//                               _originalImageUrl = null;
//                               _whiteImageUrl = null;
//                             });
//                             _sendImage();
//                           },
//                           icon: const Icon(Icons.check),
//                           label: Text(
//                             "Use ${fastTextLangNames[_suggestion]}",
//                             style: TextStyle(fontSize: 14),
//                           ),
//                         ),
//                         TextButton.icon(
//                             onPressed: () {
//                               final keep = _sourceLang!;
//                               if (!isSupported(keep)) {
//                                 _showUnsupportedDialog(keep);
//                                 return;
//                               }
//                               setState(() {
//                                 _suggestion = null;
//                                 _originalImageUrl = null;
//                                 _whiteImageUrl = null;
//                                 force = true;
//                               });
//                               _sendImage();
//                             },
//                             icon: const Icon(Icons.block),
//                             label: Text(
//                               "Keep ${fastTextLangNames[_sourceLang]}",
//                               style: TextStyle(
//                                 fontSize: 14,
//                               ),
//                             )),
//                       ],
//                     ),
//                   ],
//                 ),
//               ),
//             Expanded(
//               child: Container(
//                 width: double.infinity,
//                 color: Colors.black12,
//                 child: InteractiveViewer(
//                   // child: _originalImageUrl != null && _whiteImageUrl != null
//                   //     ? Image.network(
//                   //         _showWhite ? _whiteImageUrl! : _originalImageUrl!,
//                   //         fit: BoxFit.contain,
//                   //         key: ValueKey(_showWhite),
//                   //       )
//                   //     : _selectedImage != null
//                   //         ? Image.file(
//                   //             _selectedImage!,
//                   //             fit: BoxFit.contain,
//                   //           )
//                   //         : const Center(child: Text("No image selected.")),
//                   child: _suggestion != null && _suggestion != _sourceLang
//                       ? (_selectedImage != null
//                           ? Image.file(_selectedImage!, fit: BoxFit.contain)
//                           : const Center(child: Text("No image selected.")))
//                       : _originalImageUrl != null && _whiteImageUrl != null
//                           ? Image.network(
//                               _showWhite ? _whiteImageUrl! : _originalImageUrl!,
//                               fit: BoxFit.contain,
//                               key: ValueKey(_showWhite),
//                             )
//                           : _selectedImage != null
//                               ? Image.file(_selectedImage!, fit: BoxFit.contain)
//                               : const Center(child: Text("No image selected.")),
//                 ),
//               ),
//             ),
//             // if (_originalImageUrl != null && _whiteImageUrl != null)
//             //   Padding(
//             //     padding: const EdgeInsets.symmetric(vertical: 8),
//             //     child: Row(
//             //       mainAxisAlignment: MainAxisAlignment.center,
//             //       children: [
//             //         const Text("White BG"),
//             //         Checkbox(
//             //           value: _showWhite,
//             //           onChanged: (v) => setState(() => _showWhite = v ?? false),
//             //         ),
//             //       ],
//             //     ),
//             //   ),
//             if (_originalImageUrl != null &&
//                 _whiteImageUrl != null &&
//                 (_suggestion == null || _suggestion == _sourceLang))
//               Padding(
//                 padding: const EdgeInsets.symmetric(vertical: 8),
//                 child: Row(
//                   mainAxisAlignment: MainAxisAlignment.center,
//                   children: [
//                     const Text("White BG"),
//                     Checkbox(
//                       value: _showWhite,
//                       onChanged: (v) => setState(() => _showWhite = v ?? false),
//                     ),
//                   ],
//                 ),
//               ),
//             if (_isLoading)
//               const Padding(
//                 padding: EdgeInsets.all(8.0),
//                 child: CircularProgressIndicator(),
//               ),
//             Padding(
//               padding: const EdgeInsets.all(8.0),
//               child: Row(
//                 mainAxisAlignment: MainAxisAlignment.spaceEvenly,
//                 children: [
//                   ElevatedButton(
//                     onPressed:
//                         _selectedImage == null ? _pickImage : _removeImage,
//                     child: Text(
//                       _selectedImage == null ? "Pick Image" : "Remove Image",
//                     ),
//                   ),
//                   ElevatedButton(
//                     onPressed: _selectedImage == null
//                         ? _useCamera
//                         : () {
//                             // validate languages before sending
//                             if (_formKey.currentState!.validate()) {
//                               _sendImage();
//                             }
//                           },
//                     child: Text(
//                       _selectedImage == null ? "Use Camera" : "Send",
//                     ),
//                   ),
//                 ],
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }
// ... [all your existing imports remain unchanged]
import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import './location_provider.dart';
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
import './constants.dart';

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

  String? _originalImageUrl;
  String? _whiteImageUrl;
  bool _showWhiteBackground = false;
  bool _showOriginalImage = false;

  String? _suggestion;
  bool force = false;

  final _baseUrl = dotenv.env['API_URL']!;

  Future<void> _pickImage() async {
    final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _selectedImage = File(pickedFile.path);
        _originalImageUrl = null;
        _whiteImageUrl = null;
        _suggestion = null;
        _showOriginalImage = false;
        _showWhiteBackground = false;
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
      _suggestion = null;
      _showOriginalImage = false;
      _showWhiteBackground = false;
    });
  }

  Future<void> _sendImage() async {
    logger.d("SRC: $_sourceLang, TGT: $_targetLang");
    logger.d("SUGG: $_suggestion");
    logger.d("FORCE: $force");
    if (_selectedImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Please select an image to translate.")),
      );
      return;
    }

    if (_sourceLang == _targetLang) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text("Source and target languages must be different.")),
      );
      return;
    }
    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception("Not signed in");
      }
      final idToken = await user.getIdToken();
      final composite = '${engine}_:_$model';

      var uri = Uri.parse("$_baseUrl/translate-image");
      var request = http.MultipartRequest('POST', uri)
        ..headers['Authorization'] = 'Bearer $idToken'
        ..files.add(
            await http.MultipartFile.fromPath('file', _selectedImage!.path))
        ..fields['src_lang'] = _sourceLang!
        ..fields['tgt_lang'] = _targetLang!
        ..fields['composite'] = composite
        ..fields['force'] = force ? '1' : '0';

      var response = await request.send();
      final responseString = await response.stream.bytesToString();
      if (response.statusCode == 200) {
        var json = jsonDecode(responseString);
        setState(() {
          if (force) {
            _suggestion = null;
          } else {
            _suggestion = json['detected_lang'] as String;
          }
          _originalImageUrl = json['original_image_url'];
          _whiteImageUrl = json['white_image_url'];
          _showOriginalImage = false;
          _showWhiteBackground = false;
        });
      } else {
        if (!mounted) return;
        String errorMessage;
        try {
          final errorJson = jsonDecode(responseString);
          errorMessage = errorJson['error'] ?? "Translation failed";
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
          SnackBar(content: Text("Error during translation: $e")));
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
      _showWhiteBackground = false;
      _showOriginalImage = false;
      _suggestion = null;
      _sourceLang = null;
      _targetLang = null;
      force = false;
    });
  }

  void _showUnsupportedDialog(String code) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Unsupported language"),
        content:
            Text("${fastTextLangNames[code] ?? code} isn't in supported list."),
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
      appBar: AppBar(title: const Text("Translate Image")),
      body: Form(
        key: _formKey,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
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
                      onChanged: (v) => setState(() {
                        _sourceLang = v;
                        _originalImageUrl = null;
                        _whiteImageUrl = null;
                        force = false;
                      }),
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
                        _originalImageUrl = null;
                        _whiteImageUrl = null;
                        force = false;
                      });
                      _sendImage();
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
                      onChanged: (v) => setState(() => _targetLang = v),
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
                  color: Colors.orange.withOpacity(0.1),
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
                              _originalImageUrl = null;
                              _whiteImageUrl = null;
                            });
                            _sendImage();
                          },
                          icon: const Icon(Icons.check),
                          label: Text("Use ${fastTextLangNames[_suggestion]}"),
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
                              _originalImageUrl = null;
                              _whiteImageUrl = null;
                              force = true;
                            });
                            _sendImage();
                          },
                          icon: const Icon(Icons.block),
                          label: Text("Keep ${fastTextLangNames[_sourceLang]}"),
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
                  child: (_suggestion != null && _suggestion != _sourceLang)
                      ? (_selectedImage != null
                          ? Image.file(_selectedImage!, fit: BoxFit.contain)
                          : const Center(child: Text("No image selected.")))
                      : (_selectedImage != null
                          ? (_showOriginalImage ||
                                  _originalImageUrl == null ||
                                  _whiteImageUrl == null
                              ? Image.file(_selectedImage!, fit: BoxFit.contain)
                              : Image.network(
                                  _showWhiteBackground
                                      ? _whiteImageUrl!
                                      : _originalImageUrl!,
                                  fit: BoxFit.contain,
                                  key: ValueKey(_showWhiteBackground),
                                ))
                          : const Center(child: Text("No image selected."))),
                ),
              ),
            ),
            if (_originalImageUrl != null &&
                _whiteImageUrl != null &&
                (_suggestion == null || _suggestion == _sourceLang))
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text("Original"),
                    Switch(
                      value: _showOriginalImage,
                      onChanged: (v) => setState(() => _showOriginalImage = v),
                    ),
                    const SizedBox(width: 16),
                    if (!_showOriginalImage) ...[
                      const Text("Remove BG"),
                      Checkbox(
                        value: _showWhiteBackground,
                        onChanged: (v) =>
                            setState(() => _showWhiteBackground = v ?? false),
                      ),
                    ],
                  ],
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
