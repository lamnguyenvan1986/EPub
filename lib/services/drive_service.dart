import 'package:flutter/foundation.dart' show ChangeNotifier, kIsWeb;
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:googleapis_auth/auth_io.dart' as auth;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:libri_audio/services/storage_service.dart';
import 'dart:io' show File, Directory;

/// Singleton: mọi màn hình và BookProvider dùng chung một phiên đăng nhập Drive.
class DriveService extends ChangeNotifier {
  static final DriveService _instance = DriveService._internal();
  factory DriveService() => _instance;
  DriveService._internal();

  static const List<String> _scopes = [
    drive.DriveApi.driveFileScope,
    drive.DriveApi.driveReadonlyScope,
  ];

  drive.DriveApi? _driveApi;
  GoogleSignInAccount? _account;
  DateTime? _tokenExpiry;
  Future<void>? _initFuture;

  GoogleSignIn get _googleSignIn => GoogleSignIn.instance;

  drive.DriveApi? get driveApi => _driveApi;
  bool get isAuthenticated => _driveApi != null;

  /// Check if Google Sign-In is supported on this platform
  /// google_sign_in is deprecated on web and will be removed
  /// Also not supported on Linux - use file picker instead
  bool get isGoogleSignInSupported => !kIsWeb;

  /// google_sign_in 7.x yêu cầu gọi initialize() đúng một lần trước khi dùng.
  Future<void> _ensureInitialized() {
    return _initFuture ??= _googleSignIn.initialize();
  }

  Future<GoogleSignInAccount?> signIn() async {
    if (kIsWeb) {
      print('Google Sign-In is not supported on web. Use Google Identity Services instead.');
      return null;
    }
    try {
      await _ensureInitialized();
      _account = await _googleSignIn.authenticate();
      return _account;
    } catch (error) {
      print('Error signing in: $error');
      return null;
    }
  }

  Future<void> signOut() async {
    await _ensureInitialized();
    await _googleSignIn.signOut();
    _driveApi = null;
    _account = null;
    _tokenExpiry = null;
    notifyListeners();
  }

  /// Get the current signed-in account
  Future<GoogleSignInAccount?> getCurrentUser() async => _account;

  Future<bool> authenticate() async {
    if (kIsWeb) {
      print('Google Sign-In is not supported on web. Use Google Identity Services instead.');
      return false;
    }

    try {
      // Check if already authenticated
      if (_driveApi != null) return true;

      await _ensureInitialized();
      _account = await _googleSignIn.authenticate();

      // Get access token for Drive API using authorizationClient
      final authz = await _account!.authorizationClient.authorizeScopes(_scopes);
      _setAccessToken(authz.accessToken);
      notifyListeners();
      return true;
    } catch (error) {
      print('Error authenticating: $error');
      return false;
    }
  }

  void _setAccessToken(String token) {
    // google_sign_in không trả refresh token; access token sống khoảng 1 giờ.
    _tokenExpiry = DateTime.now().add(const Duration(minutes: 55));
    final credentials = auth.AccessCredentials(
      auth.AccessToken('Bearer', token, _tokenExpiry!.toUtc()),
      null,
      _scopes,
    );
    final client = auth.authenticatedClient(http.Client(), credentials);
    _driveApi = drive.DriveApi(client);
  }

  /// Lấy lại access token (không cần UI) khi token sắp hết hạn.
  Future<bool> _ensureFreshToken() async {
    if (_driveApi == null) return false;
    final expiry = _tokenExpiry;
    if (expiry != null && DateTime.now().isBefore(expiry)) return true;

    try {
      final authz = await _account?.authorizationClient.authorizationForScopes(_scopes);
      if (authz == null) {
        // Cần người dùng đăng nhập lại
        _driveApi = null;
        notifyListeners();
        return false;
      }
      _setAccessToken(authz.accessToken);
      return true;
    } catch (e) {
      print('Error refreshing Drive token: $e');
      _driveApi = null;
      notifyListeners();
      return false;
    }
  }

  Future<List<drive.File>> listFiles({String? mimeType}) async {
    if (!await _ensureFreshToken()) {
      return [];
    }

    final query = [
      'trashed = false',
      if (mimeType != null) "mimeType = '$mimeType'",
    ].join(' and ');

    final files = <drive.File>[];
    String? pageToken;
    do {
      final fileList = await _driveApi!.files.list(
        q: query,
        orderBy: 'modifiedTime desc',
        spaces: 'drive',
        pageSize: 100,
        pageToken: pageToken,
        $fields: 'nextPageToken, files(id, name, mimeType, modifiedTime)',
      );
      files.addAll(fileList.files ?? []);
      pageToken = fileList.nextPageToken;
    } while (pageToken != null);

    return files;
  }

