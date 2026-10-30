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

/// Một đoạn văn bản trong hàng đợi TTS, kèm vị trí trong sách.
class _TtsSegment {
  final String text;

  /// Chương (EPUB, chỉ số trong flatChapters) hoặc trang (PDF).
  final int section;

  /// Chỉ số paragraph trong EPUB (PDF luôn là 0).
  final int paragraphIndex;

  const _TtsSegment(this.text, this.section, this.paragraphIndex);
}

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

class _BookReaderScreenState extends State<BookReaderScreen> {
  /// Gộp các paragraph ngắn liền nhau tới độ dài này để giảm khoảng lặng giữa các lần đọc.
  static const int MERGE_SEGMENT_LENGTH = 1000;

  late Book _book;
  late final TtsService _tts;
  int _currentChapterIndex = 0;
  int _currentParagraphIndex = 0;
  bool _isAudioMode = false;
  String? _textContent;
  bool _isLoading = true;
  String? _error;

  // Hàng đợi TTS của sách này (tạo khi bắt đầu nghe)
  List<_TtsSegment>? _segments;
  bool _isPreparingAudio = false;
  bool _audioStarted = false;

  // EPUB specific
  KatbookEpubController? _epubController;
  final GlobalKey<KatbookEpubReaderState> _readerKey = GlobalKey<KatbookEpubReaderState>();

  // PDF specific
  Uint8List? _pdfBytes;

  bool get _isPdf => _book.fileType.contains('pdf');

  @override
  void initState() {
    super.initState();
    _book = widget.book;
    _tts = context.read<TtsService>();
    _loadBook();
  }

  @override
  void dispose() {
    // Dừng đọc khi rời màn hình
    _tts.onChunkStarted = null;
    _tts.onQueueCompleted = null;
    if (_audioStarted) {
      _tts.stop();
    }
    _epubController?.dispose();
    super.dispose();
  }

  Future<void> _loadBook() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Load saved reading state
      final savedState = StorageService().getReadingState(_book.id);
      if (savedState != null) {
        _currentChapterIndex = savedState.chapterIndex;
        _currentParagraphIndex = savedState.position;
      }

      if (_book.fileType.contains('epub')) {
        await _loadEpub();
      } else if (_isPdf) {
        await _loadPdf();
      } else {
        throw Exception('Định dạng file không được hỗ trợ: ${_book.fileType}');
      }

      if (!mounted) return;
      setState(() => _isLoading = false);

