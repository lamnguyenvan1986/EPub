import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:libri_audio/services/tts_service.dart';

class VoiceSelector extends StatelessWidget {
  const VoiceSelector({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<TtsService>(
      builder: (context, ttsService, child) {
        final voices = ttsService.voices;
        
        if (voices.isEmpty) {
          return const Text('No voices available');
        }
        
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Select Voice:'),
            const SizedBox(height: 8),
            DropdownButton<String>(
              value: ttsService.voice,
              dropdownColor: Theme.of(context).cardColor,
              items: voices.map((voice) {
                final voiceName = voice['name'] ?? voice['locale'] as String?;
                return DropdownMenuItem<String>(
                  value: voiceName,
                  child: Text(
                    '${voice['name'] ?? 'Unknown'} (${voice['locale'] ?? 'Unknown'})',
                  ),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  ttsService.setVoice(value);
                }
              },
            ),
          ],
        );
      },
    );
  }
}
