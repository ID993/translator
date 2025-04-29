import 'package:flutter/material.dart';
import 'package:flutter_settings_screens/flutter_settings_screens.dart';
import './constants.dart';

class MlModelPage extends StatelessWidget {
  const MlModelPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Select ML Model')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            RadioSettingsTile<String>(
              title: "ML Model",
              settingKey: kMlModelKey,
              values: const {
                'facebook/m2m100_1.2B': 'M2M100',
                'facebook/mbart-large-50-many-to-many-mmt': 'mBART50',
              },
              selected: 'm2m100',
            ),
          ],
        ),
      ),
    );
  }
}
