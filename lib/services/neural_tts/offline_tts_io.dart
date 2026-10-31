import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:flutter/foundation.dart' show visibleForTesting;

import 'package:archive/archive_io.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa;
import 'package:libri_audio/services/neural_tts/neural_tts_engine.dart';
import 'package:libri_audio/services/neural_tts/offline_voices.dart';

/// Tải, giải nén, xoá giọng Piper và tạo engine sherpa-onnx (Android/iOS/desktop).
class OfflineVoiceStore {
  static final OfflineVoiceStore _instance = OfflineVoiceStore._internal();
  factory OfflineVoiceStore() => _instance;
  OfflineVoiceStore._internal();

  bool get isSupported => true;

  Future<Directory> _rootDir() async {
    final support = await getApplicationSupportDirectory();
    return Directory(p.join(support.path, 'tts_voices'));
  }

  Future<String> _voiceDir(OfflineVoice voice) async =>
      p.join((await _rootDir()).path, voice.archiveName);

  Future<bool> isInstalled(OfflineVoice voice) async {
    final dir = await _voiceDir(voice);
    return File(p.join(dir, voice.modelFileName)).existsSync() &&
        File(p.join(dir, 'tokens.txt')).existsSync() &&
        Directory(p.join(dir, 'espeak-ng-data')).existsSync();
  }

  /// Tải file nén của giọng rồi giải nén vào thư mục của app.
  /// [onProgress] nhận 0..1 khi tải, null khi không biết dung lượng.
  Future<void> download(OfflineVoice voice, {void Function(double progress)? onProgress}) async {
    final root = await _rootDir();
    await root.create(recursive: true);
    // Tên phải kết thúc bằng .tar.bz2 để extractFileToDisk nhận dạng
    final archive = File(p.join(root.path, '${voice.archiveName}.download.tar.bz2'));
    final client = http.Client();
    try {
      final response = await client.send(http.Request('GET', Uri.parse(voice.downloadUrl)));
      if (response.statusCode != 200) {
        throw TtsEngineException('Tải giọng thất bại (mã ${response.statusCode}).');
      }
      final total = response.contentLength ?? 0;
      var received = 0;
      final sink = archive.openWrite();
      try {
        await for (final chunk in response.stream) {
          sink.add(chunk);
          received += chunk.length;
          if (total > 0) onProgress?.call(received / total);
        }
      } finally {
        await sink.close();
      }

      // Giải nén bz2 tốn CPU vài chục giây, chạy ở isolate khác cho UI không đứng
      final archivePath = archive.path;
      final rootPath = root.path;
      await Isolate.run(() => extractFileToDisk(archivePath, rootPath));
      if (!await isInstalled(voice)) {
        throw const TtsEngineException('File giọng tải về không đúng định dạng.');
      }
    } on TtsEngineException {
      rethrow;
    } on SocketException {
      throw const TtsEngineException('Không có mạng, chưa tải được giọng.');
    } catch (e) {
      throw TtsEngineException('Không tải được giọng: $e');
    } finally {
      client.close();
      if (archive.existsSync()) await archive.delete();
    }
  }

  Future<void> delete(OfflineVoice voice) async {
    final dir = Directory(await _voiceDir(voice));
    if (dir.existsSync()) await dir.delete(recursive: true);
  }

  Future<NeuralTtsEngine> createEngine(OfflineVoice voice) async {
    if (!await isInstalled(voice)) {
      throw const TtsEngineException('Chưa tải giọng offline. Vào mục Giọng đọc trong Cài đặt để tải.');
    }
    final dir = await _voiceDir(voice);
    final outDir = p.join((await getTemporaryDirectory()).path, 'tts_audio');
    await Directory(outDir).create(recursive: true);
    return OfflineTtsEngine._spawn(
      voiceId: voice.id,
      model: p.join(dir, voice.modelFileName),
      tokens: p.join(dir, 'tokens.txt'),
      dataDir: p.join(dir, 'espeak-ng-data'),
      outDir: outDir,
    );
  }
}

/// sherpa-onnx chạy trong một isolate riêng: generate() chặn luồng đến khi xong,
/// nên không gọi ở isolate UI. Isolate giữ model trong bộ nhớ giữa các lần đọc.
class OfflineTtsEngine extends NeuralTtsEngine {
  final String voiceId;
  final Isolate _isolate;
  final SendPort _commands;
  final ReceivePort _responses;
  final Map<int, Completer<String>> _pending = {};
  int _nextId = 0;

