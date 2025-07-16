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
    final logger = Logger();
    final locationProvider = Provider.of<LocationProvider>(context);
    final currentPos = locationProvider.currentPosition;
    logger.d(currentPos);

    final String? country = currentPos != null ? locationProvider.country : '';
    final String? lang = currentPos != null ? locationProvider.language : '';

    return Scaffold(
      appBar: AppBar(
        elevation: 2,
        title: const Text(
          'Translator App',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            tooltip: 'Settings',
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsPage()),
              ).then((_) {
                if (context.mounted) {
                  Provider.of<LocationProvider>(context, listen: false)
                      .updateTracking();
                }
              });
            },
          ),
          IconButton(
            tooltip: 'Logout',
            icon: const Icon(Icons.logout),
            onPressed: () async {
              Settings.clearCache();
              await FirebaseAuth.instance.signOut();
              navigatorKey.currentState
                  ?.pushNamedAndRemoveUntil('/login', (route) => false);
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const GreetingCard(),
              const SizedBox(height: 16),
              Expanded(
                child: GridView.count(
                  crossAxisCount: 2,
                  mainAxisSpacing: 16,
                  crossAxisSpacing: 16,
                  children: [
                    _OptionCard(
                      icon: Icons.image,
                      label: 'Image',
                      onTap: navigateToImageTranslation,
                    ),
                    _OptionCard(
                      icon: Icons.mic,
                      label: 'Voice',
                      onTap: navigateToVoiceRecording,
                    ),
                    _OptionCard(
                      icon: Icons.text_fields,
                      label: 'Text',
                      onTap: navigateToTextTranslation,
                    ),
                    LocationCard(
                      isAvailable: currentPos != null,
                      country: country!,
                      language: lang!,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static void navigateToImageTranslation(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ImageTranslationScreen()),
    );
  }

  static void navigateToVoiceRecording(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const VoiceRecordingScreen()),
    );
  }

  static void navigateToTextTranslation(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const TextTranslationScreen()),
    );
  }
}

class GreetingCard extends StatelessWidget {
  const GreetingCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            const Icon(Icons.translate, size: 40),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Welcome to Translator App!\nQuickly translate images, voice, and text.',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OptionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final void Function(BuildContext) onTap;

  const _OptionCard({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 4,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => onTap(context),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 24.0, horizontal: 8.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 48),
              const SizedBox(height: 12),
              Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class LocationCard extends StatelessWidget {
  final bool isAvailable;
  final String country;
  final String language;

  const LocationCard({
    required this.isAvailable,
    required this.country,
    required this.language,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 4,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                isAvailable ? Icons.location_on : Icons.location_off,
                size: 48,
              ),
              const SizedBox(height: 12),
              Flexible(
                child: Text(
                  isAvailable
                      ? '$country\nLanguage: $language'
                      : 'Location unavailable.',
                  textAlign: TextAlign.center,
                  softWrap: true,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 4,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
