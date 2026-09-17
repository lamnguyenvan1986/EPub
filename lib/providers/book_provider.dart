import 'package:flutter/material.dart';
import 'package:libri_audio/models/book_model.dart';
import 'package:libri_audio/services/storage_service.dart';
import 'package:libri_audio/services/drive_service.dart';
import 'package:googleapis/drive/v3.dart' as drive;

class BookProvider with ChangeNotifier {
  final StorageService _storage = StorageService();
  late DriveService _drive;

  BookProvider() {
    _drive = DriveService();
    _loadBooks();
  }

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
    final fileName = filePath.split('/').last;

    // Check if book already exists
    final existingBook = _books.firstWhere(
      (b) => b.filePath == filePath || b.title == fileName,
      orElse: () => Book(title: '', filePath: '', fileType: 'application/octet-stream'),
    );

    if (existingBook.id.isNotEmpty && existingBook.filePath != null) {
      // Book already exists, update it
      final updatedBook = existingBook.copyWith(
        filePath: filePath,
        fileType: fileType,
      );
      _storage.updateBook(updatedBook);
      final index = _books.indexWhere((b) => b.id == existingBook.id);
      if (index != -1) {
        _books[index] = updatedBook;
      }
    } else {
      // Add new book
      final book = Book(
        title: title,
        author: author ?? 'Unknown',
        filePath: filePath,
        fileType: fileType,
        coverPath: coverPath,
      );

      if (fromDrive && driveFile != null) {
        // For Drive files, download first then add
        final downloadedPath = await _drive.downloadFile(driveFile, book.id);
        if (downloadedPath == null) {
          _error = 'Failed to download file from Drive';
          notifyListeners();
          return;
        }
        book.copyWith(filePath: downloadedPath);
      }

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
      final fileName = filePath.split('/').last;

      await _addOrUpdateBook(
        title: fileName,
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
      final fileName = filePath.split('/').last;

      await _addOrUpdateBook(
        title: fileName,
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
        final existingBook = _books.firstWhere(
          (b) => b.title == file.name,
          orElse: () => Book(title: '', fileType: 'application/octet-stream'),
        );

        // Check if book needs to be added or updated
        if (existingBook.id.isEmpty || existingBook.filePath == null) {
          // Book doesn't exist or has no file path, add it
          await addBookFromDrive(file);
        } else if (existingBook.filePath == null || existingBook.filePath!.isEmpty) {
          // Book exists but has no valid file path, update it
          await addBookFromDrive(file);
        }
      }

      _isSyncing = false;
      notifyListeners();
    } catch (e) {
      _isSyncing = false;
      notifyListeners();
    }
  }
}
