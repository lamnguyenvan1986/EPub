import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb, Uint8List;
import 'package:katbook_epub_reader/katbook_epub_reader.dart';
import 'package:provider/provider.dart';
import 'package:libri_audio/models/book_model.dart';
import 'package:share_plus/share_plus.dart';
import 'package:libri_audio/services/tts_service.dart';
import 'package:libri_audio/services/storage_service.dart';
import 'package:libri_audio/widgets/voice_selector.dart';
import 'package:libri_audio/screens/search_screen.dart';
import 'package:libri_audio/providers/book_provider.dart' show BookProvider;
import 'package:libri_audio/widgets/pdf_viewer.dart' as pdf_widgets;
import 'package:pdfrx/pdfrx.dart';

/// Screen hiển thị nội dung sách với hỗ trợ EPUB, PDF và Text-to-Speech.
///
/// Tính năng:
/// - Đọc sách EPUB với katbook_epub_reader
/// - Đọc sách PDF với pdfrx
/// - Chế độ nghe audio với TTS
/// - Chuyển đổi chương, tìm kiếm, cài đặt
/// - Chia sẻ và xuất file
class BookReaderScreen extends StatefulWidget {
  final Book book;
  final bool autoPlay;
  
  const BookReaderScreen({super.key, required this.book, this.autoPlay = false});

  @override
  State<BookReaderScreen> createState() => _BookReaderScreenState();
}

/// Screen hiển thị nội dung sách với hỗ trợ EPUB, PDF và Text-to-Speech.
///
/// Tính năng:
/// - Đọc sách EPUB với katbook_epub_reader
/// - Đọc sách PDF với pdfrx
/// - Chế độ nghe audio với TTS
/// - Chuyển đổi chương, tìm kiếm, cài đặt
/// - Chia sẻ và xuất file
class _BookReaderScreenState extends State<BookReaderScreen> {
  late Book _book;
  int _currentChapterIndex = 0;
  bool _isAudioMode = false;
  String? _textContent;
  bool _isLoading = true;
  String? _error;
  final TextEditingController _searchController = TextEditingController();

  // EPUB specific
  KatbookEpubController? _epubController;
  Uint8List? _epubBytes;

  // PDF specific
  Uint8List? _pdfBytes;

  @override
  void initState() {
    super.initState();
    _book = widget.book;
    _loadBook();

    // Auto-play from last position
    if (widget.autoPlay && _book.lastRead != null) {
      _startAudioReading();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadBook() async {
    setState(() => _isLoading = true);

    try {
      // Load saved reading state
      final savedState = StorageService().getReadingState(_book.id);
      if (savedState != null) {
        _currentChapterIndex = savedState.chapterIndex;
      }
      
      if (_book.fileType.contains('epub')) {
        await _loadEpub();
      } else if (_book.fileType.contains('pdf')) {
        await _loadPdf();
        // _isAudioMode = false; // PDF không hỗ trợ TTS tốt
      } else {
        throw Exception('Định dạng file không được hỗ trợ: ${_book.fileType}');
      }
      
      setState(() => _isLoading = false);
    } on Exception catch (e, stackTrace) {
      setState(() {
        _isLoading = false;
        _error = 'Lỗi khi đọc file: ${e.toString()}';
      });

      // Log error
      print('BookReader Error: $stackTrace');
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = 'Đã xảy ra lỗi không mong muốn. Vui lòng thử lại.';
      });
    }
  }

  Future<void> _loadEpub() async {
    try {
      if (_book.filePath == null) {
        setState(() {
          _error = 'Không tìm thấy file EPUB';
        });
        return;
      }

      // Get file bytes from storage
      final storage = StorageService();
      final bytes = storage.getBookFileBytes(_book.id);

      if (bytes == null) {
        // Try to read from file path directly
        try {
          final file = File(_book.filePath!);
          _epubBytes = await file.readAsBytes();
        } catch (e) {
          print('Error reading file: $e');
          throw Exception('Không thể đọc file EPUB');
        }
      } else {
        _epubBytes = Uint8List.fromList(bytes);
      }

      // Parse EPUB book
      try {
        _epubController = KatbookEpubController();
        final success = await _epubController!.openBook(_epubBytes!);
        if (!success) {
          throw Exception('Không thể đọc file EPUB');
        }

        // Extract text from all chapters for TTS
        _textContent = await _extractTextFromEpub();
      } catch (e) {
        print('Error parsing EPUB: $e');
        throw Exception('Không thể đọc file EPUB');
      }

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading EPUB: $e');
      setState(() {
        _isLoading = false;
        _error = 'Lỗi khi đọc file EPUB: ${e.toString()}';
      });
    }
  }

