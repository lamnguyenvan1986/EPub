import 'dart:async';

import 'package:just_audio/just_audio.dart';
import 'package:libri_audio/services/neural_tts/audio_source.dart';
import 'package:libri_audio/services/neural_tts/neural_tts_engine.dart';

/// Đọc một đoạn bằng [NeuralTtsEngine]: chia đoạn thành câu ngắn, tổng hợp
/// trước câu kế tiếp trong lúc đang phát câu hiện tại, phát bằng just_audio.
class NeuralTtsPlayer {
  static const int _cacheSize = 8;

  final AudioPlayer _player = AudioPlayer();
  NeuralTtsEngine? _engine;
  double _speed = 1.0;

  // Tăng mỗi lần speak()/stop() để huỷ lượt đọc cũ đang chờ tổng hợp
  int _generation = 0;

  // Cache theo thứ tự chèn, bỏ phần tử cũ nhất khi đầy
  final Map<String, Future<SynthesizedAudio>> _cache = {};

  NeuralTtsEngine? get engine => _engine;

  /// Đổi engine (null = không dùng). Engine cũ được dispose.
  Future<void> setEngine(NeuralTtsEngine? engine) async {
    if (identical(engine, _engine)) return;
    await stop();
    final old = _engine;
    _engine = engine;
    await _clearCache();
    await old?.dispose();
  }

  /// Tốc độ phát (1.0 = bình thường). just_audio giữ nguyên cao độ khi đổi tốc độ.
  Future<void> setSpeed(double speed) async {
    _speed = speed;
    try {
      await _player.setSpeed(speed);
    } catch (_) {
      // Chưa có audio nào được nạp
    }
  }

  /// Đọc hết [text]. Trả về true nếu đọc xong, false nếu bị dừng giữa chừng.
  /// [nextText] là đoạn sẽ đọc tiếp theo, dùng để tổng hợp sẵn câu đầu của nó.
  Future<bool> speak(
    String text, {
    String? nextText,
    required List<String> Function(String text, {int maxLength}) splitter,
  }) async {
    final engine = _engine;
    if (engine == null) throw const TtsEngineException('Chưa chọn giọng đọc.');
    final gen = ++_generation;
    final parts = splitter(text, maxLength: engine.maxChunkLength);

    for (var i = 0; i < parts.length; i++) {
      final audio = await _synthesize(engine, parts[i]);
      if (gen != _generation) return false;

      // Tổng hợp sẵn câu sau để không bị ngắt quãng giữa các câu
      if (i + 1 < parts.length) {
        _prefetch(engine, parts[i + 1]);
      } else if (nextText != null && nextText.trim().isNotEmpty) {
        final next = splitter(nextText, maxLength: engine.maxChunkLength);
        if (next.isNotEmpty) _prefetch(engine, next.first);
      }

      await _player.setAudioSource(await audioSourceFor(audio));
      if (gen != _generation) return false;
      await _player.setSpeed(_speed);
      // play() trả về khi phát xong hoặc khi bị pause/stop
      await _player.play();
      if (gen != _generation) return false;
      // Sau khi phát xong player vẫn ở trạng thái playing; pause để lần play() sau chạy lại
      await _player.pause();
    }
    return gen == _generation;
  }

  Future<void> stop() async {
    _generation++;
    try {
      await _player.stop();
    } catch (_) {
      // Player chưa từng phát
    }
  }

  Future<SynthesizedAudio> _synthesize(NeuralTtsEngine engine, String text) {
    final key = '${engine.cacheKey}|$text';
    final cached = _cache.remove(key);
    final future = cached ?? engine.synthesize(text);
    _cache[key] = future;
    // Lỗi không được giữ trong cache để lần sau thử lại
    future.then((_) {}, onError: (Object _) {
      if (identical(_cache[key], future)) _cache.remove(key);
    });
    while (_cache.length > _cacheSize) {
      final oldest = _cache.keys.first;
      final evicted = _cache.remove(oldest)!;
      evicted.then(releaseAudio, onError: (_) {});
    }
    return future;
  }

  void _prefetch(NeuralTtsEngine engine, String text) {
    // Lỗi (nếu có) sẽ báo khi tới lượt đọc câu này
    _synthesize(engine, text).then((_) {}, onError: (Object _) {});
  }

  Future<void> _clearCache() async {
    final entries = _cache.values.toList();
    _cache.clear();
    for (final f in entries) {
      f.then(releaseAudio, onError: (_) {});
    }
  }

  Future<void> dispose() async {
    await setEngine(null);
    await _player.dispose();
  }
}
