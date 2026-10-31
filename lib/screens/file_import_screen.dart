import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:libri_audio/services/drive_service.dart';
import 'package:libri_audio/providers/book_provider.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'dart:io' show File;
import 'package:libri_audio/utils/file_picker_web_options_stub.dart'
    if (dart.library.js_interop) 'package:libri_audio/utils/file_picker_web_options_web.dart';

class FileImportScreen extends StatefulWidget {
  const FileImportScreen({super.key});

  @override
  State<FileImportScreen> createState() => _FileImportScreenState();
}

class _FileImportScreenState extends State<FileImportScreen> {
  // Singleton dùng chung với Provider và BookProvider
  final DriveService _driveService = DriveService();
  bool _isConnecting = false;
  String? _error;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Import Books'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: Navigator.of(context).pop,
        ),
        actions: [
          if (!kIsWeb) ...[
            Consumer<DriveService>(
              builder: (context, driveService, child) {
                if (driveService.isAuthenticated) {
                  return TextButton(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => GoogleDriveBooksScreen(),
                        ),
                      );
                    },
                    child: const Text('Google Drive'),
                  );
                }
                return TextButton(
                  onPressed: _isConnecting ? null : _handleGoogleSignIn,
                  child: _isConnecting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Connect Google Drive'),
                );
              },
            ),
          ],
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildImportMethodCard(
                    icon: Icons.file_upload_outlined,
                    title: 'Import from Device',
                    description: 'Select books from your device storage',
                    onPressed: _handleImportFromDevice,
                  ),
                  const SizedBox(height: 16),
                  if (!kIsWeb) ...[
                    _buildImportMethodCard(
                      icon: Icons.cloud_upload_outlined,
                      title: 'Import from Google Drive',
                      description: 'Select books from your Google Drive',
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => GoogleDriveBooksScreen(),
                          ),
                        );
                      },
                    ),
                  ] else ...[
                    _buildDisabledCard(
                      icon: Icons.cloud_upload_outlined,
                      title: 'Import from Google Drive',
                      description: 'Google Drive import is not supported on web. Use device storage instead.',
                    ),
                  ],
                ],
              ),
            ),
            if (_error != null)
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(top: 16),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error, color: Colors.red.shade700),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _error!,
                        style: TextStyle(color: Colors.red.shade700),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildImportMethodCard({
    required IconData icon,
    required String title,
    required String description,
    required VoidCallback onPressed,
  }) {
    return Card(
      child: ListTile(
        leading: Icon(icon, size: 48),
        title: Text(title),
        subtitle: Text(description),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: onPressed,
      ),
    );
  }

  Widget _buildDisabledCard({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Card(
      child: ListTile(
        leading: Icon(icon, size: 48, color: Colors.grey),
        title: Text(title, style: const TextStyle(color: Colors.grey)),
        subtitle: Text(description, style: const TextStyle(color: Colors.grey)),
        trailing: const Icon(Icons.lock, size: 16, color: Colors.grey),
        onTap: null,
      ),
    );
  }

  Future<void> _handleGoogleSignIn() async {
    if (kIsWeb) {
      setState(() {
        _error = 'Google Sign-In is not supported on web. Use device storage instead.';
      });
      return;
    }

    setState(() {
      _isConnecting = true;
      _error = null;
    });

    try {
      final success = await _driveService.authenticate();
      if (!mounted) return;
      setState(() {
        _isConnecting = false;
        if (!success) _error = 'Failed to connect to Google Drive';
      });
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Connected to Google Drive')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isConnecting = false;
      });
    }
  }

  static const List<String> _supportedExtensions = ['pdf', 'epub', 'mobi', 'azw', 'azw3'];

  Future<void> _handleImportFromDevice() async {
    // Import from device using file picker
    try {
      // Safari iOS làm mờ file có đuôi không nhận ra (.mobi, .azw...) khi lọc
      // theo đuôi, nên trên web cho chọn mọi file rồi tự kiểm tra đuôi.
      setState(() => _error = null);
      PlatformFile? result = await FilePicker.pickFile(
        type: kIsWeb ? FileType.any : FileType.custom,
        allowedExtensions: kIsWeb ? null : _supportedExtensions,
        webOptions: filePickerWebOptions(),
      );

      if (result == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No file selected')),
          );
        }
        return;
      }

      final extension = result.name.split('.').last.toLowerCase();
      if (!result.name.contains('.') || !_supportedExtensions.contains(extension)) {
        if (mounted) {
          setState(() {
            _error = 'Unsupported file: ${result.name}. Choose a PDF, EPUB, MOBI or AZW file.';
          });
        }
        return;
      }

      final bookProvider = context.read<BookProvider>();

      if (kIsWeb) {
        // Web không có đường dẫn file: lưu bytes vào Hive
        final bytes = await result.readAsBytes();
        await bookProvider.addBookFromBytes(result.name, bytes);
      } else {
        final filePath = result.path;
        if (filePath == null || !File(filePath).existsSync()) {
          if (mounted) {
            setState(() {
              _error = 'File not found: ${filePath ?? result.name}';
            });
          }
          return;
        }

        print('Importing file: $filePath');
        await bookProvider.addBookFromFilePath(filePath);
      }

      if (!mounted) return;
      if (bookProvider.error != null) {
        setState(() => _error = bookProvider.error);
        return;
      }
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Book imported successfully')),
      );
    } catch (e) {
      print('Error importing file: $e');
      if (!mounted) return;
      setState(() {
        _error = 'Error: ${e.toString()}';
      });
    }
  }
}

