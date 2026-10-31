import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:libri_audio/services/neural_tts/cloud_tts_engine.dart';
import 'package:libri_audio/services/neural_tts/neural_tts_engine.dart';
import 'package:libri_audio/services/neural_tts/offline_tts_io.dart';
import 'package:libri_audio/services/neural_tts/offline_voices.dart';

void main() {
  group('TtsEngineType', () {
    test('fromId trả về system khi id lạ hoặc null', () {
      expect(TtsEngineType.fromId('azure'), TtsEngineType.azure);
      expect(TtsEngineType.fromId('offline'), TtsEngineType.offline);
      expect(TtsEngineType.fromId(null), TtsEngineType.system);
      expect(TtsEngineType.fromId('khong-co'), TtsEngineType.system);
    });
  });

  group('Giọng offline', () {
    test('URL tải và tên file model theo đúng bản phát hành sherpa-onnx', () {
      final v = offlineVoiceById('vi_VN-vais1000-medium');
      expect(v.downloadUrl,
          'https://github.com/k2-fsa/sherpa-onnx/releases/download/tts-models/vits-piper-vi_VN-vais1000-medium.tar.bz2');
      expect(v.modelFileName, 'vi_VN-vais1000-medium.onnx');
      expect(offlineVoiceById('khong-co').id, offlineViVoices.first.id);
    });
  });

  group('AzureTtsEngine', () {
    test('gửi SSML đã escape và trả MP3', () async {
      late http.Request sent;
      final client = MockClient((request) async {
        sent = request;
        return http.Response.bytes([1, 2, 3], 200);
      });
      final engine = AzureTtsEngine(
          apiKey: 'k', voice: 'vi-VN-HoaiMyNeural', region: 'eastasia', client: client);
      final audio = await engine.synthesize('A & B <c>');

      expect(sent.url.toString(), 'https://eastasia.tts.speech.microsoft.com/cognitiveservices/v1');
      expect(sent.headers['Ocp-Apim-Subscription-Key'], 'k');
      expect(sent.body, contains('A &amp; B &lt;c&gt;'));
      expect(sent.body, contains("name='vi-VN-HoaiMyNeural'"));
      expect(audio.bytes, [1, 2, 3]);
      expect(audio.mimeType, 'audio/mpeg');
    });

    test('vùng trống dùng vùng mặc định', () {
      final engine = AzureTtsEngine(apiKey: 'k', voice: 'v', region: '  ');
      expect(engine.region, azureDefaultRegion);
    });

    test('key sai báo lỗi dễ hiểu', () async {
      final client = MockClient((_) async => http.Response('', 401));
      final engine = AzureTtsEngine(apiKey: 'k', voice: 'v', client: client);
      expect(
        () => engine.synthesize('xin chào'),
        throwsA(isA<TtsEngineException>()
            .having((e) => e.message, 'message', contains('Key Azure'))),
      );
    });
  });

  group('GoogleTtsEngine', () {
    test('giải mã audioContent base64', () async {
      late http.Request sent;
      final client = MockClient((request) async {
        sent = request;
        return http.Response(jsonEncode({'audioContent': base64Encode([9, 8, 7])}), 200);
      });
      final engine = GoogleTtsEngine(apiKey: 'abc', voice: 'vi-VN-Neural2-A', client: client);
      final audio = await engine.synthesize('Xin chào');

      expect(sent.url.queryParameters['key'], 'abc');
      final body = jsonDecode(sent.body) as Map<String, dynamic>;
      expect(body['input']['text'], 'Xin chào');
      expect(body['voice']['name'], 'vi-VN-Neural2-A');
      expect(audio.bytes, [9, 8, 7]);
    });

    test('lỗi 429 báo giới hạn', () async {
      final client = MockClient((_) async => http.Response('', 429));
      final engine = GoogleTtsEngine(apiKey: 'abc', voice: 'v', client: client);
      expect(
        () => engine.synthesize('a'),
        throwsA(isA<TtsEngineException>()
            .having((e) => e.message, 'message', contains('giới hạn'))),
      );
    });
  });

  // Cần file model thật: đặt PIPER_VI_MODEL_DIR trỏ tới thư mục đã giải nén
  // vits-piper-vi_VN-vais1000-medium thì test mới chạy.
  final modelDir = Platform.environment['PIPER_VI_MODEL_DIR'];
  test('OfflineTtsEngine tạo file WAV từ text tiếng Việt', () async {
    final dir = Directory(modelDir!);
    final onnx = dir.listSync().whereType<File>().firstWhere((f) => f.path.endsWith('.onnx'));
    final out = await Directory.systemTemp.createTemp('tts_test');
    final engine = await OfflineTtsEngine.spawnForTest(
      voiceId: 'test',
      model: onnx.path,
      tokens: '${dir.path}/tokens.txt',
      dataDir: '${dir.path}/espeak-ng-data',
      outDir: out.path,
    );
    try {
      final first = await engine.synthesize('Xin chào, đây là giọng đọc sách.');
      final second = await engine.synthesize('Câu thứ hai.');
      expect(first.filePath, isNot(second.filePath));
      final wav = File(first.filePath!).readAsBytesSync();
      expect(ascii.decode(wav.sublist(0, 4)), 'RIFF');
      expect(wav.length, greaterThan(10000));
    } finally {
      await engine.dispose();
      await out.delete(recursive: true);
    }
  }, skip: modelDir == null ? 'Chưa đặt PIPER_VI_MODEL_DIR' : false);
}
