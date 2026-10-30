import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:libri_audio/providers/book_provider.dart';
import 'package:libri_audio/providers/highlight_provider.dart';
import 'package:libri_audio/providers/playlist_provider.dart';
import 'package:libri_audio/providers/theme_provider.dart';
import 'package:libri_audio/services/storage_service.dart';
import 'package:libri_audio/services/drive_service.dart';
import 'package:libri_audio/services/tts_audio_handler.dart';
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

  final ttsService = TtsService();
  await _initBackgroundAudio(ttsService);

  // Run the app
  runApp(MyApp(ttsService: ttsService));
}

/// Bật phát nền cho TTS (thông báo điều khiển, nút tai nghe) trên Android/iOS.
Future<void> _initBackgroundAudio(TtsService ttsService) async {
  final supported = !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);
  if (!supported) return;

  try {
    await AudioService.init(
      builder: () => TtsAudioHandler(ttsService),
      config: const AudioServiceConfig(
        androidNotificationChannelId: 'com.example.libri_audio.tts',
        androidNotificationChannelName: 'Đọc sách',
        // Giữ foreground service khi tạm dừng để Android 12+ cho phép phát tiếp từ nền
        androidStopForegroundOnPause: false,
      ),
    );
  } catch (e) {
    print('Error initializing background audio: $e');
  }
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
  final TtsService ttsService;

  const MyApp({super.key, required this.ttsService});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => BookProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider.value(value: ttsService),
        ChangeNotifierProvider(create: (_) => PlaylistProvider()),
        ChangeNotifierProvider(create: (_) => HighlightProvider()),
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
