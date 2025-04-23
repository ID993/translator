import 'package:flutter/material.dart';
import 'package:flutter_settings_screens/flutter_settings_screens.dart';
import 'package:logger/logger.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  var logger = Logger();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Settings")),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            SettingsGroup(
              title: 'GENERAL',
              children: <Widget>[
                RadioSettingsTile<String>(
                  title: "Detection",
                  settingKey: "detection_mode",
                  values: const {
                    "location": "Location",
                    "automatic": "Automatic",
                  },
                  selected: "automatic",
                ),
                RadioSettingsTile<String>(
                  title: "Model",
                  settingKey: "model_type",
                  values: const {
                    "ml": "Machine Learning Model",
                    "llm": "LLM Model",
                  },
                  selected: "ml",
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}


// final detection = Settings.getValue<String>("detection_mode", "automatic");
// final model = Settings.getValue<String>("model_type", "ml");