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
        
        // Mỗi value chỉ xuất hiện một lần, và value đang chọn phải có trong danh sách,
        // nếu không DropdownButton sẽ assert.
        final seen = <String>{};
        final items = <DropdownMenuItem<String>>[];
        for (final voice in voices) {
          final voiceName = voice['name']?.toString();
          if (voiceName == null || !seen.add(voiceName)) continue;
          items.add(DropdownMenuItem<String>(
            value: voiceName,
            child: Text('$voiceName (${voice['locale'] ?? 'Unknown'})'),
          ));
        }
        final selected = seen.contains(ttsService.voice) ? ttsService.voice : null;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Select Voice:'),
            const SizedBox(height: 8),
            DropdownButton<String>(
              value: selected,
              hint: const Text('Giọng mặc định'),
              isExpanded: true,
              dropdownColor: Theme.of(context).cardColor,
              items: items,
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
