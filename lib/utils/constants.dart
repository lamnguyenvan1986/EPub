import 'package:flutter/material.dart';

class AppColors {
  // Primary Colors
  static const Color primary = Color(0xFF6750A4);
  static const Color primaryContainer = Color(0xFFEADDFF);
  
  // Secondary Colors
  static const Color secondary = Color(0xFF625B71);
  static const Color secondaryContainer = Color(0xFFEADDFF);
  
  // Tertiary Colors
  static const Color tertiary = Color(0xFF7D5260);
  static const Color tertiaryContainer = Color(0xFFFFD8E4);
  
  // Background Colors
  static const Color background = Color(0xFFFFFBFE);
  static const Color surface = Color(0xFFFFFBFE);
  static const Color surfaceVariant = Color(0xFFE7E0EC);
  
  // On Colors
  static const Color onPrimary = Color(0xFFFFFFFF);
  static const Color onSecondary = Color(0xFFFFFFFF);
  static const Color onBackground = Color(0xFF1C1B1F);
  static const Color onSurface = Color(0xFF1C1B1F);
  
  // Neutral Colors
  static const Color neutral = Color(0xFF1C1B1F);
  static const Color neutralVariant = Color(0xFF302F37);
}

class AppStrings {
  static const String appName = 'LibriAudio';
  static const String defaultVoiceId = 'en-US-Standard-A';
}

class AppTheme {
  static ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: Brightness.light,
    ),
    scaffoldBackgroundColor: AppColors.background,
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.primaryContainer,
      foregroundColor: AppColors.onPrimary,
      elevation: 0,
      centerTitle: true,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: AppColors.surfaceVariant),
      ),
    ),
    cardTheme: CardThemeData(
      color: AppColors.surface,
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
    ),
    textTheme: const TextTheme(
      bodyLarge: TextStyle(fontFamily: 'NotoSans', fontSize: 16),
      bodyMedium: TextStyle(fontFamily: 'NotoSans', fontSize: 14),
      bodySmall: TextStyle(fontFamily: 'NotoSans', fontSize: 12),
    ),
  );

  static ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: Brightness.dark,
    ),
    scaffoldBackgroundColor: const Color(0xFF1C1B1F),
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFF302F37),
      foregroundColor: Colors.white,
      elevation: 0,
      centerTitle: true,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFF302F37),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: const Color(0xFF49454F)),
      ),
    ),
    cardTheme: CardThemeData(
      color: const Color(0xFF302F37),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
    ),
    textTheme: const TextTheme(
      bodyLarge: TextStyle(fontFamily: 'NotoSans', fontSize: 16),
      bodyMedium: TextStyle(fontFamily: 'NotoSans', fontSize: 14),
      bodySmall: TextStyle(fontFamily: 'NotoSans', fontSize: 12),
    ),
  );
}
