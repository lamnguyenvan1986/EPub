import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:libri_audio/screens/tts_settings_screen.dart';
import 'package:libri_audio/services/neural_tts/cloud_tts_engine.dart';
import 'package:libri_audio/services/neural_tts/neural_tts_engine.dart';
import 'package:libri_audio/services/neural_tts/offline_voices.dart';
import 'package:libri_audio/services/tts_service.dart';

/// Chọn nhanh bộ đọc và giọng (màn đọc sách). Tải giọng offline và nhập key
/// cloud nằm ở TtsSettingsScreen.
class VoiceSelector extends StatelessWidget {
  const VoiceSelector({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<TtsService>(
      builder: (context, tts, child) {
        final engines = TtsEngineType.values
            .where((t) => t != TtsEngineType.offline || tts.offlineSupported)
            .toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Bộ đọc:'),
            DropdownButton<TtsEngineType>(
              value: tts.engineType,
              isExpanded: true,
              dropdownColor: Theme.of(context).cardColor,
              items: [
                for (final t in engines) DropdownMenuItem(value: t, child: Text(t.label)),
              ],
              onChanged: (value) {
                if (value != null) tts.setEngineType(value);
              },
            ),
            const SizedBox(height: 8),
            const Text('Giọng:'),
            _voiceDropdown(context, tts),
            TextButton.icon(
              icon: const Icon(Icons.tune),
              label: const Text('Tải giọng, nhập key, nghe thử'),
              onPressed: () => TtsSettingsScreen.open(context),
            ),
          ],
        );
      },
    );
  }

  Widget _voiceDropdown(BuildContext context, TtsService tts) {
    switch (tts.engineType) {
      case TtsEngineType.system:
        return _systemVoices(context, tts);
      case TtsEngineType.offline:
        final installed =
            offlineViVoices.where((v) => tts.isOfflineVoiceInstalled(v.id)).toList();
        if (installed.isEmpty) {
          return const Text('Chưa tải giọng offline nào. Bấm nút bên dưới để tải.');
        }
        return _dropdown(
          context,
          value: tts.offlineVoiceId,
          items: {for (final v in installed) v.id: v.label},
          onChanged: tts.setOfflineVoice,
        );
      case TtsEngineType.azure:
        if (!tts.hasAzureKey) return const Text('Chưa nhập key Azure. Bấm nút bên dưới để nhập.');
        return _dropdown(
          context,
          value: tts.azureVoice,
          items: {for (final v in azureViVoices) v.id: v.label},
          onChanged: (v) => tts.setAzureConfig(voice: v),
        );
      case TtsEngineType.google:
        if (!tts.hasGoogleKey) return const Text('Chưa nhập key Google Cloud. Bấm nút bên dưới để nhập.');
        return _dropdown(
          context,
          value: tts.googleVoice,
          items: {for (final v in googleViVoices) v.id: v.label},
          onChanged: (v) => tts.setGoogleConfig(voice: v),
        );
    }
  }

  Widget _dropdown(
    BuildContext context, {
    required String value,
    required Map<String, String> items,
    required void Function(String value) onChanged,
  }) {
    return DropdownButton<String>(
      // Giá trị đang chọn phải có trong danh sách, nếu không DropdownButton sẽ assert
      value: items.containsKey(value) ? value : null,
      isExpanded: true,
      dropdownColor: Theme.of(context).cardColor,
      items: [
        for (final e in items.entries) DropdownMenuItem(value: e.key, child: Text(e.value)),
      ],
      onChanged: (v) {
        if (v != null) onChanged(v);
      },
    );
  }

  Widget _systemVoices(BuildContext context, TtsService tts) {
    final voices = tts.voices;
    if (voices.isEmpty) {
      return const Text('Máy không có giọng nào');
    }

    // Mỗi value chỉ xuất hiện một lần
    final items = <String, String>{};
    for (final voice in voices) {
      final voiceName = voice['name']?.toString();
      if (voiceName == null || items.containsKey(voiceName)) continue;
      items[voiceName] = '$voiceName (${voice['locale'] ?? 'Unknown'})';
    }

    return DropdownButton<String>(
      value: items.containsKey(tts.voice) ? tts.voice : null,
      hint: const Text('Giọng mặc định'),
      isExpanded: true,
      dropdownColor: Theme.of(context).cardColor,
      items: [
        for (final e in items.entries) DropdownMenuItem(value: e.key, child: Text(e.value)),
      ],
      onChanged: (value) {
        if (value != null) tts.setVoice(value);
      },
    );
  }
}
