import 'package:flutter/material.dart';
import 'package:flutter_settings_screens/flutter_settings_screens.dart';
import 'package:logger/logger.dart';
import 'package:provider/provider.dart';
import 'location_provider.dart';
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
                    "no_location": "No Location",
                  },
                  selected: "no_location",
                  onChange: (newVal) {
                    setState(() {});
                    final locProv = context.read<LocationProvider>();
                    if (newVal == "location") {
                      locProv.startTracking();
                    } else {
                      locProv.stopTracking();
                    }
                  },
                ),
                RadioSettingsTile<String>(
                  title: "Model",
                  settingKey: kModelTypeKey,
                  values: const {
                    "ml": "Machine Learning Model",
                    "llm": "LLM Model",
                  },
                  selected: currentModelType!,
                  onChange: (_) => setState(() {}),
                ),
                if (currentModelType == 'ml')
                  ListTile(
                    title: const Text('Choose ML Model'),
                    subtitle: Text(
                      modelNames[Settings.getValue<String>(
                        kMlModelKey,
                        defaultValue: 'facebook/m2m100_1.2B',
                      )]!,
                    ),
                    leading: const Icon(Icons.memory),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () async {
                      await Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => SettingsScreen(
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
                                selected: Settings.getValue<String>(
                                  kMlModelKey,
                                  defaultValue: 'facebook/m2m100_1.2B',
                                )!,
                              ),
                            ],
                          ),
                        ),
                      );
                      setState(() {});
                    },
                  ),
                if (currentModelType == 'llm')
                  ListTile(
                    title: const Text('Choose LLM Model'),
                    subtitle: Text(
                      modelNames[Settings.getValue<String>(
                        kLlmModelKey,
                        defaultValue: 'chatgpt',
                      )]!,
                    ),
                    leading: const Icon(Icons.chat_bubble_outline),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () async {
                      await Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => SettingsScreen(
                            title: 'Select LLM Model',
                            children: [
                              RadioSettingsTile<String>(
                                title: "LLM Model",
                                settingKey: kLlmModelKey,
                                values: const {
                                  'chatgpt': 'OpenAI ChatGPT',
                                  'claude': 'Anthropic Claude',
                                },
                                selected: Settings.getValue<String>(
                                  kLlmModelKey,
                                  defaultValue: 'chatgpt',
                                )!,
                              ),
                            ],
                          ),
                        ),
                      );
                      setState(() {});
                    },
                  ),
                const Divider(height: 1, thickness: 0.6),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// final detection = Settings.getValue<String>("detection_mode", "automatic");
