import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:googleapis_auth/auth_io.dart' as auth;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:libri_audio/services/storage_service.dart';
import 'dart:io' show File;

class DriveService {
  drive.DriveApi? _driveApi;
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    // Thay bằng Client ID của bạn từ Google Cloud Console
    // Để trống hoặc dùng null cho development
    clientId: '577711935566-ru5fvsii1r4jrgsckg8ku22vgq48anrt.apps.googleusercontent.com',
    scopes: [
      drive.DriveApi.driveFileScope,
      drive.DriveApi.driveReadonlyScope,
    ],
  );

  DriveService() {
    // Khởi tạo - sẽ setup khi authenticate
  }

  drive.DriveApi? get driveApi => _driveApi;
  bool get isAuthenticated => _driveApi != null;

  /// Check if Google Sign-In is supported on this platform
  /// google_sign_in is deprecated on web and will be removed
  /// Also not supported on Linux - use file picker instead
  bool get isGoogleSignInSupported => !kIsWeb ;
  Future<GoogleSignInAccount?> signIn() async {
    if (kIsWeb) {
      print('Google Sign-In is not supported on web. Use Google Identity Services instead.');
      return null;
    }
    try {
      final account = await _googleSignIn.signIn();
      return account;
    } catch (error) {
      print('Error signing in: $error');
      return null;
    }
  }

  Future<void> signOut() async {
    await _googleSignIn.signOut();
    _driveApi = null;
  }

  GoogleSignInAccount? get currentUser => _googleSignIn.currentUser;

  Future<bool> authenticate() async {
    if (kIsWeb) {
      print('Google Sign-In is not supported on web. Use Google Identity Services instead.');
      return false;
    }

    try {
      // Check if already authenticated
      if (_driveApi != null) return true;

      final account = await _googleSignIn.signIn();
      if (account == null) return false;

      final authResponse = await account.authentication;
      // In googleapis_auth 1.6.0, AccessToken takes 3 params: type, data, expiry
      final accessToken = auth.AccessToken('Bearer', authResponse.accessToken!, DateTime.now().add(const Duration(hours: 1)));
      // AccessCredentials order: accessToken, refreshToken, scopes
      final credentials = auth.AccessCredentials(
        accessToken,
        null, // No refresh token available from google_sign_in
        [drive.DriveApi.driveFileScope, drive.DriveApi.driveReadonlyScope],
      );

      // authenticatedClient takes baseClient and credentials
      final client = auth.authenticatedClient(http.Client(), credentials);
      _driveApi = drive.DriveApi(client);
      return true;
    } catch (error) {
      print('Error authenticating: $error');
      return false;
    }
  }

  void dispose() {
    _driveApi = null;
  }

  Future<List<drive.File>> listFiles({String? mimeType}) async {
    if (_driveApi == null) {
      return [];
    }

    try {
      final fileList = await _driveApi!.files.list(
        q: mimeType != null ? "mimeType='$mimeType'" : null,
        orderBy: 'modifiedTime desc',
        spaces: 'drive',
      );

      return fileList.files ?? [];
    } catch (e) {
      print('Error listing files: $e');
      return [];
    }
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
    if (_driveApi == null) {
      return null;
    }

    try {
      final response = await _driveApi!.files.get(file.id!, downloadOptions: drive.DownloadOptions.fullMedia);
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
        // Save to local storage on mobile/desktop
        final dir = await getApplicationDocumentsDirectory();
        final filename = file.name ?? 'file_${file.id}';
        final filePath = p.join(dir.path, filename);

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
