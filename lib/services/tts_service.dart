import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:libri_audio/services/storage_service.dart';

/// Đọc văn bản bằng flutter_tts theo từng đoạn ngắn.
///
/// Android giới hạn độ dài mỗi lần speak() (khoảng 4000 ký tự), nên text dài
/// được chia thành hàng đợi các đoạn và đọc nối tiếp qua completion handler.
class TtsService extends ChangeNotifier {
  /// Độ dài tối đa của một đoạn, thấp hơn giới hạn 4000 ký tự của Android.
  static const int MAX_CHUNK_LENGTH = 3000;

  final FlutterTts _tts = FlutterTts();
  bool _isSpeaking = false;
  double _rate = 1.0;
  double _pitch = 1.0;
  String _selectedVoice = '';
  String _language = 'vi-VN';

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
      } catch (e) {
        // StorageService chưa khởi tạo (vd. trong test)
      }

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
    _queue = queue;
    _currentIndex = startIndex.clamp(0, _queue.length - 1);
    await _speakCurrent();
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

    try {
      await _tts.speak(_queue[_currentIndex]);
    } catch (e) {
      print('TTS error: $e');
      _isSpeaking = false;
      notifyListeners();
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
