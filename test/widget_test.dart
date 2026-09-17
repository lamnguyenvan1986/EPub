// This is a basic Flutter widget test for LibriAudio.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:libri_audio/providers/theme_provider.dart';
import 'package:libri_audio/services/tts_service.dart';
import 'package:libri_audio/services/storage_service.dart';

void main() {
  setUpAll(() async {
    // Initialize storage before tests
    await StorageService().init();
  });

  testWidgets('App starts with correct title', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    // Note: This test needs actual providers setup like in main.dart
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => ThemeProvider()),
          ChangeNotifierProvider(create: (_) => TtsService()),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: Center(
              child: Text('LibriAudio Test'),
            ),
          ),
        ),
      ),
    );

    // Verify that app title text is displayed
    expect(find.text('LibriAudio Test'), findsOneWidget);
  });

  testWidgets('ThemeProvider can toggle theme', (WidgetTester tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => ThemeProvider(),
        child: MaterialApp(
          home: Builder(
            builder: (context) {
              final provider = Provider.of<ThemeProvider>(context, listen: false);
              return Scaffold(
                body: Center(
                  child: Text(provider.isDarkMode ? 'Dark' : 'Light'),
                ),
              );
            },
          ),
        ),
      ),
    );

    // Initial state should be light (system default)
    expect(find.text('Light'), findsOneWidget);

    // Toggle theme
    final provider = Provider.of<ThemeProvider>(tester.element(find.byType(ThemeProvider)), listen: false);
    provider.toggleTheme();
    await tester.pump();

    expect(find.text('Dark'), findsOneWidget);
  });

  testWidgets('TtsService can change rate', (WidgetTester tester) async {
    final ttsService = TtsService();

    // Initial rate should be 1.0
    expect(ttsService.rate, 1.0);

    // Set new rate
    await ttsService.setRate(1.5);
    expect(ttsService.rate, 1.5);

    // Test clamping
    await ttsService.setRate(0.3);
    expect(ttsService.rate, 0.5); // Clamped to min

    await ttsService.setRate(3.0);
    expect(ttsService.rate, 2.0); // Clamped to max
  });
}
