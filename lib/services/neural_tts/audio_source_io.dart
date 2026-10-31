import 'dart:io';

import 'package:just_audio/just_audio.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:libri_audio/services/neural_tts/neural_tts_engine.dart';

int _fileIndex = 0;
final Map<SynthesizedAudio, String> _tempFiles = {};

/// Mobile: AVPlayer trên iOS không phát data URI ổn định, nên ghi bytes ra file tạm.
Future<AudioSource> audioSourceFor(SynthesizedAudio audio) async {
  final path = audio.filePath ?? await _writeTemp(audio);
  return AudioSource.file(path);
}

Future<String> _writeTemp(SynthesizedAudio audio) async {
  final existing = _tempFiles[audio];
  if (existing != null) return existing;
  final dir = Directory(p.join((await getTemporaryDirectory()).path, 'tts_audio'));
  await dir.create(recursive: true);
  final path = p.join(dir.path, 'cloud_${_fileIndex++}.${audio.fileExtension}');
  await File(path).writeAsBytes(audio.bytes!, flush: true);
  _tempFiles[audio] = path;
  return path;
}

/// Xoá file tạm của audio cloud khi không còn trong cache.
Future<void> releaseAudio(SynthesizedAudio audio) async {
  final path = _tempFiles.remove(audio);
  if (path == null) return;
  try {
    await File(path).delete();
  } catch (_) {
    // File đã bị xoá hoặc hệ thống dọn thư mục tạm
  }
}