      // Auto-play from last position
      if (widget.autoPlay) {
        _enterAudioMode();
      }
    } catch (e, stackTrace) {
      print('BookReader Error: $e\n$stackTrace');
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = 'Lỗi khi đọc file: ${e.toString()}';
      });
    }
  }

  /// Đọc bytes của file sách: web lấy từ Hive, mobile/desktop đọc từ đường dẫn.
  Future<Uint8List> _readBookBytes() async {
    final storage = StorageService();
    if (kIsWeb) {
      // Bytes lưu theo id sách; bản cũ có thể lưu theo tên file
      final bytes = storage.getBookFileBytes(_book.id) ??
          storage.getBookFileBytes(_book.filePath ?? '');
      if (bytes == null) {
        throw Exception('Không tìm thấy dữ liệu file');
      }
      return Uint8List.fromList(bytes);
    }

    final path = _book.filePath;
    if (path == null || path.isEmpty) {
      throw Exception('Không tìm thấy file');
    }
    final file = File(path);
    if (!await file.exists()) {
      throw Exception('File không tồn tại: $path');
    }
    return file.readAsBytes();
  }

  Future<void> _loadEpub() async {
    final bytes = await _readBookBytes();

    final controller = KatbookEpubController();
    final success = await controller.openBook(bytes);
    if (!success) {
      controller.dispose();
      throw Exception('Không thể đọc file EPUB');
    }
    _epubController = controller;

    final chapterCount = controller.flatChapters.length;
    if (_currentChapterIndex >= chapterCount) {
      _currentChapterIndex = 0;
      _currentParagraphIndex = 0;
    }
    if (_currentParagraphIndex >= controller.totalParagraphs) {
      _currentParagraphIndex = 0;
    }
    // Vị trí cũ chỉ lưu chương: mở tại đầu chương đó
    if (_currentParagraphIndex == 0 && _currentChapterIndex > 0) {
      _currentParagraphIndex = controller.flatChapters[_currentChapterIndex].startIndex;
    }

    // Text đầy đủ cho tìm kiếm, mỗi paragraph một dòng
    _textContent = controller.paragraphs
        .map((p) => p.text.trim())
        .where((t) => t.isNotEmpty)
        .join('\n');
  }

  Future<void> _loadPdf() async {
    // Text cho TTS được trích khi bắt đầu nghe, để mở PDF nhanh hơn
    _pdfBytes = await _readBookBytes();
  }

  /// Tạo hàng đợi TTS: EPUB theo paragraph, PDF theo trang.
  Future<List<_TtsSegment>> _buildSegments() async {
    final segments = <_TtsSegment>[];

    if (_epubController != null) {
      final paragraphs = _epubController!.paragraphs;
      final buffer = StringBuffer();
      var bufferSection = 0;
      var bufferParagraph = 0;

      void flush() {
        if (buffer.isEmpty) return;
        for (final chunk in TtsService.splitText(buffer.toString())) {
          segments.add(_TtsSegment(chunk, bufferSection, bufferParagraph));
        }
        buffer.clear();
      }

      for (int i = 0; i < paragraphs.length; i++) {
        final text = paragraphs[i].text.trim();
        if (text.isEmpty) continue;
        final section = paragraphs[i].chapterIndex;
        if (buffer.isNotEmpty &&
            (section != bufferSection || buffer.length + text.length > MERGE_SEGMENT_LENGTH)) {
          flush();
        }
        if (buffer.isEmpty) {
          bufferSection = section;
          bufferParagraph = i;
        }
        buffer.writeln(text);
      }
      flush();
    } else if (_pdfBytes != null && _pdfBytes!.isNotEmpty) {
      final document = await PdfDocument.openData(Uint8List.fromList(_pdfBytes!));
      try {
        for (int i = 0; i < document.pages.length; i++) {
          try {
            final text = await document.pages[i].loadText();
            final fullText = text?.fullText.trim() ?? '';
            for (final chunk in TtsService.splitText(fullText)) {
              segments.add(_TtsSegment(chunk, i, 0));
            }
          } catch (e) {
            print('Error extracting text from PDF page $i: $e');
          }
        }
      } finally {
        await document.dispose();
      }
    }

    return segments;
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
        appBar: AppBar(title: const Text('Lỗi')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => _loadBook(),
                child: const Text('Thử lại'),
              ),
            ],
          ),
        ),
      );
    }

    if (_isAudioMode) {
      return _buildAudioMode();
    }

    if (_isPdf) {
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
            onPressed: _enterAudioMode,
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
        : const Center(child: Text('Đang tải EPUB...')),
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
    final controller = _epubController!;
    return KatbookEpubReader(
      key: _readerKey,
      controller: controller,
      initialTheme: ReaderTheme.light,
      initialFontSize: 16.0,
      showAppBar: false,
      initialPosition: _currentParagraphIndex > 0
          ? ReadingPosition(
              chapterIndex: _currentChapterIndex,
              paragraphIndex: _currentParagraphIndex,
              totalParagraphs: controller.totalParagraphs,
            )
          : null,
      onChapterChanged: (chapter) {
        final index = controller.flatChapters.indexOf(chapter);
        if (index != -1 && index != _currentChapterIndex) {
          setState(() => _currentChapterIndex = index);
        }
      },
      onPositionChanged: (position) {
        _currentParagraphIndex = position.paragraphIndex;
        _saveProgress();
      },
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      contentWidthPercent: 0.85,
    );
  }

  /// PDF reader, dùng pdfrx trên mọi nền tảng (kể cả web).
  Widget _buildPdfReader() {
    if (_pdfBytes != null) {
      return pdf_widgets.PdfViewer(
        pdfBytes: _pdfBytes!,
        fileName: _book.title,
        onListen: _enterAudioMode,
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
            const Icon(Icons.error_outline, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text('Chưa tải được file PDF'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => _loadBook(),
              child: const Text('Thử lại'),
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
            Expanded(
              child: Text(
                _book.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: _exitAudioMode,
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
                  final isSpeaking = _audioStarted && ttsService.isSpeaking;
                  return Column(
                    children: [
                      if (_isPreparingAudio)
                        const CircularProgressIndicator()
                      else if (isSpeaking)
                        const AnimatedAudioWave()
                      else
                        Icon(
                          Icons.queue_music,
                          size: 64,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      const SizedBox(height: 16),
                      Text(
                        _currentSectionLabel(),
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      if (_segments != null && _segments!.isNotEmpty && _audioStarted)
                        Text(
                          'Đoạn ${ttsService.currentIndex + 1}/${_segments!.length}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.skip_previous),
                            onPressed: _isPreparingAudio ? null : () => _jumpSectionAudio(-1),
                          ),
                          IconButton(
                            icon: Icon(
                              isSpeaking ? Icons.pause : Icons.play_arrow,
                              size: 48,
                            ),
                            onPressed: _isPreparingAudio
                                ? null
                                : () {
                                    if (isSpeaking) {
                                      ttsService.pause();
                                    } else if (_audioStarted && ttsService.hasQueue) {
                                      ttsService.resume();
                                    } else {
                                      _startAudioReading();
                                    }
                                  },
                          ),
                          IconButton(
                            icon: const Icon(Icons.skip_next),
                            onPressed: _isPreparingAudio ? null : () => _jumpSectionAudio(1),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const VoiceSelector(),
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

  String _currentSectionLabel() {
    if (_isPdf) {
      return 'Trang ${_currentChapterIndex + 1}';
    }
    final chapters = _epubController?.flatChapters ?? [];
    if (_currentChapterIndex < chapters.length) {
      final title = chapters[_currentChapterIndex].title.trim();
      if (title.isNotEmpty) return title;
    }
    return 'Chương ${_currentChapterIndex + 1}';
  }

  void _enterAudioMode() {
    setState(() => _isAudioMode = true);
    _startAudioReading();
  }

  void _exitAudioMode() {
    _tts.stop();
    _audioStarted = false;
    setState(() => _isAudioMode = false);
  }

  /// Bắt đầu đọc từ vị trí hiện tại (chương/trang và paragraph đang xem).
  Future<void> _startAudioReading({int? startSegment}) async {
    if (_segments == null) {
      setState(() => _isPreparingAudio = true);
      try {
        _segments = await _buildSegments();
      } catch (e) {
        print('Error preparing audio: $e');
        _segments = [];
      }
      if (!mounted) return;
      setState(() => _isPreparingAudio = false);
    }

    final segments = _segments!;
    if (segments.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Không có nội dung văn bản để đọc')),
      );
      return;
    }

    final start = startSegment ?? _segmentIndexForPosition(_currentChapterIndex, _currentParagraphIndex);

    _tts.onChunkStarted = _onSegmentStarted;
    _tts.onQueueCompleted = null;
    _audioStarted = true;
    await _tts.speakQueue(segments.map((s) => s.text).toList(), startIndex: start);
  }

  int _segmentIndexForPosition(int section, int paragraphIndex) {
    final segments = _segments ?? [];
    for (int i = 0; i < segments.length; i++) {
      final s = segments[i];
      if (s.section > section || (s.section == section && s.paragraphIndex >= paragraphIndex)) {
        // Lùi về đoạn chứa paragraph đang xem nếu có
        if (i > 0 && segments[i - 1].section == section && s.paragraphIndex > paragraphIndex) {
          return i - 1;
        }
        return i;
      }
    }
    return 0;
  }

  void _onSegmentStarted(int index) {
    final segments = _segments;
    if (!mounted || segments == null || index >= segments.length) return;
    final segment = segments[index];
    setState(() {
      _currentChapterIndex = segment.section;
      _currentParagraphIndex = segment.paragraphIndex;
    });
    _saveProgress();
  }

  /// Nhảy sang chương/trang trước (-1) hoặc sau (+1) trong chế độ nghe.
  Future<void> _jumpSectionAudio(int direction) async {
    if (_segments == null) {
      await _startAudioReading();
      if (_segments == null || _segments!.isEmpty) return;
    }
    final segments = _segments!;
    final sections = <int>[];
    for (final s in segments) {
      if (sections.isEmpty || sections.last != s.section) sections.add(s.section);
    }

    var pos = sections.indexWhere((s) => s >= _currentChapterIndex);
    if (pos == -1) pos = sections.length - 1;
    final target = (pos + direction).clamp(0, sections.length - 1);
    final index = segments.indexWhere((s) => s.section == sections[target]);
    if (index == -1) return;

    if (_audioStarted && _tts.hasQueue) {
      await _tts.jumpTo(index);
    } else {
      await _startAudioReading(startSegment: index);
    }
  }

  void _saveProgress() {
    context.read<BookProvider>().saveReadingProgress(
      _book.id, _currentChapterIndex, _currentParagraphIndex,
    );
  }

  void _goToChapter(int index) {
    final chapters = _epubController?.flatChapters ?? [];
    if (index < 0 || index >= chapters.length) return;
    final chapter = chapters[index];
    _readerKey.currentState?.jumpToChapter(chapter);
    setState(() {
      _currentChapterIndex = index;
      _currentParagraphIndex = chapter.startIndex;
    });
    _saveProgress();
  }

  void _goToNextChapter() => _goToChapter(_currentChapterIndex + 1);

  void _goToPreviousChapter() => _goToChapter(_currentChapterIndex - 1);

  /// Lấy tổng số chương của sách EPUB.
  int _getTotalChapters() {
    return _epubController?.flatChapters.length ?? 1;
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
      ShareParams(
        text: 'Tôi đang đọc: ${_book.title}\n\nTải app LibriAudio để đọc sách: https://example.com',
      ),
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
            const VoiceSelector(),
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
          padding: const EdgeInsets.symmetric(horizontal: 4),
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
