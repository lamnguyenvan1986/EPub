import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';

class TtsService extends ChangeNotifier {
  final FlutterTts _tts = FlutterTts();
  bool _isSpeaking = false;
  double _rate = 1.0;
  double _pitch = 1.0;
  String _selectedVoice = 'vi-VN';
  String _language = 'vi-VN';

  final List<String> _languages = ['vi-VN', 'en-US'];
  List<Map<String, dynamic>> _voices = [];

  List<String> get languages => _languages;
  List<Map<String, dynamic>> get voices => _voices;
  bool get isSpeaking => _isSpeaking;
  double get rate => _rate;
  double get pitch => _pitch;
  String get selectedVoice => _selectedVoice;
  String get language => _language;
  String get voice => _selectedVoice;

  TtsService() {
    // Initialize voices after a short delay to ensure flutter_tts is ready
    WidgetsFlutterBinding.ensureInitialized();
    _initTts();
  }

  Future<void> _initTts() async {
    // Wait a bit for flutter_tts to initialize
    await Future.delayed(const Duration(milliseconds: 500));

    // Get available voices
    final voices = await _tts.getVoices;
    if (voices != null) {
      _voices = voices.where((v) => v['locale'] != null).toList();
      print('TTS Service: Loaded ${_voices.length} voices');
      notifyListeners();
    } else {
      print('TTS Service: No voices available');
    }
  }

  /// Force reload voices from flutter_tts
  Future<void> reloadVoices() async {
    final voices = await _tts.getVoices;
    if (voices != null) {
      _voices = voices.where((v) => v['locale'] != null).toList();
      print('TTS Service: Reloaded ${_voices.length} voices');
      notifyListeners();
    }
  }

  Future<void> setLanguage(String language) async {
    _language = language;
    await _tts.setLanguage(language.toUpperCase());
    notifyListeners();
  }

  Future<void> setRate(double rate) async {
    _rate = rate.clamp(0.5, 2.0);
    await _tts.setSpeechRate(_rate);
    notifyListeners();
  }

  Future<void> setPitch(double pitch) async {
    _pitch = pitch.clamp(0.5, 2.0);
    await _tts.setPitch(pitch);
    notifyListeners();
  }

  String? _lastText;

  Future<void> speak(String text) async {
    if (text.isEmpty) return;
    _lastText = text;
    _isSpeaking = true;
    notifyListeners();

    try {
      await _tts.speak(text);
    } catch (e) {
      print('TTS error: $e');
      _isSpeaking = false;
      notifyListeners();
    }
  }

  Future<void> pause() async {
    await _tts.pause();
    _isSpeaking = false;
    notifyListeners();
  }

  Future<void> resume() async {
    // flutter_tts doesn't have a native resume method
    // Resume by speaking the text again from the beginning
    if (_lastText != null && _lastText!.isNotEmpty) {
      await speak(_lastText!);
    }
    notifyListeners();
  }

  Future<void> stop() async {
    await _tts.stop();
    _isSpeaking = false;
    notifyListeners();
  }

  Future<void> setVoice(String voiceName) async {
    _selectedVoice = voiceName;
    await _tts.setVoice({'name': voiceName});
    notifyListeners();
  }

  List<Map<String, dynamic>> get vietnameseVoices {
    return _voices.where((v) {
      final locale = v['locale'] ?? '';
      return locale.contains('vi') || locale.contains('Vietnamese');
    }).toList();
  }
}