  /// Extract text content from all EPUB chapters for TTS.
  ///
  /// Duyệt qua tất cả các paragraph trong EPUB và nối lại thành một chuỗi.
  Future<String> _extractTextFromEpub() async {
    try {
      final paragraphs = _epubController?.paragraphs ?? [];
      if (paragraphs.isEmpty) {
        return '';
      }

      final buffer = StringBuffer();

      // Duyệt qua từng paragraph và trích xuất text
      for (final paragraph in paragraphs) {
        final text = paragraph.text.trim();
        if (text.isNotEmpty) {
          buffer.write(text);
          buffer.write(' ');
        }
      }

      return buffer.toString();
    } catch (e) {
      print('Error extracting text from EPUB: $e');
      return '';
    }
  }

  Future<void> _loadPdf() async {
    try {
      if (kIsWeb) {
        // On web, get PDF bytes from storage (filePath doesn't exist in browser)
        // Key is filePath (file name from Drive) not bookId
        final storage = StorageService();
        final bytes = storage.getBookFileBytes(_book.filePath ?? '');
        _pdfBytes = bytes != null ? Uint8List.fromList(bytes) : null;

        if (_pdfBytes == null) {
          setState(() {
            _error = 'Không tìm thấy file PDF';
          });
          return;
        }
      } else {
        // On mobile/desktop, use file path
        if (_book.filePath == null) {
          setState(() {
            _error = 'Không tìm thấy file PDF';
          });
          return;
        }

        final file = File(_book.filePath!);
        if (!await file.exists()) {
          setState(() {
            _error = 'File PDF không tồn tại';
          });
          return;
        }

        _pdfBytes = await file.readAsBytes();
      }

      // Extract text from PDF for TTS
      _textContent = await _extractTextFromPdf();

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading PDF: $e');
      setState(() {
        _isLoading = false;
        _error = 'Lỗi khi đọc file PDF: ${e.toString()}';
      });
    }
  }

  /// Extract text content from PDF for TTS.
  ///
  /// Sử dụng pdfrx để trích xuất text từ từng trang PDF.
  Future<String> _extractTextFromPdf() async {
    try {
      if (_pdfBytes == null || _pdfBytes!.isEmpty) {
        return '';
      }

      final buffer = StringBuffer();

      // Use pdfrx to extract text from all pages
      final pdfDocument = await PdfDocument.openData(Uint8List.fromList(_pdfBytes!));
      final totalPages = pdfDocument.pages.length;

      for (int i = 0; i < totalPages; i++) {
        try {
          final page = pdfDocument.pages[i];
          final text = await page.loadText();
          if (text?.fullText.isNotEmpty ?? false) {
            buffer.write(text!.fullText.trim());
            buffer.write('\n\n');
          }
        } catch (e) {
          print('Error extracting text from PDF page $i: $e');
          continue;
        }
      }

      return buffer.toString();
    } catch (e) {
      print('Error extracting text from PDF: $e');
      // Fallback: try alternative method
      try {
        final pdfDocument = await PdfDocument.openData(Uint8List.fromList(_pdfBytes!));
        final totalPages = pdfDocument.pages.length;
        final buffer = StringBuffer();

        for (int i = 0; i < totalPages; i++) {
          try {
            final page = pdfDocument.pages[i];
            final text = await page.loadText();
            if (text?.fullText.isNotEmpty ?? false) {
              buffer.write(text!.fullText.trim());
              buffer.write('\n\n');
            }
          } catch (e) {
            print('Error extracting text from PDF page $i: $e');
            continue;
          }
        }
        return buffer.toString();
      } catch (e2) {
        print('Alternative PDF extraction also failed: $e2');
        return '';
      }
    }
  }
  
  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Đang đọc...')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    
    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Error')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => _loadBook(),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }
    
