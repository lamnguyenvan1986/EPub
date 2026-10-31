import 'dart:convert';

import 'package:just_audio/just_audio.dart';
import 'package:libri_audio/services/neural_tts/neural_tts_engine.dart';

/// Web: phát bytes qua data URI (thẻ <audio> của trình duyệt đọc được).
Future<AudioSource> audioSourceFor(SynthesizedAudio audio) async {
  final bytes = audio.bytes;
  if (bytes == null) {
    throw const TtsEngineException('Không có dữ liệu audio.');
  }
  return AudioSource.uri(Uri.parse('data:${audio.mimeType};base64,${base64Encode(bytes)}'));
}

/// Web không có file tạm cần xoá.
Future<void> releaseAudio(SynthesizedAudio audio) async {}
