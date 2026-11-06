import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:libri_audio/services/storage_service.dart';

/// Màu nền/chữ của trang sách.
enum ReaderTheme { app, light, sepia, dark }

/// Cuộn dọc cả chương, hoặc chia trang và lật ngang.
enum ReaderLayout { scroll, paginate }

/// Tùy chọn hiển thị dùng chung cho mọi sách dạng chữ (EPUB, MOBI, PDF dạng chữ).
@immutable
class ReaderSettings {
  static const fontFamilies = {'NotoSans': 'Không chân', 'LiberationSerif': 'Có chân'};

  final double fontSize;
  final double lineHeight;

  /// Lề trái/phải (logical pixel).
  final double margin;
  final String fontFamily;
  final ReaderTheme theme;
  final ReaderLayout layout;
  final bool justify;

  const ReaderSettings({
    this.fontSize = 18,
    this.lineHeight = 1.5,
    this.margin = 20,
    this.fontFamily = 'NotoSans',
    this.theme = ReaderTheme.app,
    this.layout = ReaderLayout.scroll,
    this.justify = false,
  });

  ReaderSettings copyWith({
    double? fontSize,
    double? lineHeight,
    double? margin,
    String? fontFamily,
    ReaderTheme? theme,
    ReaderLayout? layout,
    bool? justify,
  }) =>
      ReaderSettings(
        fontSize: fontSize ?? this.fontSize,
        lineHeight: lineHeight ?? this.lineHeight,
        margin: margin ?? this.margin,
        fontFamily: fontFamily ?? this.fontFamily,
        theme: theme ?? this.theme,
        layout: layout ?? this.layout,
        justify: justify ?? this.justify,
      );

  Map<String, dynamic> toJson() => {
        'fontSize': fontSize,
        'lineHeight': lineHeight,
        'margin': margin,
        'fontFamily': fontFamily,
        'theme': theme.name,
        'layout': layout.name,
        'justify': justify,
      };

  factory ReaderSettings.fromJson(Map<String, dynamic> json) {
    const d = ReaderSettings();
    double num_(String key, double fallback, double min, double max) {
      final v = json[key];
      return v is num ? v.toDouble().clamp(min, max) : fallback;
    }

    final family = json['fontFamily'];
    return ReaderSettings(
      fontSize: num_('fontSize', d.fontSize, 12, 36),
      lineHeight: num_('lineHeight', d.lineHeight, 1.1, 2.4),
      margin: num_('margin', d.margin, 4, 64),
      fontFamily: family is String && fontFamilies.containsKey(family) ? family : d.fontFamily,
      theme: ReaderTheme.values.where((t) => t.name == json['theme']).firstOrNull ?? d.theme,
      layout: ReaderLayout.values.where((l) => l.name == json['layout']).firstOrNull ?? d.layout,
      justify: json['justify'] == true,
    );
  }

  /// Màu nền và màu chữ của trang theo [theme]; `app` lấy theo theme của app.
  ({Color background, Color text}) colors(ThemeData appTheme) => switch (theme) {
        ReaderTheme.light => (background: Colors.white, text: const Color(0xFF1F1F1F)),
        ReaderTheme.sepia => (background: const Color(0xFFF4ECD8), text: const Color(0xFF5B4636)),
        ReaderTheme.dark => (background: const Color(0xFF121212), text: const Color(0xFFDADADA)),
        ReaderTheme.app => (background: appTheme.colorScheme.surface, text: appTheme.colorScheme.onSurface),
      };

  TextStyle textStyle(Color color) => TextStyle(
        fontFamily: fontFamily,
        fontSize: fontSize,
        height: lineHeight,
        color: color,
      );

  @override
  bool operator ==(Object other) =>
      other is ReaderSettings &&
      other.fontSize == fontSize &&
      other.lineHeight == lineHeight &&
      other.margin == margin &&
      other.fontFamily == fontFamily &&
      other.theme == theme &&
      other.layout == layout &&
      other.justify == justify;

  @override
  int get hashCode => Object.hash(fontSize, lineHeight, margin, fontFamily, theme, layout, justify);
}

/// Lưu và phát thay đổi [ReaderSettings] (SharedPreferences, khoá `reader_settings`).
class ReaderSettingsProvider with ChangeNotifier {
  final StorageService? _storage;
  ReaderSettings _settings;

  ReaderSettingsProvider({StorageService? storage, ReaderSettings? initial})
      : _storage = storage,
        _settings = initial ?? _load(storage);

  static ReaderSettings _load(StorageService? storage) {
    final raw = storage?.readerSettings;
    if (raw == null) return const ReaderSettings();
    try {
      return ReaderSettings.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (e) {
      return const ReaderSettings();
    }
  }

  ReaderSettings get settings => _settings;

  void update(ReaderSettings settings) {
    if (settings == _settings) return;
    _settings = settings;
    _storage?.saveReaderSettings(jsonEncode(settings.toJson()));
    notifyListeners();
  }

  void reset() => update(const ReaderSettings());
}
