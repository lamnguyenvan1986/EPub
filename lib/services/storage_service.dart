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
    if (!Hive.isAdapterRegistered(0)) Hive.registerAdapter(BookAdapter());
    if (!Hive.isAdapterRegistered(1)) Hive.registerAdapter(ReadingStateAdapter());
    if (!Hive.isAdapterRegistered(2)) Hive.registerAdapter(HighlightAdapter());
    if (!Hive.isAdapterRegistered(3)) Hive.registerAdapter(PlaylistAdapter());

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
    _readingStatesBox.delete(bookId);
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

  ReadingState? getReadingState(String bookId) {
    final state = _readingStatesBox.get(bookId);
    return state is ReadingState ? state : null;
  }

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

  /// 'system', 'light' hoặc 'dark'. Null nếu người dùng chưa chọn.
  String? get themeMode {
    final mode = _prefs.getString('theme_mode');
    if (mode != null) return mode;
    // Bản cũ chỉ lưu dark_mode
    if (_prefs.containsKey('dark_mode')) return darkMode ? 'dark' : 'light';
    return null;
  }

  Future<void> saveThemeMode(String mode) => _prefs.setString('theme_mode', mode);

  String get lastDir => _prefs.getString('last_dir') ?? '';
  Future<void> saveLastDir(String path) => _prefs.setString('last_dir', path);

  double get pitch => _prefs.getDouble('pitch') ?? 1.0;
  Future<void> savePitch(double pitch) => _prefs.setDouble('pitch', pitch);

  // Bộ đọc TTS: 'system', 'offline', 'azure' hoặc 'google'. Key API lưu ở
  // flutter_secure_storage (TtsService), không lưu ở đây.
  String? get ttsEngine => _prefs.getString('tts_engine');
  Future<void> saveTtsEngine(String engine) => _prefs.setString('tts_engine', engine);

  String? get offlineVoiceId => _prefs.getString('offline_voice_id');
  Future<void> saveOfflineVoiceId(String id) => _prefs.setString('offline_voice_id', id);

  String? get azureVoice => _prefs.getString('azure_voice');
  Future<void> saveAzureVoice(String voice) => _prefs.setString('azure_voice', voice);

  String? get azureRegion => _prefs.getString('azure_region');
  Future<void> saveAzureRegion(String region) => _prefs.setString('azure_region', region);

  String? get googleVoice => _prefs.getString('google_voice');
  Future<void> saveGoogleVoice(String voice) => _prefs.setString('google_voice', voice);

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

  /// Copy a picked file into the app's own folder so it survives cache cleanup
  /// (file_picker on Android returns a copy inside the cache directory).
  Future<String> copyFileToLibrary(String sourcePath) async {
    if (kIsWeb) return sourcePath;
    final docsDir = await getApplicationDocumentsDirectory();
    final libraryDir = Directory(p.join(docsDir.path, 'books'));
    if (p.isWithin(libraryDir.path, sourcePath)) return sourcePath;

    final targetDir = Directory(
      p.join(libraryDir.path, DateTime.now().microsecondsSinceEpoch.toString()),
    );
    await targetDir.create(recursive: true);
    final copied = await File(sourcePath).copy(p.join(targetDir.path, p.basename(sourcePath)));
    return copied.path;
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
