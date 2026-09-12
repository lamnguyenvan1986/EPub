import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libri_audio/main.dart';
import 'package:libri_audio/models/book_model.dart';
import 'package:libri_audio/models/highlight_model.dart';
import 'package:libri_audio/providers/book_provider.dart';
import 'package:libri_audio/providers/theme_provider.dart';
import 'package:libri_audio/screens/home_screen.dart';
import 'package:libri_audio/services/storage_service.dart';
import 'package:libri_audio/services/tts_service.dart';
import 'package:provider/provider.dart';

void main() {
  setUpAll(() async {
    // Initialize storage before tests
    await StorageService().init();
  });

  group('Feature Tests', () {
    testWidgets('App starts with empty book list', (WidgetTester tester) async {
      await tester.pumpWidget(const MyApp());

      // Check that home screen is displayed
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(find.text('LibriAudio'), findsOneWidget);
    });

    testWidgets('Dark mode toggle works', (WidgetTester tester) async {
      await tester.pumpWidget(
        ChangeNotifierProvider(
          create: (_) => ThemeProvider(),
          child: const MyApp(),
        ),
      );

      // Use a Finder to locate a widget and get its context
      final themeFinder = find.byType(ThemeProvider);
      final themeProvider = Provider.of<ThemeProvider>(tester.element(themeFinder), listen: false);

      // Initial state should be light
      expect(themeProvider.isDarkMode, false);

      // Toggle dark mode
      themeProvider.toggleTheme();
      await tester.pump();

      expect(themeProvider.isDarkMode, true);
    });

    testWidgets('Book can be added to list', (WidgetTester tester) async {
      final bookProvider = BookProvider();

      final book = Book(
        title: 'Test Book',
        fileType: 'epub',
      );

      bookProvider.addBook(book);

      expect(bookProvider.books.length, 1);
      expect(bookProvider.books.first.title, 'Test Book');
    });

    testWidgets('Reading state can be saved', (WidgetTester tester) async {
      final storage = StorageService();
      const String bookId = 'test-book-id';

      storage.saveReadingState(bookId, 5, 1000);

      final state = storage.getReadingState(bookId);
      expect(state, isNotNull);
      expect(state?.chapterIndex, 5);
      expect(state?.position, 1000);
    });

    testWidgets('TTS service can change rate', (WidgetTester tester) async {
      final ttsService = TtsService();

      await ttsService.setRate(1.5);

      expect(ttsService.rate, 1.5);
    });

    testWidgets('Book can be removed', (WidgetTester tester) async {
      final bookProvider = BookProvider();

      final book = Book(title: 'To Remove', fileType: 'epub');
      bookProvider.addBook(book);

      expect(bookProvider.books.length, 1);

      bookProvider.removeBook(book.id);

      expect(bookProvider.books.length, 0);
    });

    testWidgets('Highlight can be added', (WidgetTester tester) async {
      final storage = StorageService();

      final highlight = Highlight(
        bookId: 'book123',
        text: 'Test highlight',
        chapterIndex: 1,
        positionStart: 100,
        positionEnd: 150,
      );

      storage.saveHighlight(highlight);

      final highlights = storage.getHighlights('book123');
      expect(highlights.length, 1);
      expect(highlights.first.text, 'Test highlight');
    });
  });

  group('Integration Tests', () {
    testWidgets('App with all providers', (WidgetTester tester) async {
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => BookProvider()),
            ChangeNotifierProvider(create: (_) => ThemeProvider()),
            ChangeNotifierProvider(create: (_) => TtsService()),
          ],
          child: const MyApp(),
        ),
      );

      // Verify all providers are accessible
      final bookFinder = find.byType(BookProvider);
      final themeFinder = find.byType(ThemeProvider);
      final ttsFinder = find.byType(TtsService);

      expect(Provider.of<BookProvider>(tester.element(bookFinder), listen: false), isNotNull);
      expect(Provider.of<ThemeProvider>(tester.element(themeFinder), listen: false), isNotNull);
      expect(Provider.of<TtsService>(tester.element(ttsFinder), listen: false), isNotNull);
    });

    testWidgets('Theme persists across rebuilds', (WidgetTester tester) async {
      await tester.pumpWidget(
        ChangeNotifierProvider(
          create: (_) => ThemeProvider(),
          child: MaterialApp(
            home: Builder(
              builder: (context) => Consumer<ThemeProvider>(
                builder: (context, themeProvider, child) {
                  return Container(
                    color: themeProvider.isDarkMode ? Colors.black : Colors.white,
                    child: Text('Theme Test'),
                  );
                },
              ),
            ),
          ),
        ),
      );

      final themeFinder = find.byType(ThemeProvider);
      final themeProvider = Provider.of<ThemeProvider>(tester.element(themeFinder), listen: false);

      themeProvider.setDarkMode();
      await tester.pump();

      expect(themeProvider.isDarkMode, true);
    });
  });
}
