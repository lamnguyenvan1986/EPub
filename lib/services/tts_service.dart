import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;
import 'package:audio_session/audio_session.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:libri_audio/services/neural_tts/cloud_tts_engine.dart';
import 'package:libri_audio/services/neural_tts/neural_tts_engine.dart';
import 'package:libri_audio/services/neural_tts/neural_tts_player.dart';
import 'package:libri_audio/services/neural_tts/offline_tts.dart';
import 'package:libri_audio/services/neural_tts/offline_voices.dart';
import 'package:libri_audio/services/storage_service.dart';

/// Đọc văn bản theo từng đoạn ngắn, bằng giọng của máy (flutter_tts) hoặc
/// giọng offline/cloud (NeuralTtsPlayer).
///
/// Android giới hạn độ dài mỗi lần speak() (khoảng 4000 ký tự), nên text dài
/// được chia thành hàng đợi các đoạn và đọc nối tiếp qua completion handler.
class TtsService extends ChangeNotifier {
  static const String _azureKeyName = 'azure_tts_key';
  static const String _googleKeyName = 'google_tts_key';

  /// Độ dài tối đa của một đoạn, thấp hơn giới hạn 4000 ký tự của Android.
  static const int MAX_CHUNK_LENGTH = 3000;

  final FlutterTts _tts = FlutterTts();
  bool _isSpeaking = false;
  double _rate = 1.0;
  double _pitch = 1.0;
  String _selectedVoice = '';
  String _language = 'vi-VN';

  // Bộ đọc offline/cloud
  final NeuralTtsPlayer _neural = NeuralTtsPlayer();
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  TtsEngineType _engineType = TtsEngineType.system;
  String _offlineVoiceId = offlineViVoices.first.id;
  String _azureVoice = azureViVoices.first.id;
  String _azureRegion = azureDefaultRegion;
  String _azureKey = '';
  String _googleVoice = googleViVoices.first.id;
  String _googleKey = '';
  Future<void>? _engineLoading;
  // Engine lỗi (mất mạng, sai key...): đọc tiếp bằng giọng máy đến lần đọc sau
  bool _fallbackToSystem = false;
  String? _engineError;
  // Tăng mỗi lần bắt đầu một đoạn, để bỏ qua kết quả của lượt đọc cũ
  int _speakToken = 0;
  final Set<String> _installedOfflineVoices = {};
  String? _downloadingVoiceId;
  double? _downloadProgress;

  final List<String> _languages = ['vi-VN', 'en-US'];
  List<Map<String, dynamic>> _voices = [];

  // Hàng đợi đọc
  List<String> _queue = [];
  int _currentIndex = 0;
  // Bỏ qua completion/cancel do chính stop() gây ra
  bool _stopRequested = false;

  /// Gọi mỗi khi chuyển sang đoạn mới (index trong hàng đợi).
  void Function(int index)? onChunkStarted;

  /// Gọi khi đã đọc hết hàng đợi.
  VoidCallback? onQueueCompleted;

  /// Gọi khi giọng offline/cloud lỗi và app chuyển sang giọng máy.
  void Function(String message)? onEngineError;

  /// Chuyển chương/trang tiếp theo hoặc trước đó (màn đọc sách gán vào).
  /// Nút trên thông báo và tai nghe dùng các callback này.
  Future<void> Function()? onSkipNext;
  Future<void> Function()? onSkipPrevious;

  // Thông tin hiển thị trên thông báo / màn hình khoá
  String? _nowPlayingTitle;
  String? _nowPlayingSubtitle;
  String? get nowPlayingTitle => _nowPlayingTitle;
  String? get nowPlayingSubtitle => _nowPlayingSubtitle;

  List<String> get languages => _languages;
  List<Map<String, dynamic>> get voices => _voices;
  bool get isSpeaking => _isSpeaking;
  double get rate => _rate;
  double get pitch => _pitch;
  String get selectedVoice => _selectedVoice;
  String get language => _language;
  String get voice => _selectedVoice;
  int get currentIndex => _currentIndex;
  int get queueLength => _queue.length;
  bool get hasQueue => _queue.isNotEmpty;