    if (_isAudioMode) {
      return _buildAudioMode();
    }
    
    if (_book.fileType.contains('pdf')) {
      return _buildPdfReader();
    }
    
    return _buildEpubReader();
  }
  
  Widget _buildEpubReader() {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Expanded(
              child: Text(
                _book.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (_textContent != null)
              IconButton(
                icon: const Icon(Icons.search),
                onPressed: () {
                  _showSearchDialog();
                },
              ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.volume_up),
            onPressed: () {
              setState(() => _isAudioMode = true);
              _startAudioReading();
            },
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'share') {
                _shareBook();
              } else if (value == 'export') {
                _exportBook();
              } else if (value == 'settings') {
                _showSettingsDialog();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'share',
                child: ListTile(
                  leading: Icon(Icons.share),
                  title: Text('Chia sẻ'),
                ),
              ),
              const PopupMenuItem(
                value: 'export',
                child: ListTile(
                  leading: Icon(Icons.file_download),
                  title: Text('Xuất file'),
                ),
              ),
              const PopupMenuItem(
                value: 'settings',
                child: ListTile(
                  leading: Icon(Icons.settings),
                  title: Text('Cài đặt'),
                ),
              ),
            ],
          ),
        ],
      ),
      body: _epubController != null
        ? _buildEpubViewer()
        : const Center(child: Text('Loading EPUB...')),
      floatingActionButton: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_currentChapterIndex > 0)
            FloatingActionButton(
              heroTag: 'prev',
              onPressed: _goToPreviousChapter,
              child: const Icon(Icons.chevron_left),
            ),
          const SizedBox(width: 8),
          if (_currentChapterIndex < _getTotalChapters() - 1)
            FloatingActionButton(
              heroTag: 'next',
              onPressed: _goToNextChapter,
              child: const Icon(Icons.chevron_right),
            ),
        ],
      ),
    );
  }

  Widget _buildEpubViewer() {
    try {
      return KatbookEpubReader(
        controller: _epubController!,
        initialTheme: ReaderTheme.light,
        initialFontSize: 16.0,
        showAppBar: false,
        onChapterChanged: (chapter) {
          _currentChapterIndex = chapter.startIndex;
        },
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        contentWidthPercent: 0.85,
      );
    } catch (e) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text('EPUB Error: ${e.toString()}'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => _loadBook(),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }
  }

  /// Web-specific PDF viewer using data URI.
  ///
  /// Trình xem PDF dành cho web sử dụng data URI từ pdfBytes.
  Widget _buildPdfReaderWeb(String dataUri) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_book.title),
        actions: [
          IconButton(
            icon: const Icon(Icons.volume_up),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('PDF text-to-speech không được hỗ trợ')),
              );
            },
          ),
        ],
      ),
      body: Builder(
        builder: (context) {
          // Trả về widget giữ iframe sống
          return Container();
        },
      ),
    );
  }

  /// PDF reader widget - tự động chọn mode phù hợp.
  ///
  /// - Web: Sử dụng data URI với _buildPdfReaderWeb
  /// - Mobile/Desktop: Sử dụng PdfViewer widget
  Widget _buildPdfReader() {
    if (kIsWeb) {
      // On web, use data URI from pdfBytes
      if (_pdfBytes != null) {
        final base64Pdf = base64Encode(_pdfBytes!);
        final dataUri = 'data:application/pdf;base64,$base64Pdf';
        return _buildPdfReaderWeb(dataUri);
      }

      // Fallback for web without file bytes
      return Scaffold(
        appBar: AppBar(
          title: Text(_book.title),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.file_open, size: 64, color: Colors.grey),
              const SizedBox(height: 16),
              Text('PDF loading...'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => _loadBook(),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    // On mobile/desktop, use PdfViewer with pdfBytes
    if (_pdfBytes != null) {
      return pdf_widgets.PdfViewer(
        pdfBytes: _pdfBytes!,
        fileName: _book.title,
      );
    }

    // Fallback if no bytes available
    return Scaffold(
      appBar: AppBar(
        title: Text(_book.title),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text('PDF file not loaded'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => _loadBook(),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildAudioMode() {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Icon(Icons.volume_up),
            const SizedBox(width: 8),
            Text('Audio Mode - ${_book.title}'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () {
              context.read<TtsService>().stop();
              setState(() => _isAudioMode = false);
            },
          ),
        ],
      ),
      body: Column(
        children: [
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Center(
              child: Consumer<TtsService>(
                builder: (context, ttsService, child) {
                  return Column(
                    children: [
                      if (ttsService.isSpeaking)
                        AnimatedAudioWave()
                      else
                        Icon(
                          Icons.queue_music,
                          size: 64,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.skip_previous),
                            onPressed: () => _goToPreviousChapterAudio(),
                          ),
                          IconButton(
                            icon: Icon(
                              ttsService.isSpeaking ? Icons.pause : Icons.play_arrow,
                              size: 48,
                            ),
                            onPressed: () {
                              if (ttsService.isSpeaking) {
                                context.read<TtsService>().pause();
                              } else {
                                _startAudioReading();
                              }
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.skip_next),
                            onPressed: () => _goToNextChapterAudio(),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      VoiceSelector(),
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  void _startAudioReading() {
    if (_textContent != null && _textContent!.isNotEmpty) {
      context.read<TtsService>().speak(_textContent!);
    }
  }
  
  Future<void> _goToNextChapter() async {
    if (_epubController != null) {
      final chapters = _epubController?.flatChapters ?? [];
      if (chapters.isNotEmpty && _currentChapterIndex < chapters.length - 1) {
        _currentChapterIndex++;
        context.read<BookProvider>().saveReadingProgress(
          _book.id, _currentChapterIndex, 0,
        );
        setState(() {});
      }
    }
  }

  Future<void> _goToPreviousChapter() async {
    if (_epubController != null && _currentChapterIndex > 0) {
      _currentChapterIndex--;
      context.read<BookProvider>().saveReadingProgress(
        _book.id, _currentChapterIndex, 0,
      );
      setState(() {});
    }
  }

  void _goToNextChapterAudio() async {
    await _goToNextChapter();
    _startAudioReading();
  }

  void _goToPreviousChapterAudio() async {
    await _goToPreviousChapter();
    _startAudioReading();
  }

  /// Lấy tổng số chương của sách EPUB.
  int _getTotalChapters() {
    return _epubController?.tableOfContents.length ?? 1;
  }

  /// Hiển thị dialog tìm kiếm trong sách.
  void _showSearchDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SearchScreen(
        bookTitle: _book.title,
        content: _textContent ?? '',
      ),
    );
  }

  /// Chia sẻ thông tin sách.
  Future<void> _shareBook() async {
    await SharePlus.instance.share(
      'Tôi đang đọc: ${_book.title}\n\nTải app LibriAudio để đọc sách: https://example.com' as ShareParams,
    );
  }

  /// Xuất file sách (placeholder).
  void _exportBook() async {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Xuất file: ${_book.title}')),
    );
  }

  /// Hiển thị dialog cài đặt (tốc độ đọc, giọng đọc).
  void _showSettingsDialog() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Cài đặt',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Slider(
              value: context.watch<TtsService>().rate,
              min: 0.5,
              max: 2.0,
              divisions: 15,
              label: '${(context.watch<TtsService>().rate * 100).toInt()}%',
              onChanged: (value) => context.read<TtsService>().setRate(value),
            ),
            const SizedBox(height: 16),
            VoiceSelector(),
          ],
        ),
      ),
    );
  }
}

/// Animated audio wave component cho TTS mode.
///
/// Hiển thị hiệu ứng sóng âm thanh khi đang phát audio.
class AnimatedAudioWave extends StatelessWidget {
  const AnimatedAudioWave({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 500),
      height: 30,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(5, (index) => AnimatedPadding(
          key: Key('wave_$index'),
          duration: const Duration(milliseconds: 200),
          padding: EdgeInsets.symmetric(horizontal: 4),
          child: Container(
            width: 6,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
        )),
      ),
    );
  }
}
