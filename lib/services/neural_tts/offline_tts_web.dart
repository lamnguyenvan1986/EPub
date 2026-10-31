import 'dart:js_interop';
import 'dart:typed_data';

import 'package:libri_audio/services/neural_tts/neural_tts_engine.dart';
import 'package:libri_audio/services/neural_tts/offline_voices.dart';

/// window.libriPiper do web/piper/piper_bridge.js tạo ra.
@JS('libriPiper')
external _LibriPiper? get _piper;

extension type _LibriPiper._(JSObject _object) implements JSObject {
  external bool isSupported();
  external JSPromise<JSBoolean> isInstalled(JSArray<JSString> urls);
  external JSPromise<JSAny?> download(JSArray<JSString> urls, JSFunction onProgress);
  external JSPromise<JSAny?> remove(JSArray<JSString> urls);
  external JSPromise<JSAny?> load(String modelUrl, String configUrl);
  external JSPromise<JSArrayBuffer> synthesize(String text);
}

JSArray<JSString> _urls(OfflineVoice voice) =>
    [voice.webModelUrl.toJS, voice.webConfigUrl.toJS].toJS;

/// Lỗi từ JS (Error) thành thông báo đọc được: toString() của Error có dạng "Error: message".
String _jsMessage(Object e) {
  final text = e.toString();
  return text.startsWith('Error: ') ? text.substring(7) : text;
}

/// Bản web: model Piper lưu trong Cache Storage của trình duyệt, chạy bằng
/// onnxruntime-web trong Web Worker.
class OfflineVoiceStore {
  static final OfflineVoiceStore _instance = OfflineVoiceStore._internal();
  factory OfflineVoiceStore() => _instance;
  OfflineVoiceStore._internal();

  _LibriPiper? get _bridge {
    final piper = _piper;
    if (piper == null || !piper.isSupported()) return null;
    return piper;
  }

  bool get isSupported => _bridge != null;

  _LibriPiper _require() {
    final bridge = _bridge;
    if (bridge == null) {
      throw const TtsEngineException('Trình duyệt này không chạy được giọng offline.');
    }
    return bridge;
  }

  Future<bool> isInstalled(OfflineVoice voice) async {
    final bridge = _bridge;
    if (bridge == null) return false;
    try {
      return (await bridge.isInstalled(_urls(voice)).toDart).toDart;
    } catch (_) {
      return false;
    }
  }

  Future<void> download(OfflineVoice voice, {void Function(double progress)? onProgress}) async {
    final bridge = _require();
    void report(JSNumber progress) => onProgress?.call(progress.toDartDouble);
    try {
      await bridge.download(_urls(voice), report.toJS).toDart;
    } catch (e) {
      final message = _jsMessage(e);
      if (message.contains('Failed to fetch') || message.contains('NetworkError')) {
        throw const TtsEngineException('Không có mạng, chưa tải được giọng.');
      }
      throw TtsEngineException('Không tải được giọng: $message');
    }
  }

  Future<void> delete(OfflineVoice voice) async {
    final bridge = _bridge;
    if (bridge == null) return;
    await bridge.remove(_urls(voice)).toDart;
  }

  Future<NeuralTtsEngine> createEngine(OfflineVoice voice) async {
    final bridge = _require();
    if (!await isInstalled(voice)) {
      throw const TtsEngineException('Chưa tải giọng offline. Vào mục Giọng đọc trong Cài đặt để tải.');
    }
    try {
      await bridge.load(voice.webModelUrl, voice.webConfigUrl).toDart;
    } catch (e) {
      throw TtsEngineException('Không nạp được giọng offline: ${_jsMessage(e)}');
    }
    return _WebOfflineTtsEngine(bridge, voice.id);
  }
}

class _WebOfflineTtsEngine extends NeuralTtsEngine {
  final _LibriPiper _bridge;
  final String voiceId;

  _WebOfflineTtsEngine(this._bridge, this.voiceId);

  @override
  int get maxChunkLength => 300;

  @override
  String get cacheKey => 'offline:$voiceId';

  @override
  Future<SynthesizedAudio> synthesize(String text) async {
    try {
      final buffer = await _bridge.synthesize(text).toDart;
      return SynthesizedAudio.bytes(Uint8List.view(buffer.toDart), mimeType: 'audio/wav');
    } catch (e) {
      throw TtsEngineException('Lỗi đọc offline: ${_jsMessage(e)}');
    }
  }
}