  OfflineTtsEngine._(this.voiceId, this._isolate, this._commands, this._responses);

  /// Tạo engine từ các file model có sẵn (dùng trong test).
  @visibleForTesting
  static Future<OfflineTtsEngine> spawnForTest({
    required String voiceId,
    required String model,
    required String tokens,
    required String dataDir,
    required String outDir,
  }) =>
      _spawn(voiceId: voiceId, model: model, tokens: tokens, dataDir: dataDir, outDir: outDir);

  static Future<OfflineTtsEngine> _spawn({
    required String voiceId,
    required String model,
    required String tokens,
    required String dataDir,
    required String outDir,
  }) async {
    final responses = ReceivePort();
    // Tin nhắn đầu tiên: SendPort của worker, hoặc chuỗi lỗi nếu không nạp được model.
    // Các tin sau là kết quả tổng hợp. ReceivePort chỉ listen được một lần.
    final ready = Completer<Object?>();
    void Function(dynamic msg)? onReply;
    responses.listen((msg) {
      if (!ready.isCompleted) {
        ready.complete(msg);
      } else {
        onReply?.call(msg);
      }
    });
    final isolate = await Isolate.spawn(
      _workerMain,
      [responses.sendPort, model, tokens, dataDir, outDir],
    );
    final first = await ready.future;
    if (first is! SendPort) {
      isolate.kill(priority: Isolate.immediate);
      responses.close();
      throw TtsEngineException('Không nạp được giọng offline: $first');
    }
    final engine = OfflineTtsEngine._(voiceId, isolate, first, responses);
    onReply = engine._onResponse;
    return engine;
  }

  void _onResponse(dynamic msg) {
    final list = msg as List;
    final completer = _pending.remove(list[0] as int);
    if (completer == null) return;
    if (list[1] == true) {
      completer.complete(list[2] as String);
    } else {
      completer.completeError(TtsEngineException('Lỗi đọc offline: ${list[2]}'));
    }
  }

  @override
  // Đoạn ngắn để câu đầu tiên phát ra nhanh trên điện thoại yếu
  int get maxChunkLength => 300;

  @override
  String get cacheKey => 'offline:$voiceId';

  @override
  Future<SynthesizedAudio> synthesize(String text) async {
    final id = _nextId++;
    final completer = Completer<String>();
    _pending[id] = completer;
    _commands.send([id, text]);
    return SynthesizedAudio.file(await completer.future);
  }

  @override
  Future<void> dispose() async {
    _isolate.kill(priority: Isolate.immediate);
    _responses.close();
    for (final c in _pending.values) {
      c.completeError(const TtsEngineException('Đã dừng đọc offline.'));
    }
    _pending.clear();
  }
}

/// Hàm chạy trong isolate worker.
/// args: [SendPort, model, tokens, dataDir, outDir]
void _workerMain(List<Object> args) {
  final replyPort = args[0] as SendPort;
  final outDir = args[4] as String;
  final sherpa.OfflineTts tts;
  try {
    sherpa.initBindings();
    tts = sherpa.OfflineTts(sherpa.OfflineTtsConfig(
      model: sherpa.OfflineTtsModelConfig(
        vits: sherpa.OfflineTtsVitsModelConfig(
          model: args[1] as String,
          tokens: args[2] as String,
          dataDir: args[3] as String,
        ),
        numThreads: 2,
        debug: false,
      ),
    ));
  } catch (e) {
    replyPort.send(e.toString());
    return;
  }

  final commands = ReceivePort();
  var fileIndex = 0;
  replyPort.send(commands.sendPort);
  commands.listen((msg) {
    final list = msg as List;
    final id = list[0] as int;
    try {
      final audio = tts.generate(text: list[1] as String, sid: 0, speed: 1.0);
      if (audio.samples.isEmpty) throw StateError('không tạo được audio');
      // Xoay vòng tên file để thư mục tạm không phình ra
      final path = p.join(outDir, 'offline_${fileIndex++ % 16}.wav');
      sherpa.writeWave(filename: path, samples: audio.samples, sampleRate: audio.sampleRate);
      replyPort.send([id, true, path]);
    } catch (e) {
      replyPort.send([id, false, e.toString()]);
    }
  });
}
