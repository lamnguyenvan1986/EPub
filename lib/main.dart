import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:libri_audio/providers/book_provider.dart';
import 'package:libri_audio/providers/theme_provider.dart';
import 'package:libri_audio/services/storage_service.dart';
import 'package:libri_audio/services/audio_player_service.dart';
import 'package:libri_audio/services/drive_service.dart';
import 'package:libri_audio/services/tts_service.dart';
import 'package:libri_audio/screens/home_screen.dart';
import 'package:libri_audio/utils/constants.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Set system UI overlay style
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );

  // Initialize services
  try {
    await StorageService().init();
    // DriveService is initialized lazily when needed
  } catch (e) {
    print('Error initializing storage: $e');
  }

  // Run the app
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => BookProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => TtsService()),
        ChangeNotifierProvider(create: (_) => AudioPlayerService()),
        Provider(create: (_) => DriveService()),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, child) {
          return MaterialApp(
            title: AppStrings.appName,
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: themeProvider.themeMode,
            home: const HomeScreen(),
          );
        },
      ),
    );
  }
}
