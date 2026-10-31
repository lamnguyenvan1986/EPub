import 'package:libri_audio/services/neural_tts/neural_tts_engine.dart';
import 'package:libri_audio/services/neural_tts/offline_voices.dart';

/// Bản web: chưa hỗ trợ giọng offline (sherpa-onnx cần file model trên máy).
class OfflineVoiceStore {
  static final OfflineVoiceStore _instance = OfflineVoiceStore._internal();
  factory OfflineVoiceStore() => _instance;
  OfflineVoiceStore._internal();

  bool get isSupported => false;

  Future<bool> isInstalled(OfflineVoice voice) async => false;

  Future<void> download(OfflineVoice voice, {void Function(double progress)? onProgress}) async {
    throw const TtsEngineException('Giọng offline chưa dùng được trên bản web.');
  }

  Future<void> delete(OfflineVoice voice) async {}

  Future<NeuralTtsEngine> createEngine(OfflineVoice voice) async {
    throw const TtsEngineException('Giọng offline chưa dùng được trên bản web.');
  }
}
