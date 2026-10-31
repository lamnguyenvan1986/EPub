import 'dart:typed_data';

/// Bộ đọc mà TtsService dùng.
///
/// [system] là flutter_tts (giọng của máy). Các loại còn lại tự tạo file audio
/// rồi phát bằng NeuralTtsPlayer.
enum TtsEngineType {
  system('system', 'Giọng của máy'),
  offline('offline', 'Giọng offline (Piper)'),
  azure('azure', 'Microsoft Azure'),
  google('google', 'Google Cloud');

  final String id;
  final String label;
  const TtsEngineType(this.id, this.label);

  static TtsEngineType fromId(String? id) {
    for (final t in values) {
      if (t.id == id) return t;
    }
    return system;
  }
}

/// Audio do engine tạo ra: file trên máy (offline) hoặc bytes (cloud).
class SynthesizedAudio {
  final String? filePath;
  final Uint8List? bytes;
  final String mimeType;

  const SynthesizedAudio.file(String path)
      : filePath = path,
        bytes = null,
        mimeType = 'audio/wav';

  const SynthesizedAudio.bytes(Uint8List data, {required this.mimeType})
      : bytes = data,
        filePath = null;

  String get fileExtension => mimeType == 'audio/mpeg' ? 'mp3' : 'wav';
}

/// Engine đổi text thành audio.
abstract class NeuralTtsEngine {
  /// Độ dài tối đa mỗi lần tổng hợp. Đoạn ngắn thì bắt đầu đọc nhanh hơn.
  int get maxChunkLength;

  /// Khoá để phân biệt cache giữa các engine/giọng.
  String get cacheKey;

  Future<SynthesizedAudio> synthesize(String text);

  Future<void> dispose() async {}
}

/// Lỗi hiển thị được cho người dùng.
class TtsEngineException implements Exception {
  final String message;
  const TtsEngineException(this.message);

  @override
  String toString() => message;
}
