import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'location_provider.dart';
import 'image_translation_screen.dart';
import 'voice_recording_screen.dart';
import 'text_translation_screen.dart';
import 'settings_page.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_settings_screens/flutter_settings_screens.dart';
import 'main.dart';
import 'package:logger/logger.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    var logger = Logger();
    final locationProvider = Provider.of<LocationProvider>(context);
    final currentPos = locationProvider.currentPosition;
    logger.d(currentPos);
    final locality = locationProvider.locality;
    final administrativeArea = locationProvider.administrativeArea;
    final country = locationProvider.country;
    final lang = locationProvider.language;
    String locationText = currentPos != null
        ? "Locality: $locality\n Administrative area: $administrativeArea\n Country: $country\n Language: $lang"
        : "";

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Translator App Home",
          style: TextStyle(
            fontSize: 16.0,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.2,
            height: 1.5,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              Settings.clearCache();
              await FirebaseAuth.instance.signOut();

              navigatorKey.currentState
                  ?.pushNamedAndRemoveUntil('/login', (route) => false);
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsPage()),
              ).then((_) {
                if (context.mounted) {
                  Provider.of<LocationProvider>(context, listen: false)
                      .updateTracking();
                }
              });
            },
          )
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            ElevatedButton(
              child: const Text("Translate Image"),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const ImageTranslationScreen()),
                );
              },
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              child: const Text("Record Voice"),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const VoiceRecordingScreen()),
                );
              },
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              child: const Text("Input text"),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const TextTranslationScreen()),
                );
              },
            ),
            const SizedBox(height: 20),
            Text(
              locationText,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12.0,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.2,
                height: 1.5,
              ),
            )
          ],
        ),
      ),
    );
  }
}
