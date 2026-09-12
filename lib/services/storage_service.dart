import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart' show getApplicationDocumentsDirectory;
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io' show File, Directory;
import 'package:libri_audio/models/highlight_model.dart';
import 'package:libri_audio/models/book_model.dart';
import 'package:libri_audio/models/playlist_model.dart';

class StorageService {
  static final StorageService _instance = StorageService._internal();
  factory StorageService() => _instance;
  StorageService._internal();

  late Box _booksBox;
  late Box _readingStatesBox;
  late Box _highlightsBox;
  late Box _playlistsBox;
  late SharedPreferences _prefs;

  // Box for storing file bytes (for web)
  late Box _fileBytesBox;

  Future<void> init() async {
    // Initialize Hive
    if (kIsWeb) {
      // On web, Hive initializes automatically via hive_flutter
      await Hive.initFlutter();
    } else {
      // On mobile/desktop, use application documents directory
      final documentsDir = await getApplicationDocumentsDirectory();
      Hive.init(documentsDir.path);
    }

    // Register adapters
    Hive.registerAdapter(BookAdapter());
    Hive.registerAdapter(ReadingStateAdapter());
    Hive.registerAdapter(HighlightAdapter());

    // Open boxes
    _booksBox = await Hive.openBox('books');
    _readingStatesBox = await Hive.openBox('reading_states');
    _highlightsBox = await Hive.openBox('highlights');
    _playlistsBox = await Hive.openBox('playlists');
    _fileBytesBox = await Hive.openBox('file_bytes');

    // Initialize SharedPreferences
    _prefs = await SharedPreferences.getInstance();
  }

  // Books
  List<Book> get books => _booksBox.values.cast<Book>().toList();
  void addBook(Book book) => _booksBox.put(book.id, book);
  void updateBook(Book book) => _booksBox.put(book.id, book);
  void removeBook(String bookId) {
    _booksBox.delete(bookId);
    // Also remove file bytes for this book on web
    if (kIsWeb) {
      _fileBytesBox.delete(bookId);
    }
  }
  Book? getBook(String bookId) => _booksBox.get(bookId);

  // Reading States
  void saveReadingState(String bookId, int chapterIndex, int position) {
    final state = ReadingState(
      bookId: bookId,
      chapterIndex: chapterIndex,
      position: position,
      timestamp: DateTime.now(),
    );
    _readingStatesBox.put(bookId, state);

    // Update book's last read info
    final book = getBook(bookId);
    if (book != null) {
      final updatedBook = book.copyWith(
        lastRead: DateTime.now(),
        chapterIndex: chapterIndex,
        position: position,
      );
      updateBook(updatedBook);
    }
  }

  ReadingState? getReadingState(String bookId) => _readingStatesBox.get(bookId);

  // Highlights
  void saveHighlight(Highlight highlight) => _highlightsBox.put(highlight.id, highlight);
  void updateHighlight(Highlight highlight) => _highlightsBox.put(highlight.id, highlight);
  void deleteHighlight(String highlightId) => _highlightsBox.delete(highlightId);
  List<Highlight> getHighlights(String bookId) => _highlightsBox.values
      .where((h) => (h as Highlight).bookId == bookId)
      .cast<Highlight>()
      .toList();

  // Playlists
  void savePlaylist(Playlist playlist) => _playlistsBox.put('playlist_${playlist.id}', playlist);
  void updatePlaylist(Playlist playlist) => _playlistsBox.put('playlist_${playlist.id}', playlist);
  void deletePlaylist(String playlistId) => _playlistsBox.delete('playlist_$playlistId');
  List<Playlist> getPlaylists() => _playlistsBox.values.cast<Playlist>().toList();

  // Preferences
  String? get savedVoiceId => _prefs.getString('voice_id');
  Future<void> saveVoiceId(String voiceId) => _prefs.setString('voice_id', voiceId);

  double get readingSpeed => _prefs.getDouble('reading_speed') ?? 1.0;
  Future<void> saveReadingSpeed(double speed) => _prefs.setDouble('reading_speed', speed);

  bool get darkMode => _prefs.getBool('dark_mode') ?? false;
  Future<void> saveDarkMode(bool enabled) => _prefs.setBool('dark_mode', enabled);

  String get lastDir => _prefs.getString('last_dir') ?? '';
  Future<void> saveLastDir(String path) => _prefs.setString('last_dir', path);

  // File operations
  Future<String?> saveFileToFileSystem(
    Directory dir,
    String fileName,
    List<int> data,
  ) async {
    try {
      final file = File(p.join(dir.path, fileName));
      await file.writeAsBytes(data);
      return file.path;
    } catch (e) {
      print('Error saving file: $e');
      return null;
    }
  }

  /// Save file bytes to storage
  /// On web, saves to Hive with the book ID as key
  /// On mobile/desktop, saves to file system and returns path
  Future<String?> saveFileBytes(String fileName, List<int> data) async {
    try {
      if (kIsWeb) {
        // On web, save file bytes to Hive
        // We'll use the book ID as the key, so we need to get it from the book
        // For now, return the filename and store bytes separately
        // The book should be created with a unique ID first
        return fileName;
      } else {
        // On mobile/desktop, save to documents directory
        final dir = await getApplicationDocumentsDirectory();
        final filePath = p.join(dir.path, fileName);
        final file = File(filePath);
        await file.writeAsBytes(data);
        return filePath;
      }
    } catch (e) {
      print('Error saving file bytes: $e');
      return null;
    }
  }

  /// Save file bytes for a specific book (web only)
  Future<void> saveBookFileBytes(String bookId, List<int> bytes) async {
    try {
      if (kIsWeb) {
        await _fileBytesBox.put(bookId, bytes);
      }
    } catch (e) {
      print('Error saving book file bytes: $e');
    }
  }

  /// Get file bytes for a book (web only)
  List<int>? getBookFileBytes(String bookId) {
    if (kIsWeb) {
      return _fileBytesBox.get(bookId);
    }
    return null;
  }

  // Export book as text
  Future<String?> exportBookAsText(String bookId) async {
    final book = getBook(bookId);
    if (book == null || book.fileType != 'epub') return null;

    try {
      // This would require EPUB parsing to extract text
      // For now, return a placeholder
      return 'Exported content from ${book.title}';
    } catch (e) {
      return null;
    }
  }
}

class ReadingState {
  final String bookId;
  final int chapterIndex;
  final int position;
  final DateTime timestamp;

  ReadingState({
    required this.bookId,
    required this.chapterIndex,
    required this.position,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'bookId': bookId,
      'chapterIndex': chapterIndex,
      'position': position,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  factory ReadingState.fromMap(Map<String, dynamic> map) {
    return ReadingState(
      bookId: map['bookId'],
      chapterIndex: map['chapterIndex'],
      position: map['position'],
      timestamp: DateTime.parse(map['timestamp']),
    );
  }
}
