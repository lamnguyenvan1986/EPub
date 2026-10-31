// Giọng offline: mobile/desktop dùng sherpa-onnx qua dart:ffi, web dùng
// onnxruntime-web trong Web Worker (web/piper/). Bản stub cho nền tảng khác.
export 'offline_tts_stub.dart'
    if (dart.library.io) 'offline_tts_io.dart'
    if (dart.library.js_interop) 'offline_tts_web.dart';
