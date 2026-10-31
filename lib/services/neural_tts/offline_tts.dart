// Giọng offline dùng dart:ffi nên chỉ có trên Android/iOS/desktop; web dùng bản stub.
export 'offline_tts_stub.dart' if (dart.library.io) 'offline_tts_io.dart';
