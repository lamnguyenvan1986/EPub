import 'package:flutter/material.dart';
import 'package:libri_audio/widgets/tts_engine_settings.dart';

/// Màn cài đặt giọng đọc: chọn bộ đọc, tải giọng offline, nhập key cloud.
class TtsSettingsScreen extends StatelessWidget {
  const TtsSettingsScreen({super.key});

  static Future<void> open(BuildContext context) {
    return Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const TtsSettingsScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Giọng đọc')),
      body: const SingleChildScrollView(child: TtsEngineSettings()),
    );
  }
}
