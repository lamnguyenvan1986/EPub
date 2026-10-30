import 'package:flutter/material.dart';
import 'package:libri_audio/models/book_model.dart';
import 'package:libri_audio/services/storage_service.dart';
import 'package:libri_audio/services/drive_service.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:path/path.dart' as p;

class BookProvider with ChangeNotifier {
  final StorageService _storage = StorageService();
  // Dùng chung singleton với các màn hình để giữ cùng phiên đăng nhập
  final DriveService _drive = DriveService();

  BookProvider() {
    _loadBooks();
  }

  DriveService get driveService => _drive;

  List<Book> _books = <Book>[];
  Book? _currentBook;
  bool _isLoading = false;
  bool _isSyncing = false;
  String? _error;

  List<Book> get books => _books;
  Book? get currentBook => _currentBook;
  bool get isLoading => _isLoading;
  bool get isSyncing => _isSyncing;
  String? get error => _error;
  bool get hasBooks => _books.isNotEmpty;

  Future<void> _loadBooks() async {
    _books = _storage.books;
    notifyListeners();
  }

  /// Helper method to add or update a book
  Future<void> _addOrUpdateBook({
    required String title,
    required String filePath,
    required String fileType,
    String? author,
    String? coverPath,
    bool fromDrive = false,
    drive.File? driveFile,
  }) async {
    // Check if book already exists (same path or same title)
    final existingBook = _books.where(
      (b) => b.filePath == filePath || b.title == title,
    ).firstOrNull;

    var book = existingBook ??
        Book(
          title: title,
          author: author ?? 'Unknown',
          filePath: filePath,
          fileType: fileType,
          coverPath: coverPath,
        );

    var resolvedPath = filePath;
    if (fromDrive && driveFile != null) {
      // For Drive files, download first; filePath is only the Drive file name
      final downloadedPath = await _drive.downloadFile(driveFile, book.id);
      if (downloadedPath == null) {
        _error = 'Failed to download file from Drive';
        notifyListeners();
        return;
      }
      resolvedPath = downloadedPath;
    }

    book = book.copyWith(filePath: resolvedPath, fileType: fileType);

    if (existingBook != null) {
      _storage.updateBook(book);
      final index = _books.indexWhere((b) => b.id == existingBook.id);
      if (index != -1) {
        _books[index] = book;
      }
    } else {
      _storage.addBook(book);
      _books.add(book);
    }
  }

  Future<void> addBookFromDrive(drive.File file) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _addOrUpdateBook(
        title: file.name ?? 'unknown',
        filePath: file.name ?? '',
        fileType: file.mimeType ?? 'application/octet-stream',
        author: 'Unknown',
        fromDrive: true,
        driveFile: file,
      );
    } catch (error) {
      _error = error.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> addBookFromFilePath(String filePath) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final fileName = p.basename(filePath);
      final libraryPath = await _storage.copyFileToLibrary(filePath);

      await _addOrUpdateBook(
        title: fileName,
        filePath: libraryPath,
        fileType: DriveService.getMimeType(filePath),
        author: 'Unknown',
      );
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Web: không có đường dẫn file, lưu bytes vào Hive theo id sách.
  Future<void> addBookFromBytes(String fileName, List<int> bytes) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final book = Book(
        title: fileName,
        author: 'Unknown',
        filePath: fileName,
        fileType: DriveService.getMimeType(fileName),
      );
      await _storage.saveBookFileBytes(book.id, bytes);
      _storage.addBook(book);
      _books.add(book);
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void addBook(Book book) {
    _storage.addBook(book);
    _books.add(book);
    notifyListeners();
  }

  Future<void> importLocalFile(String filePath) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _addOrUpdateBook(
        title: p.basename(filePath),
        filePath: filePath,
        fileType: DriveService.getMimeType(filePath),
        author: 'Unknown',
      );
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void setCurrentBook(Book book) {
    _currentBook = book;
    notifyListeners();
  }

  void removeBook(String bookId) {
    _storage.removeBook(bookId);
    _books.removeWhere((book) => book.id == bookId);
    if (_currentBook?.id == bookId) {
      _currentBook = null;
    }
    notifyListeners();
  }

  void updateBook(Book book) {
    _storage.updateBook(book);
    final index = _books.indexWhere((b) => b.id == book.id);
    if (index != -1) {
      _books[index] = book;
      notifyListeners();
    }
  }

  void saveReadingProgress(String bookId, int chapterIndex, int position) {
    _storage.saveReadingState(bookId, chapterIndex, position);

    final bookIndex = _books.indexWhere((b) => b.id == bookId);
    if (bookIndex != -1) {
      _books[bookIndex] = _books[bookIndex].copyWith(
        chapterIndex: chapterIndex,
        position: position,
        lastRead: DateTime.now(),
      );
      notifyListeners();
    }
  }

  Future<void> refreshBooks() async {
    await _loadBooks();
  }

  Future<void> syncWithDrive() async {
    _isSyncing = true;
    notifyListeners();

    try {
      if (!_drive.isAuthenticated) {
        _isSyncing = false;
        notifyListeners();
        return;
      }

      final driveFiles = await _drive.listPdfAndEpubFiles();

      for (final file in driveFiles) {
        final existingBook = _books.where((b) => b.title == file.name).firstOrNull;

        // Add books that are missing or have no usable file path
        if (existingBook == null ||
            existingBook.filePath == null ||
            existingBook.filePath!.isEmpty) {
          await addBookFromDrive(file);
        }
      }

      _isSyncing = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isSyncing = false;
      notifyListeners();
    }
  }
}
