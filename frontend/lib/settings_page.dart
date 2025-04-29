import 'package:flutter/material.dart';
import 'package:flutter_settings_screens/flutter_settings_screens.dart';
import 'package:logger/logger.dart';

import './constants.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final logger = Logger();

  @override
  Widget build(BuildContext context) {
    final currentModelType = Settings.getValue<String>(
      kModelTypeKey,
      defaultValue: 'ml',
    );

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
                  onChange: (_) => setState(() {}),
                ),
                RadioSettingsTile<String>(
                  title: "Model",
                  settingKey: kModelTypeKey,
                  values: const {
                    "ml": "Machine Learning Model",
                    "llm": "LLM Model",
                  },
                  selected: "ml",
                  onChange: (_) => setState(() {}),
                ),
                if (currentModelType == 'ml')
                  SimpleSettingsTile(
                    title: 'Choose ML Model',
                    leading: const Icon(Icons.memory),
                    child: SettingsScreen(
                      title: 'Select ML Model',
                      children: [
                        RadioSettingsTile<String>(
                          title: "ML Model",
                          settingKey: kMlModelKey,
                          values: const {
                            'facebook/m2m100_1.2B': 'M2M100',
                            'facebook/mbart-large-50-many-to-many-mmt':
                                'mBART50',
                          },
                          selected: 'm2m100',
                        ),
                      ],
                    ),
                  ),
                if (currentModelType == 'llm')
                  SimpleSettingsTile(
                    title: 'Choose LLM Model',
                    leading: const Icon(Icons.chat_bubble_outline),
                    child: SettingsScreen(
                      title: 'Select LLM Model',
                      children: [
                        RadioSettingsTile<String>(
                          title: "LLM Model",
                          settingKey: kLlmModelKey,
                          values: const {
                            'chatgpt': 'OpenAI ChatGPT',
                            'claude': 'Anthropic Claude',
                          },
                          selected: 'chatgpt',
                        ),
                      ],
                    ),
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
