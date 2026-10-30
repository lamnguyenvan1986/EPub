import 'package:flutter/material.dart';
import 'package:libri_audio/services/storage_service.dart';

class ThemeProvider with ChangeNotifier, WidgetsBindingObserver {
  final StorageService _storage = StorageService();

  ThemeMode _themeMode = ThemeMode.system;

  ThemeMode get themeMode => _themeMode;

  /// Theme đang hiển thị là tối (tính cả khi theo hệ thống).
  bool get isDarkMode {
    if (_themeMode == ThemeMode.system) {
      return WidgetsBinding.instance.platformDispatcher.platformBrightness == Brightness.dark;
    }
    return _themeMode == ThemeMode.dark;
  }

  ThemeProvider() {
    // Load saved theme; mặc định theo hệ thống
    _themeMode = switch (_storage.themeMode) {
      'dark' => ThemeMode.dark,
      'light' => ThemeMode.light,
      _ => ThemeMode.system,
    };
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangePlatformBrightness() {
    // Cập nhật icon/switch khi hệ thống đổi sáng/tối
    if (_themeMode == ThemeMode.system) notifyListeners();
  }

  void setThemeMode(ThemeMode mode) {
    _themeMode = mode;
    _storage.saveThemeMode(mode.name);
    notifyListeners();
  }

  /// Đổi giữa sáng và tối dựa trên theme đang hiển thị.
  void toggleTheme() {
    setThemeMode(isDarkMode ? ThemeMode.light : ThemeMode.dark);
  }

  void setLightMode() => setThemeMode(ThemeMode.light);

  void setDarkMode() => setThemeMode(ThemeMode.dark);

  void setSystemMode() => setThemeMode(ThemeMode.system);

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}
