import 'package:flutter/material.dart';
import 'package:libri_audio/services/storage_service.dart';

class ThemeProvider with ChangeNotifier {
  final StorageService _storage = StorageService();
  
  ThemeMode _themeMode = ThemeMode.system;
  
  ThemeMode get themeMode => _themeMode;
  bool get isDarkMode => _themeMode == ThemeMode.dark;
  
  ThemeProvider() {
    // Load saved theme
    final darkMode = _storage.darkMode;
    _themeMode = darkMode ? ThemeMode.dark : ThemeMode.light;
  }
  
  void setThemeMode(ThemeMode mode) {
    _themeMode = mode;
    
    // Save to preferences
    _storage.saveDarkMode(mode == ThemeMode.dark);
    
    notifyListeners();
  }
  
  void toggleTheme() {
    final newMode = _themeMode == ThemeMode.light 
      ? ThemeMode.dark 
      : ThemeMode.light;
    _themeMode = newMode;
    
    // Save to preferences
    _storage.saveDarkMode(newMode == ThemeMode.dark);
    
    notifyListeners();
  }
  
  void setLightMode() {
    _themeMode = ThemeMode.light;
    _storage.saveDarkMode(false);
    notifyListeners();
  }
  
  void setDarkMode() {
    _themeMode = ThemeMode.dark;
    _storage.saveDarkMode(true);
    notifyListeners();
  }
}
