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
  } catch (e) {
    // Các provider đều cần StorageService; chạy tiếp sẽ crash với LateInitializationError
    print('Error initializing storage: $e');
    runApp(StartupErrorApp(message: e.toString()));
    return;
  }

  // Run the app
  runApp(const MyApp());
}

class StartupErrorApp extends StatelessWidget {
  final String message;

  const StartupErrorApp({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'Không khởi tạo được bộ nhớ của ứng dụng.\n\n$message',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }
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
        // Singleton: cùng instance với FileImportScreen và BookProvider
        ChangeNotifierProvider.value(value: DriveService()),
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