class GoogleDriveBooksScreen extends StatefulWidget {
  const GoogleDriveBooksScreen({super.key});

  @override
  State<GoogleDriveBooksScreen> createState() => _GoogleDriveBooksScreenState();
}

class _GoogleDriveBooksScreenState extends State<GoogleDriveBooksScreen> {
  // Giữ future để không gọi lại Drive API mỗi lần rebuild
  Future<List<drive.File>>? _filesFuture;
  bool _isConnecting = false;
  String? _connectError;

  Future<void> _connect() async {
    setState(() {
      _isConnecting = true;
      _connectError = null;
    });
    final success = await DriveService().authenticate();
    if (!mounted) return;
    setState(() {
      _isConnecting = false;
      _filesFuture = null;
      if (!success) _connectError = 'Failed to connect to Google Drive';
    });
  }

  Widget _buildConnectPrompt(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.cloud_off, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _isConnecting ? null : _connect,
              icon: _isConnecting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.login),
              label: const Text('Connect Google Drive'),
            ),
            if (_connectError != null) ...[
              const SizedBox(height: 12),
              Text(_connectError!, style: TextStyle(color: Colors.red.shade700)),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _downloadAndImportFile(BuildContext context, drive.File file) async {
    try {
      final bookProvider = context.read<BookProvider>();
      await bookProvider.addBookFromDrive(file);
      if (!mounted) return;
      final error = bookProvider.error;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error == null ? 'Book imported: ${file.name}' : 'Error: $error')),
      );
      if (error == null) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Google Drive'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: Navigator.of(context).pop,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: () => setState(() => _filesFuture = null),
          ),
        ],
      ),
      body: Consumer<DriveService>(
        builder: (context, driveService, child) {
          if (!driveService.isAuthenticated) {
            // Phiên hết hạn giữa chừng: bỏ kết quả cũ để tải lại sau khi kết nối
            _filesFuture = null;
            return _buildConnectPrompt(
              'Please connect Google Drive first. If you were connected before, your session may have expired.',
            );
          }

          return FutureBuilder<List<drive.File>>(
            future: _filesFuture ??= driveService.listPdfAndEpubFiles(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error, size: 48, color: Colors.red),
                      const SizedBox(height: 8),
                      Text(snapshot.error.toString()),
                    ],
                  ),
                );
              }

              final files = snapshot.data ?? [];

              if (files.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(Icons.folder_open, size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text('No PDF, EPUB or MOBI files found in Google Drive'),
                    ],
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: files.length,
                itemBuilder: (context, index) {
                  final file = files[index];
                  return Card(
                    child: ListTile(
                      leading: file.mimeType?.contains('pdf') == true
                        ? const Icon(Icons.picture_as_pdf, color: Colors.red)
                        : const Icon(Icons.book, color: Colors.blue),
                      title: Text(file.name ?? 'Unknown'),
                      subtitle: Text(file.mimeType ?? ''),
                      trailing: IconButton(
                        icon: const Icon(Icons.download),
                        onPressed: () async {
                          await _downloadAndImportFile(context, file);
                        },
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
