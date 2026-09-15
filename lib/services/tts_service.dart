import 'package:flutter/material.dart';

class TtsService extends ChangeNotifier {
  bool _isSpeaking = false;
  double _rate = 1.0;
  double _pitch = 1.0;
  String _selectedVoice = 'vi-VN';
  String _language = 'vi-VN';
  
  final List<String> _languages = ['vi-VN', 'en-US'];
  final List<Map<String, dynamic>> _voices = [
    {'name': 'vi-VN', 'locale': 'vi-VN'},
    {'name': 'en-US', 'locale': 'en-US'},
  ];
  
  List<String> get languages => _languages;
  List<Map<String, dynamic>> get voices => _voices;
  bool get isSpeaking => _isSpeaking;
  double get rate => _rate;
  double get pitch => _pitch;
  String get selectedVoice => _selectedVoice;
  String get language => _language;
  String get voice => _selectedVoice;
  
  Future<void> setLanguage(String language) async {
    _language = language;
    notifyListeners();
  }
  
  Future<void> setRate(double rate) async {
    _rate = rate.clamp(0.5, 2.0);
    notifyListeners();
  }
  
  Future<void> setPitch(double pitch) async {
    _pitch = pitch.clamp(0.5, 2.0);
    notifyListeners();
  }
  
  Future<void> speak(String text) async {
    if (text.isEmpty) return;
    _isSpeaking = true;
    notifyListeners();
    try {
      // Giả lập - trong thực tế dùng audio player
      await Future.delayed(Duration(seconds: (text.length / 5).toInt()));
    } finally {
      _isSpeaking = false;
      notifyListeners();
    }
  }
  
  Future<void> pause() async {
    _isSpeaking = false;
    notifyListeners();
  }
  
  Future<void> resume() async {
    _isSpeaking = true;
    notifyListeners();
  }
  
  Future<void> stop() async {
    _isSpeaking = false;
    notifyListeners();
  }
  
  Future<void> setVoice(String voiceName) async {
    _selectedVoice = voiceName;
    notifyListeners();
  }
  
  
  List<Map<String, dynamic>> get vietnameseVoices {
    return _voices.where((v) {
      final locale = v['locale'] ?? '';
      return locale.contains('vi') || locale.contains('Vietnamese');
    }).toList();
  }
}
