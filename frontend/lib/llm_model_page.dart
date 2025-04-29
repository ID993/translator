import 'package:flutter/material.dart';
import 'package:flutter_settings_screens/flutter_settings_screens.dart';
import './constants.dart';

class LlmModelPage extends StatelessWidget {
  const LlmModelPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Select LLM Model')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
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
    );
  }
}
