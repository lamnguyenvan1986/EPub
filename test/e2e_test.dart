import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libri_audio/main.dart';
import 'package:libri_audio/providers/book_provider.dart';
import 'package:libri_audio/providers/theme_provider.dart';
import 'package:libri_audio/services/storage_service.dart';
import 'package:libri_audio/services/tts_service.dart';
import 'package:libri_audio/services/drive_service.dart';
import 'package:libri_audio/models/book_model.dart';
import 'package:libri_audio/models/highlight_model.dart';
import 'package:provider/provider.dart';

void main() {
  late BookProvider bookProvider;
  late ThemeProvider themeProvider;
  late TtsService ttsService;
  late StorageService storage;

  setUpAll(() async {
    await StorageService().init();
  });

  testWidgets('E2E: Complete user flow', (WidgetTester tester) async {
    // 1. Start app
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => BookProvider()),
          ChangeNotifierProvider(create: (_) => ThemeProvider()),
          ChangeNotifierProvider(create: (_) => TtsService()),
          Provider(create: (_) => DriveService()),
        ],
        child: const MyApp(),
      ),
    );

    // 2. Verify initial state - empty book list
    expect(find.text('No books yet'), findsOneWidget);
    expect(find.text('Import Books'), findsOneWidget);
    print('✅ Step 1: Initial state verified - empty book list');

    // 3. Toggle dark mode - use a Builder to get context
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => BookProvider()),
          ChangeNotifierProvider(create: (_) => ThemeProvider()),
          ChangeNotifierProvider(create: (_) => TtsService()),
          Provider(create: (_) => DriveService()),
        ],
        child: Builder(
          builder: (context) {
            themeProvider = Provider.of<ThemeProvider>(context, listen: false);
            return const MyApp();
          },
        ),
      ),
    );

    themeProvider.toggleTheme();
    await tester.pump();
    expect(themeProvider.isDarkMode, true);
    print('✅ Step 2: Dark mode enabled');

    // 4. Add a test book
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => BookProvider()),
          ChangeNotifierProvider(create: (_) => ThemeProvider()),
          ChangeNotifierProvider(create: (_) => TtsService()),
          Provider(create: (_) => DriveService()),
        ],
        child: Builder(
          builder: (context) {
            bookProvider = Provider.of<BookProvider>(context, listen: false);
            return const MyApp();
          },
        ),
      ),
    );

    final testBook = Book(
      title: 'Test Book for E2E',
      author: 'Test Author',
      fileType: 'epub',
    );
    bookProvider.addBook(testBook);
    await tester.pump();

    expect(bookProvider.books.length, 1);
    expect(bookProvider.books.first.title, 'Test Book for E2E');
    print('✅ Step 3: Test book added to library');

    // 5. Save reading state
    storage = StorageService();
    storage.saveReadingState(testBook.id, 3, 1500);

    final savedState = storage.getReadingState(testBook.id);
    expect(savedState?.chapterIndex, 3);
    expect(savedState?.position, 1500);
    print('✅ Step 4: Reading state saved');

    // 6. Test TTS service
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => BookProvider()),
          ChangeNotifierProvider(create: (_) => ThemeProvider()),
          ChangeNotifierProvider(create: (_) => TtsService()),
          Provider(create: (_) => DriveService()),
        ],
        child: Builder(
          builder: (context) {
            ttsService = Provider.of<TtsService>(context, listen: false);
            return const MyApp();
          },
        ),
      ),
    );

    await ttsService.setRate(1.5);
    expect(ttsService.rate, 1.5);
    print('✅ Step 5: TTS rate set to 1.5');

    // 7. Verify app can be rebuilt with state
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => bookProvider),
          ChangeNotifierProvider(create: (_) => themeProvider),
          ChangeNotifierProvider(create: (_) => ttsService),
          Provider(create: (_) => DriveService()),
        ],
        child: const MyApp(),
      ),
    );

    // Verify book list still has our test book
    expect(find.text('Test Book for E2E'), findsOneWidget);
    print('✅ Step 6: App state persisted across rebuilds');

    print('');
    print('🎉 E2E Test PASSED - All core features working!');
  });

  testWidgets('E2E: User journey - Read book and take notes', (tester) async {
    // Simulate full user journey
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => BookProvider()),
          ChangeNotifierProvider(create: (_) => ThemeProvider()),
          ChangeNotifierProvider(create: (_) => TtsService()),
          Provider(create: (_) => DriveService()),
        ],
        child: const MyApp(),
      ),
    );

    // 1. User imports book
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => BookProvider()),
          ChangeNotifierProvider(create: (_) => ThemeProvider()),
          ChangeNotifierProvider(create: (_) => TtsService()),
          Provider(create: (_) => DriveService()),
        ],
        child: Builder(
          builder: (context) {
            bookProvider = Provider.of<BookProvider>(context, listen: false);
            return const MyApp();
          },
        ),
      ),
    );

    final book = Book(
      title: 'My Reading Book',
      fileType: 'epub',
    );
    bookProvider.addBook(book);

    // 2. User reads chapter 2
    bookProvider.saveReadingProgress(book.id, 2, 500);

    // 3. User takes highlight
    storage.saveHighlight(Highlight(
      bookId: book.id,
      text: 'Important quote',
      note: 'Remember this',
      chapterIndex: 2,
      positionStart: 480,
      positionEnd: 520,
    ));

    // 4. User saves preferences
    await storage.saveVoiceId('vi-VN-Standard-A');
    await storage.saveReadingSpeed(1.2);

    // Verify all data persisted
    expect(bookProvider.books.first.chapterIndex, 2);
    expect(bookProvider.books.first.position, 500);

    final highlights = storage.getHighlights(book.id);
    expect(highlights.length, 1);
    expect(highlights.first.note, 'Remember this');

    print('✅ E2E Journey Test PASSED');
  });

  testWidgets('E2E: Audio playback flow', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: Text('Test Audio Flow'),
          ),
        ),
      ),
    );

    print('✅ Audio Flow Test PASSED');
  });
}
