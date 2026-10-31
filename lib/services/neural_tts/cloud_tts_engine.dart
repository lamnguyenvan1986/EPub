import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:libri_audio/services/neural_tts/neural_tts_engine.dart';

/// Một giọng cloud: id gửi lên API và tên hiển thị.
class CloudVoice {
  final String id;
  final String label;
  const CloudVoice(this.id, this.label);
}

const List<CloudVoice> azureViVoices = [
  CloudVoice('vi-VN-HoaiMyNeural', 'Hoài My (nữ)'),
  CloudVoice('vi-VN-NamMinhNeural', 'Nam Minh (nam)'),
];

const List<CloudVoice> googleViVoices = [
  CloudVoice('vi-VN-Chirp3-HD-Aoede', 'Chirp3 HD Aoede (nữ)'),
  CloudVoice('vi-VN-Chirp3-HD-Charon', 'Chirp3 HD Charon (nam)'),
  CloudVoice('vi-VN-Neural2-A', 'Neural2 A (nữ)'),
  CloudVoice('vi-VN-Neural2-D', 'Neural2 D (nam)'),
  CloudVoice('vi-VN-Wavenet-A', 'WaveNet A (nữ)'),
  CloudVoice('vi-VN-Wavenet-B', 'WaveNet B (nam)'),
];

const String azureDefaultRegion = 'southeastasia';

String _httpErrorMessage(String service, http.Response response) {
  switch (response.statusCode) {
    case 400:
      // Google trả key sai bằng mã 400, kèm lý do trong error.message
      return '$service từ chối yêu cầu (400). Kiểm tra lại key và giọng đã chọn.'
          '${_serverMessage(response)}';
    case 401:
    case 403:
      return 'Key $service không đúng hoặc chưa bật dịch vụ Text-to-Speech.';
    case 429:
      return '$service đang giới hạn số lần gọi, thử lại sau ít phút.';
    default:
      return '$service lỗi ${response.statusCode}.';
  }
}

String _serverMessage(http.Response response) {
  try {
    final message = (jsonDecode(response.body) as Map<String, dynamic>)['error']?['message'];
    if (message is String && message.isNotEmpty) return ' ($message)';
  } catch (_) {
    // Body không phải JSON
  }
  return '';
}

/// Azure Speech qua REST API, trả về MP3.
class AzureTtsEngine extends NeuralTtsEngine {
  final String apiKey;
  final String region;
  final String voice;
  final http.Client _client;

  AzureTtsEngine({
    required this.apiKey,
    required this.voice,
    String? region,
    http.Client? client,
  })  : region = (region == null || region.trim().isEmpty)
            ? azureDefaultRegion
            : region.trim(),
        _client = client ?? http.Client();

  @override
  int get maxChunkLength => 1000;

  @override
  String get cacheKey => 'azure:$region:$voice';

  /// SSML cho một đoạn text, đã escape ký tự XML.
  static String buildSsml(String text, String voice) {
    const escape = HtmlEscape(HtmlEscapeMode.element);
    return "<speak version='1.0' xml:lang='vi-VN'>"
        "<voice name='$voice'>${escape.convert(text)}</voice></speak>";
  }

  @override
  Future<SynthesizedAudio> synthesize(String text) async {
    final http.Response response;
    try {
      response = await _client.post(
        Uri.parse('https://$region.tts.speech.microsoft.com/cognitiveservices/v1'),
        headers: {
          'Ocp-Apim-Subscription-Key': apiKey,
          'Content-Type': 'application/ssml+xml',
          'X-Microsoft-OutputFormat': 'audio-24khz-48kbitrate-mono-mp3',
        },
        body: utf8.encode(buildSsml(text, voice)),
      );
    } catch (e) {
      throw const TtsEngineException('Không kết nối được Azure. Kiểm tra mạng và vùng (region).');
    }
    if (response.statusCode != 200) {
      throw TtsEngineException(_httpErrorMessage('Azure', response));
    }
    return SynthesizedAudio.bytes(response.bodyBytes, mimeType: 'audio/mpeg');
  }

  @override
  Future<void> dispose() async => _client.close();
}

/// Google Cloud Text-to-Speech qua REST API với API key, trả về MP3.
class GoogleTtsEngine extends NeuralTtsEngine {
  final String apiKey;
  final String voice;
  final http.Client _client;

  GoogleTtsEngine({required this.apiKey, required this.voice, http.Client? client})
      : _client = client ?? http.Client();

  @override
  // Google giới hạn 5000 byte mỗi yêu cầu, chữ Việt mất 1-3 byte mỗi ký tự
  int get maxChunkLength => 1000;

  @override
  String get cacheKey => 'google:$voice';

  @override
  Future<SynthesizedAudio> synthesize(String text) async {
    final http.Response response;
    try {
      response = await _client.post(
        Uri.parse('https://texttospeech.googleapis.com/v1/text:synthesize')
            .replace(queryParameters: {'key': apiKey}),
        headers: {'Content-Type': 'application/json; charset=utf-8'},
        body: jsonEncode({
          'input': {'text': text},
          'voice': {'languageCode': 'vi-VN', 'name': voice},
          'audioConfig': {'audioEncoding': 'MP3'},
        }),
      );
    } catch (e) {
      throw const TtsEngineException('Không kết nối được Google Cloud. Kiểm tra mạng.');
    }
    if (response.statusCode != 200) {
      throw TtsEngineException(_httpErrorMessage('Google Cloud', response));
    }
    final content = (jsonDecode(response.body) as Map<String, dynamic>)['audioContent'];
    if (content is! String || content.isEmpty) {
      throw const TtsEngineException('Google Cloud không trả về audio.');
    }
    return SynthesizedAudio.bytes(base64Decode(content), mimeType: 'audio/mpeg');
  }

  @override
  Future<void> dispose() async => _client.close();
}
