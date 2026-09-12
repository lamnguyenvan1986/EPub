import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:libri_audio/services/tts_service.dart';

class AudioFloatingControls extends StatelessWidget {
  final VoidCallback onClose;
  
  const AudioFloatingControls({super.key, required this.onClose});

  @override
  Widget build(BuildContext context) {
    return Consumer<TtsService>(
      builder: (context, ttsService, child) {
        return AnimatedPositioned(
          duration: const Duration(milliseconds: 300),
          bottom: 0,
          left: 0,
          right: 0,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 10,
                  offset: const Offset(0, -5),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                IconButton(
                  icon: const Icon(Icons.skip_previous),
                  onPressed: () => _goToPreviousChapter(ttsService),
                  color: Theme.of(context).colorScheme.primary,
                ),
                IconButton(
                  icon: Icon(
                    ttsService.isSpeaking ? Icons.pause : Icons.play_arrow,
                    size: 48,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  onPressed: () {
                    if (ttsService.isSpeaking) {
                      ttsService.pause();
                    } else {
                      ttsService.speak('Đang đọc');
                    }
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.skip_next),
                  onPressed: () => _goToNextChapter(ttsService),
                  color: Theme.of(context).colorScheme.primary,
                ),
                IconButton(
                  icon: const Icon(Icons.volume_up),
                  onPressed: onClose,
                  color: Colors.red,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
  
  void _goToPreviousChapter(TtsService ttsService) {
    ttsService.stop();
  }
  
  void _goToNextChapter(TtsService ttsService) {
    ttsService.stop();
  }
}