  TtsEngineType get engineType => _engineType;
  String get offlineVoiceId => _offlineVoiceId;
  String get azureVoice => _azureVoice;
  String get azureRegion => _azureRegion;
  bool get hasAzureKey => _azureKey.isNotEmpty;
  String get googleVoice => _googleVoice;
  bool get hasGoogleKey => _googleKey.isNotEmpty;
  String? get engineError => _engineError;
  bool get offlineSupported => OfflineVoiceStore().isSupported;
  bool isOfflineVoiceInstalled(String id) => _installedOfflineVoices.contains(id);
  String? get downloadingVoiceId => _downloadingVoiceId;
  double? get downloadProgress => _downloadProgress;

  TtsService() {
    WidgetsFlutterBinding.ensureInitialized();
    // Không dùng cancel handler: sự kiện cancel của stop() có thể tới sau khi
    // đoạn mới đã bắt đầu và làm sai trạng thái. stop() tự cập nhật trạng thái.
    _tts.setCompletionHandler(_onChunkCompleted);
    _tts.setErrorHandler((message) {
      print('TTS error: $message');
      _isSpeaking = false;
      notifyListeners();
    });
    _initTts();
  }

  Future<void> _initTts() async {
    try {
      // speak() trả về ngay; việc đọc nối tiếp do completion handler đảm nhận
      await _tts.awaitSpeakCompletion(false);

      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
        // Category playback để tiếp tục đọc khi khoá màn hình / tắt tiếng
        await _tts.setSharedInstance(true);
        await _tts.setIosAudioCategory(
          IosTextToSpeechAudioCategory.playback,
          [
            IosTextToSpeechAudioCategoryOptions.allowBluetooth,
            IosTextToSpeechAudioCategoryOptions.allowBluetoothA2DP,
          ],
          IosTextToSpeechAudioMode.spokenAudio,
        );
      }

      // Khôi phục cài đặt đã lưu
      try {
        final storage = StorageService();
        _rate = storage.readingSpeed.clamp(0.5, 2.0);
        _pitch = storage.pitch.clamp(0.5, 2.0);
        _selectedVoice = storage.savedVoiceId ?? '';
        _engineType = TtsEngineType.fromId(storage.ttsEngine);
        _offlineVoiceId = offlineVoiceById(storage.offlineVoiceId).id;
        _azureVoice = storage.azureVoice ?? _azureVoice;
        _azureRegion = storage.azureRegion ?? _azureRegion;
        _googleVoice = storage.googleVoice ?? _googleVoice;
      } catch (e) {
        // StorageService chưa khởi tạo (vd. trong test)
      }
      if (_engineType == TtsEngineType.offline && !offlineSupported) {
        _engineType = TtsEngineType.system;
      }
      await _neural.setSpeed(_rate);
      await _initNeural();

      await _tts.setLanguage(_language);
      await _tts.setSpeechRate(_engineRate(_rate));
      await _tts.setPitch(_pitch);

      final voices = await _tts.getVoices;
      if (voices != null) {
        _voices = (voices as List)
            .map((v) => Map<String, dynamic>.from(v as Map))
            .where((v) => v['locale'] != null && v['name'] != null)
            .toList();
        print('TTS Service: Loaded ${_voices.length} voices');
      } else {
        print('TTS Service: No voices available');
      }

      if (_selectedVoice.isNotEmpty && _findVoice(_selectedVoice) != null) {
        await _applyVoice(_selectedVoice);
      } else {
        _selectedVoice = '';
      }
      notifyListeners();
    } catch (e) {
      print('TTS init error: $e');
    }
  }

  /// Nạp key API, danh sách giọng offline đã tải và cấu hình audio session.
  Future<void> _initNeural() async {
    try {
      _azureKey = await _secureStorage.read(key: _azureKeyName) ?? '';
      _googleKey = await _secureStorage.read(key: _googleKeyName) ?? '';
    } catch (e) {
      print('TTS key not loaded: $e');
    }
    await refreshOfflineVoices();
    if (!kIsWeb) {
      try {
        // just_audio cần category playback để phát tiếp khi khoá màn hình (iOS)
        final session = await AudioSession.instance;
        await session.configure(const AudioSessionConfiguration.speech());
      } catch (e) {
        print('Audio session error: $e');
      }
    }
  }

  /// Kiểm tra lại giọng offline nào đã có trên máy.
  Future<void> refreshOfflineVoices() async {
    if (!offlineSupported) return;
    try {
      final store = OfflineVoiceStore();
      _installedOfflineVoices.clear();
      for (final v in offlineViVoices) {
        if (await store.isInstalled(v)) _installedOfflineVoices.add(v.id);
      }
      notifyListeners();
    } catch (e) {
      print('Offline voices not checked: $e');
    }
  }

  /// Chọn bộ đọc. Đang đọc thì dừng, lần đọc sau dùng bộ đọc mới.
  Future<void> setEngineType(TtsEngineType type) async {
    if (type == TtsEngineType.offline && !offlineSupported) return;
    _engineType = type;
    _saveSetting(() => StorageService().saveTtsEngine(type.id));
    await _resetNeuralEngine();
  }

  Future<void> setOfflineVoice(String id) async {
    _offlineVoiceId = offlineVoiceById(id).id;
    _saveSetting(() => StorageService().saveOfflineVoiceId(_offlineVoiceId));
    await _resetNeuralEngine();
  }

  Future<void> setAzureConfig({String? key, String? region, String? voice}) async {
    if (key != null) {
      _azureKey = key.trim();
      await _writeSecure(_azureKeyName, _azureKey);
    }
    if (region != null) {
      _azureRegion = region.trim().isEmpty ? azureDefaultRegion : region.trim();
      _saveSetting(() => StorageService().saveAzureRegion(_azureRegion));
    }
    if (voice != null) {
      _azureVoice = voice;
      _saveSetting(() => StorageService().saveAzureVoice(voice));
    }
    await _resetNeuralEngine();
  }

  Future<void> setGoogleConfig({String? key, String? voice}) async {
    if (key != null) {
      _googleKey = key.trim();
      await _writeSecure(_googleKeyName, _googleKey);
    }
    if (voice != null) {
      _googleVoice = voice;
      _saveSetting(() => StorageService().saveGoogleVoice(voice));
    }
    await _resetNeuralEngine();
  }

  Future<void> _writeSecure(String key, String value) async {
    try {
      if (value.isEmpty) {
        await _secureStorage.delete(key: key);
      } else {
        await _secureStorage.write(key: key, value: value);
      }
    } catch (e) {
      print('TTS key not saved: $e');
    }
  }

  /// Tải giọng offline. Ném [TtsEngineException] nếu lỗi.
  Future<void> downloadOfflineVoice(String id) async {
    if (_downloadingVoiceId != null) return;
    final voice = offlineVoiceById(id);
    _downloadingVoiceId = voice.id;
    _downloadProgress = 0;
    notifyListeners();
    try {
      await OfflineVoiceStore().download(voice, onProgress: (progress) {
        _downloadProgress = progress;
        notifyListeners();
      });
      _installedOfflineVoices.add(voice.id);
    } finally {
      _downloadingVoiceId = null;
      _downloadProgress = null;
      notifyListeners();
    }
  }

  Future<void> deleteOfflineVoice(String id) async {
    final voice = offlineVoiceById(id);
    if (voice.id == _offlineVoiceId) await _resetNeuralEngine();
    await OfflineVoiceStore().delete(voice);
    _installedOfflineVoices.remove(voice.id);
    notifyListeners();
  }

  /// Dừng đọc và bỏ engine hiện tại; engine mới được tạo khi đọc lần sau.
  Future<void> _resetNeuralEngine() async {
    if (_isSpeaking) await pause();
    _engineLoading = null;
    _fallbackToSystem = false;
    _engineError = null;
    await _neural.setEngine(null);
    notifyListeners();
  }

  /// Tạo engine theo cài đặt nếu chưa có. Ném [TtsEngineException] nếu thiếu cấu hình.
  Future<void> _ensureNeuralEngine() {
    if (_neural.engine != null) return Future.value();
    return _engineLoading ??= _createNeuralEngine().whenComplete(() => _engineLoading = null);
  }

  Future<void> _createNeuralEngine() async {
    final NeuralTtsEngine engine;
    switch (_engineType) {
      case TtsEngineType.offline:
        final voice = offlineVoiceById(_offlineVoiceId);
        if (!isOfflineVoiceInstalled(voice.id)) {
          throw const TtsEngineException('Chưa tải giọng offline. Vào mục Giọng đọc trong Cài đặt để tải.');
        }
        engine = await OfflineVoiceStore().createEngine(voice);
        break;
      case TtsEngineType.azure:
        if (_azureKey.isEmpty) throw const TtsEngineException('Chưa nhập key Azure trong mục Giọng đọc.');
        engine = AzureTtsEngine(apiKey: _azureKey, region: _azureRegion, voice: _azureVoice);
        break;
      case TtsEngineType.google:
        if (_googleKey.isEmpty) throw const TtsEngineException('Chưa nhập key Google Cloud trong mục Giọng đọc.');
        engine = GoogleTtsEngine(apiKey: _googleKey, voice: _googleVoice);
        break;
      case TtsEngineType.system:
        return;
    }
    await _neural.setEngine(engine);
  }

  /// Đọc thử một câu bằng cài đặt hiện tại (nút "Nghe thử" trong Cài đặt).
  Future<void> preview() async {
    await speakQueue(const ['Xin chào, đây là giọng đọc sách của bạn.']);
  }

  /// Force reload voices from flutter_tts
  Future<void> reloadVoices() async {
    final voices = await _tts.getVoices;
    if (voices != null) {
      _voices = (voices as List)
          .map((v) => Map<String, dynamic>.from(v as Map))
          .where((v) => v['locale'] != null && v['name'] != null)
          .toList();
      print('TTS Service: Reloaded ${_voices.length} voices');
      notifyListeners();
    }
  }

  Future<void> setLanguage(String language) async {
    _language = language;
    await _tts.setLanguage(language);
    notifyListeners();
  }

  Future<void> setRate(double rate) async {
    _rate = rate.clamp(0.5, 2.0);
    await _tts.setSpeechRate(_engineRate(_rate));
    await _neural.setSpeed(_rate);
    _saveSetting(() => StorageService().saveReadingSpeed(_rate));
    notifyListeners();
  }

  Future<void> setPitch(double pitch) async {
    _pitch = pitch.clamp(0.5, 2.0);
    await _tts.setPitch(_pitch);
    _saveSetting(() => StorageService().savePitch(_pitch));
    notifyListeners();
  }

  /// Đổi hệ số tốc độ của app (1.0 = bình thường) sang giá trị của flutter_tts.
  /// flutter_tts nhân đôi rate trên Android, còn iOS/macOS dùng 0.5 là bình thường
  /// và 1.0 là tối đa, nên cả hai cùng dùng rate * 0.5. Web dùng nguyên giá trị.
  static double _engineRate(double rate) => kIsWeb ? rate : rate * 0.5;

  /// Cập nhật tiêu đề hiển thị trên thông báo / màn hình khoá.
  void setNowPlaying(String? title, {String? subtitle}) {
    if (_nowPlayingTitle == title && _nowPlayingSubtitle == subtitle) return;
    _nowPlayingTitle = title;
    _nowPlayingSubtitle = subtitle;
    notifyListeners();
  }

  /// Chuyển tiếp: theo chương/trang nếu màn đọc có gán, không thì sang đoạn sau.
  Future<void> skipNext() async {
    if (onSkipNext != null) return onSkipNext!();
    if (_queue.isNotEmpty) await jumpTo(_currentIndex + 1);
  }

  Future<void> skipPrevious() async {
    if (onSkipPrevious != null) return onSkipPrevious!();
    if (_queue.isNotEmpty) await jumpTo(_currentIndex - 1);
  }

  /// Đọc một đoạn text bất kỳ (tự chia nhỏ nếu dài).
  Future<void> speak(String text) async {
    if (text.trim().isEmpty) return;
    await speakQueue(splitText(text));
  }

  /// Đọc danh sách đoạn, bắt đầu từ [startIndex].
  Future<void> speakQueue(List<String> chunks, {int startIndex = 0}) async {
    final queue = chunks.where((c) => c.trim().isNotEmpty).toList();
    if (queue.isEmpty) return;

    await _stopEngine();
    await _ensureWebVoice();
    _fallbackToSystem = false;
    _queue = queue;
    _currentIndex = startIndex.clamp(0, _queue.length - 1);
    await _speakCurrent();
  }

  bool _webVoiceReady = false;

  /// Trình duyệt (nhất là Chrome) tải danh sách giọng bất đồng bộ, nên lúc
  /// khởi tạo thường chưa có giọng nào và setLanguage() không chọn được giọng
  /// Việt. Trước lần đọc đầu tiên, tải lại giọng và áp dụng lại ngôn ngữ/giọng.
  Future<void> _ensureWebVoice() async {
    if (!kIsWeb || _webVoiceReady) return;
    try {
      if (_voices.isEmpty) await reloadVoices();
      if (_voices.isEmpty) return;
      _webVoiceReady = true;

      if (_selectedVoice.isEmpty) {
        try {
          _selectedVoice = StorageService().savedVoiceId ?? '';
        } catch (e) {
          // StorageService chưa khởi tạo
        }
      }
      if (_selectedVoice.isNotEmpty && _findVoice(_selectedVoice) != null) {
        await _applyVoice(_selectedVoice);
      } else {
        _selectedVoice = '';
        await _tts.setLanguage(_language);
      }
    } catch (e) {
      print('TTS web voice error: $e');
    }
  }

  /// Nhảy tới đoạn [index] trong hàng đợi hiện tại.
  Future<void> jumpTo(int index) async {
    if (_queue.isEmpty) return;
    await _stopEngine();
    _currentIndex = index.clamp(0, _queue.length - 1);
    await _speakCurrent();
  }

  Future<void> _speakCurrent() async {
    if (_currentIndex >= _queue.length) return;
    _stopRequested = false;
    _isSpeaking = true;
    notifyListeners();
    onChunkStarted?.call(_currentIndex);

    if (_engineType != TtsEngineType.system && !_fallbackToSystem) {
      await _speakNeural();
      return;
    }
    await _speakSystem();
  }

  Future<void> _speakSystem() async {
    try {
      await _tts.speak(_queue[_currentIndex]);
    } catch (e) {
      print('TTS error: $e');
      _isSpeaking = false;
      notifyListeners();
    }
  }

  Future<void> _speakNeural() async {
    final token = ++_speakToken;
    final index = _currentIndex;
    try {
      await _ensureNeuralEngine();
      if (token != _speakToken || _stopRequested) return;
      final next = index + 1 < _queue.length ? _queue[index + 1] : null;
      final finished = await _neural.speak(_queue[index], nextText: next, splitter: splitText);
      if (finished && token == _speakToken && !_stopRequested) _onChunkCompleted();
    } catch (e) {
      if (token != _speakToken || _stopRequested) return;
      // Không để việc nghe bị ngắt: đọc tiếp bằng giọng máy và báo lỗi một lần
      print('Neural TTS error: $e');
      _fallbackToSystem = true;
      _engineError = e is TtsEngineException ? e.message : 'Giọng đọc lỗi: $e';
      notifyListeners();
      onEngineError?.call('${_engineError!} Đang đọc bằng giọng của máy.');
      await _speakSystem();
    }
  }

  void _onChunkCompleted() {
    if (_stopRequested || !_isSpeaking) return;

    if (_currentIndex < _queue.length - 1) {
      _currentIndex++;
      _speakCurrent();
    } else {
      _isSpeaking = false;
      notifyListeners();
      onQueueCompleted?.call();
    }
  }

  /// Tạm dừng. Đọc tiếp sẽ bắt đầu lại từ đầu đoạn hiện tại
  /// (pause() của flutter_tts không ổn định trên mọi nền tảng).
  Future<void> pause() async {
    await _stopEngine();
    notifyListeners();
  }

  /// Đọc tiếp từ đoạn hiện tại.
  Future<void> resume() async {
    if (_queue.isEmpty) return;
    await _speakCurrent();
  }

  Future<void> stop() async {
    await _stopEngine();
    _queue = [];
    _currentIndex = 0;
    _nowPlayingTitle = null;
    _nowPlayingSubtitle = null;
    notifyListeners();
  }

  Future<void> _stopEngine() async {
    _stopRequested = true;
    _isSpeaking = false;
    _speakToken++;
    await _neural.stop();
    await _tts.stop();
  }

  Future<void> setVoice(String voiceName) async {
    _selectedVoice = voiceName;
    await _applyVoice(voiceName);
    _saveSetting(() => StorageService().saveVoiceId(voiceName));
    notifyListeners();
  }

  Future<void> _applyVoice(String voiceName) async {
    final voice = _findVoice(voiceName);
    // flutter_tts trên Android cần cả name và locale
    await _tts.setVoice({
      'name': voiceName,
      'locale': voice?['locale']?.toString() ?? _language,
    });
  }

  Map<String, dynamic>? _findVoice(String voiceName) {
    for (final v in _voices) {
      if (v['name'] == voiceName) return v;
    }
    return null;
  }

  void _saveSetting(Future<void> Function() save) {
    try {
      save();
    } catch (e) {
      print('TTS setting not saved: $e');
    }
  }

  List<Map<String, dynamic>> get vietnameseVoices {
    return _voices.where((v) {
      final locale = (v['locale'] ?? '').toString();
      return locale.contains('vi') || locale.contains('Vietnamese');
    }).toList();
  }

  /// Chia text thành các đoạn không quá [maxLength] ký tự,
  /// ưu tiên cắt ở ranh giới đoạn văn, rồi câu, rồi khoảng trắng.
  static List<String> splitText(String text, {int maxLength = MAX_CHUNK_LENGTH}) {
    final chunks = <String>[];
    for (final paragraph in text.split(RegExp(r'\n\s*\n|\n'))) {
      final trimmed = paragraph.trim();
      if (trimmed.isEmpty) continue;
      if (trimmed.length <= maxLength) {
        chunks.add(trimmed);
        continue;
      }

      final buffer = StringBuffer();
      for (final sentence in trimmed.split(RegExp(r'(?<=[.!?…;:])\s+'))) {
        if (buffer.length + sentence.length + 1 > maxLength && buffer.isNotEmpty) {
          chunks.add(buffer.toString().trim());
          buffer.clear();
        }
        if (sentence.length > maxLength) {
          // Câu quá dài: cắt theo khoảng trắng
          var rest = sentence;
          while (rest.length > maxLength) {
            var cut = rest.lastIndexOf(' ', maxLength);
            if (cut <= 0) cut = maxLength;
            chunks.add(rest.substring(0, cut).trim());
            rest = rest.substring(cut).trim();
          }
          buffer.write('$rest ');
        } else {
          buffer.write('$sentence ');
        }
      }
      if (buffer.isNotEmpty) chunks.add(buffer.toString().trim());
    }
    return chunks.where((c) => c.isNotEmpty).toList();
  }
}
