import 'package:audio_service/audio_service.dart';
import 'package:libri_audio/services/tts_service.dart';

/// Nối TtsService với audio_service: giữ app chạy nền (foreground service trên
/// Android), hiện thông báo điều khiển và nhận nút tai nghe / màn hình khoá.
class TtsAudioHandler extends BaseAudioHandler {
  final TtsService _tts;

  TtsAudioHandler(this._tts) {
    _tts.addListener(_broadcastState);
    _broadcastState();
  }

  void _broadcastState() {
    final playing = _tts.isSpeaking;
    playbackState.add(playbackState.value.copyWith(
      controls: [
        MediaControl.skipToPrevious,
        playing ? MediaControl.pause : MediaControl.play,
        MediaControl.stop,
        MediaControl.skipToNext,
      ],
      systemActions: const {
        MediaAction.skipToPrevious,
        MediaAction.skipToNext,
      },
      androidCompactActionIndices: const [0, 1, 3],
      processingState: _tts.hasQueue ? AudioProcessingState.ready : AudioProcessingState.idle,
      playing: playing,
    ));

    final title = _tts.nowPlayingTitle;
    final current = mediaItem.value;
    if (title == null) {
      if (current != null) mediaItem.add(null);
    } else if (current?.title != title || current?.album != _tts.nowPlayingSubtitle) {
      mediaItem.add(MediaItem(
        id: title,
        title: title,
        album: _tts.nowPlayingSubtitle,
      ));
    }
  }

  @override
  Future<void> play() => _tts.resume();

  @override
  Future<void> pause() => _tts.pause();

  @override
  Future<void> stop() async {
    await _tts.stop();
    await super.stop();
  }

  @override
  Future<void> skipToNext() => _tts.skipNext();

  @override
  Future<void> skipToPrevious() => _tts.skipPrevious();
}