  Future<List<drive.File>> listPdfAndEpubFiles() async {
    final pdfFiles = await listFiles(mimeType: 'application/pdf');
    final epubFiles = await listFiles(mimeType: 'application/epub+zip');
    final mobiFiles = await listFiles(mimeType: 'application/x-mobipocket-ebook');

    return [...pdfFiles, ...epubFiles, ...mobiFiles];
  }

  /// Download file and return the file path/identifier
  /// On web, returns a fake path; bytes are stored in Hive with bookId
  /// On mobile/desktop, returns the actual file path
  Future<String?> downloadFile(drive.File file, String? bookId) async {
    if (!await _ensureFreshToken()) {
      return null;
    }

    try {
      final response = await _driveApi!.files.get(file.id!,
          downloadOptions: drive.DownloadOptions.fullMedia);
      final media = response as drive.Media;

      // Media has a stream property that emits List<int>
      final bytes = await media.stream.toList();
      final buffer = bytes.expand((e) => e).toList();

      // On web, save file bytes to Hive; on mobile/desktop, save to file system
      if (kIsWeb) {
        // For web, save bytes to Hive with bookId as key
        if (bookId != null && bookId.isNotEmpty) {
          final storageService = StorageService();
          await storageService.saveBookFileBytes(bookId, buffer);
        }
        // Return a fake path for web (will use fileBytes instead)
        return file.name;
      } else {
        // Mỗi file Drive một thư mục riêng theo id để tránh ghi đè file trùng tên
        final dir = await getApplicationDocumentsDirectory();
        final bookDir = Directory(p.join(dir.path, 'books', 'drive_${file.id}'));
        await bookDir.create(recursive: true);
        final filename = file.name ?? 'file_${file.id}';
        final filePath = p.join(bookDir.path, filename);

        final fileObj = File(filePath);
        await fileObj.writeAsBytes(buffer);

        return filePath;
      }
    } catch (e) {
      print('Error downloading file: $e');
      return null;
    }
  }

  /// Pick a file from device storage
  /// On web, file_picker returns bytes and filename (path is null due to browser security)
  /// On mobile/desktop, this returns the file path directly
  Future<String?> pickFileFromDevice() async {
    if (kIsWeb) {
      return _pickFileFromDeviceWeb();
    } else {
      return _pickFileFromDeviceMobile();
    }
  }

  /// Import a specific file by path directly (for importing known file paths)
  Future<String?> importFileByPath(String path) async {
    if (kIsWeb) {
      // On web, read bytes from the file
      try {
        final file = File(path);
        final bytes = await file.readAsBytes();
        final fileName = p.basename(path);
        final storageService = StorageService();
        return await storageService.saveFileBytes(fileName, bytes);
      } catch (e) {
        print('Error reading file: $e');
        return null;
      }
    } else {
      // On Linux, use the file path directly
      return path;
    }
  }

  /// Web-specific file picking
  /// Since path is null on web, we read bytes and save using StorageService
  /// For web, we use the file_picker's readAsBytes() method
  Future<String?> _pickFileFromDeviceWeb() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['epub', 'pdf', 'mobi'],
      );

      if (result.isEmpty) {
        print('No files selected');
        return null;
      }

      if (result.length > 1) {
        print('Multiple files selected, using first one');
      }

      final platformFile = result.single;

      // On web, path is null - read bytes directly
      final bytes = await platformFile.readAsBytes();
      final fileName = platformFile.name;

      // Use StorageService to save file bytes
      final storageService = StorageService();
      final filePath = await storageService.saveFileBytes(fileName, bytes);

      if (filePath != null) {
        print('Saved file to: $filePath');
      }
      return filePath;
    } catch (e) {
      print('Error picking file on web: $e');
      return null;
    }
  }

  /// Mobile/Desktop file picking - returns file path directly
  Future<String?> _pickFileFromDeviceMobile() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['epub', 'pdf', 'mobi'],
    );

    if (result.isEmpty) {
      print('No files selected');
      return null;
    }

    if (result.length > 1) {
      print('Multiple files selected, using first one');
    }

    final path = result.single.path;
    if (path == null || path.isEmpty) {
      print('File path is null or empty');
      return null;
    }

    print('Selected file path: $path');
    return path;
  }

  // Helper to get MIME type from extension
  static String getMimeType(String path) {
    // Extract extension - handle both full paths and bare filenames
    final parts = path.split('.');
    final extension = parts.length > 1 ? '.${parts.last}' : '';
    final lowerExt = extension.toLowerCase();

    switch (lowerExt) {
      case '.epub':
        return 'application/epub+zip';
      case '.pdf':
        return 'application/pdf';
      case '.mobi':
        return 'application/x-mobipocket-ebook';
      default:
        // Try to infer from path content for web fake paths
        if (path.toLowerCase().contains('.pdf')) {
          return 'application/pdf';
        }
        if (path.toLowerCase().contains('.epub')) {
          return 'application/epub+zip';
        }
        if (path.toLowerCase().contains('.mobi')) {
          return 'application/x-mobipocket-ebook';
        }
        return 'application/octet-stream';
    }
  }
}
