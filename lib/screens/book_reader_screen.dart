import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show compute, kIsWeb, Uint8List;
import 'package:path_provider/path_provider.dart';
import 'package:pdfrx/pdfrx.dart' as pdfrx;
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:libri_audio/models/book_model.dart';
import 'package:libri_audio/models/reader_content.dart';
import 'package:libri_audio/providers/book_provider.dart' show BookProvider;
import 'package:libri_audio/providers/reader_settings_provider.dart';
import 'package:libri_audio/screens/search_screen.dart';
import 'package:libri_audio/services/epub_parser.dart';
import 'package:libri_audio/services/mobi_parser.dart';
import 'package:libri_audio/services/pdf_text_extractor.dart';
import 'package:libri_audio/services/reader_tts_segments.dart';
import 'package:libri_audio/services/storage_service.dart';
import 'package:libri_audio/services/tts_service.dart';
import 'package:libri_audio/widgets/reader/reader_settings_sheet.dart';
import 'package:libri_audio/widgets/reader/reader_view.dart';
import 'package:libri_audio/widgets/voice_selector.dart';

/// Màn hình đọc và nghe sách.
///
/// EPUB và MOBI/AZW được tách thành [ReaderDocument] rồi hiển thị bằng trình đọc
/// chung [ReaderView] (cùng tùy chọn hiển thị, cùng cách tô sáng khi nghe).
/// PDF mặc định xem nguyên trang bằng pdfrx, có nút chuyển sang "xem dạng chữ"
/// dùng cùng trình đọc chung. Nghe bằng TTS chạy ngay trong màn hình đọc, với
/// thanh điều khiển ở dưới.
class BookReaderScreen extends StatefulWidget {
  final Book book;
  final bool autoPlay;

  const BookReaderScreen({super.key, required this.book, this.autoPlay = false});

  @override
  State<BookReaderScreen> createState() => _BookReaderScreenState();
}

class _BookReaderScreenState extends State<BookReaderScreen> {
  late Book _book;
  late final TtsService _tts;
  final ReaderController _reader = ReaderController();
  final pdfrx.PdfViewerController _pdfController = pdfrx.PdfViewerController();

  bool _isLoading = true;
  String? _error;

  /// Nội dung dạng chữ (EPUB/MOBI lúc mở sách; PDF khi xem dạng chữ hoặc nghe).
  ReaderDocument? _document;
  Uint8List? _pdfBytes;
  bool _pdfTextMode = false;
  bool _isExtractingPdf = false;

  /// Vị trí đọc: chương (PDF: trang, từ 0) và khối trong chương.
  int _chapter = 0;
  int _block = 0;

  // Nghe
  bool _listening = false;
  bool _audioStarted = false;
  bool _isPreparingAudio = false;
  List<ReaderTtsSegment>? _segments;
  ReaderHighlight? _highlight;

  bool get _isPdf => _book.fileType.contains('pdf');
  bool get _isMobi => _book.fileType.contains('mobipocket');
  bool get _showsText => _document != null && (!_isPdf || _pdfTextMode);

  @override
  void initState() {
    super.initState();
    _book = widget.book;
    _tts = context.read<TtsService>();
    _loadBook();
  }

  @override
  void dispose() {
    _tts.onChunkStarted = null;
    _tts.onQueueCompleted = null;
    _tts.onSkipNext = null;
    _tts.onSkipPrevious = null;
    _tts.onEngineError = null;
    if (_audioStarted) _tts.stop();
    super.dispose();
  }

  Future<void> _loadBook() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final savedState = StorageService().getReadingState(_book.id);
      if (savedState != null) {
        _chapter = savedState.chapterIndex;
        _block = savedState.position;
      }

      final bytes = await _readBookBytes();
      if (_book.fileType.contains('epub')) {
        // Giải nén và tách HTML ở isolate khác để không đứng giao diện
        _document = await compute(EpubParser.parse, bytes);
      } else if (_isMobi) {
        final mobi = await compute(MobiParser.parse, bytes);
        _document = mobi.toReaderDocument();
      } else if (_isPdf) {
        // Chữ của PDF chỉ trích khi xem dạng chữ hoặc nghe, để mở nhanh hơn
        _pdfBytes = bytes;
      } else {
        throw Exception('Định dạng file không được hỗ trợ: ${_book.fileType}');
      }
      _clampPosition();
      _updateBookInfo();

      if (!mounted) return;
      setState(() => _isLoading = false);

      if (widget.autoPlay) _startListening();
    } catch (e, stackTrace) {
      print('BookReader Error: $e\n$stackTrace');
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = e is EpubFormatException || e is MobiFormatException
            ? e.toString()
            : 'Lỗi khi đọc file: ${e.toString()}';
      });
    }
  }

  /// Sách nhập từ file mang tên file và tác giả "Unknown": thay bằng tên sách
  /// và tác giả trong metadata của EPUB/MOBI.
  void _updateBookInfo() {
    final doc = _document;
    if (doc == null || _isPdf) return;
    final looksLikeFileName = RegExp(r'\.(epub|mobi|azw3?|prc)$', caseSensitive: false).hasMatch(_book.title);
    final title = doc.title.trim();
    final author = doc.author?.trim();
    final newTitle = looksLikeFileName && title.isNotEmpty && title != 'Không có tiêu đề' ? title : null;
    final newAuthor = (_book.author == null || _book.author == 'Unknown') && author != null && author.isNotEmpty ? author : null;
    if (newTitle == null && newAuthor == null) return;
    _book = _book.copyWith(title: newTitle, author: newAuthor);
    context.read<BookProvider>().updateBook(_book);
  }

  /// Vị trí đã lưu có thể vượt quá nội dung (sách đổi, hoặc bản cũ lưu theo cách khác).
  void _clampPosition() {
    final doc = _document;
    if (doc == null) {
      if (_chapter < 0) _chapter = 0;
      return;
    }
    if (_chapter < 0 || _chapter >= doc.chapters.length) {
      _chapter = 0;
      _block = 0;
    }
    if (_block < 0 || _block >= doc.chapters[_chapter].blocks.length) _block = 0;
  }

  /// Bytes của file sách: web lấy từ Hive, mobile/desktop đọc từ đường dẫn.
  Future<Uint8List> _readBookBytes() async {
    final storage = StorageService();
    if (kIsWeb) {
      // Bytes lưu theo id sách; bản cũ có thể lưu theo tên file
      final bytes = storage.getBookFileBytes(_book.id) ?? storage.getBookFileBytes(_book.filePath ?? '');
      if (bytes == null) throw Exception('Không tìm thấy dữ liệu file');
      return Uint8List.fromList(bytes);
    }
    final path = _book.filePath;
    if (path == null || path.isEmpty) throw Exception('Không tìm thấy file');
    final file = File(path);
    if (!await file.exists()) throw Exception('File không tồn tại: $path');
    return file.readAsBytes();
  }

  /// Trích chữ PDF (một lần) cho chế độ xem dạng chữ và TTS.
  Future<ReaderDocument?> _ensurePdfText() async {
    if (_document != null || _pdfBytes == null) return _document;
    setState(() => _isExtractingPdf = true);
    try {
      _document = await PdfTextExtractor.extract(_pdfBytes!, title: _book.title);
      _clampPosition();
    } catch (e) {
      print('Lỗi trích chữ PDF: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Không lấy được chữ từ file PDF này')),
        );
      }
    }
    if (mounted) setState(() => _isExtractingPdf = false);
    return _document;
  }

  Future<void> _togglePdfTextMode() async {
    if (!_pdfTextMode) {
      final doc = await _ensurePdfText();
      if (doc == null || !mounted) return;
      if (doc.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('PDF này không có lớp chữ (có thể là ảnh scan)')),
        );
        return;
      }
      setState(() {
        _pdfTextMode = true;
        _block = 0;
      });
    } else {
      setState(() => _pdfTextMode = false);
    }
  }

  void _onPositionChanged(int chapter, int block) {
    final chapterChanged = chapter != _chapter;
    _chapter = chapter;
    _block = block;
    if (chapterChanged && mounted) setState(() {});
    _saveProgress();
  }

  void _saveProgress() {
    context.read<BookProvider>().saveReadingProgress(_book.id, _chapter, _block);
  }

  // ---------------- Nghe ----------------

  Future<void> _startListening({int? startSegment}) async {
    setState(() => _listening = true);

    if (_segments == null) {
      setState(() => _isPreparingAudio = true);
      final doc = _isPdf ? await _ensurePdfText() : _document;
      _segments = doc == null ? [] : buildTtsSegments(doc);
      if (!mounted) return;
      setState(() => _isPreparingAudio = false);
    }

    final segments = _segments!;
    if (segments.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Không có nội dung văn bản để đọc')),
      );
      setState(() => _listening = false);
      return;
    }

    final start = startSegment ?? segmentIndexFor(segments, _chapter, _block);
    _tts.onChunkStarted = _onSegmentStarted;
    _tts.onQueueCompleted = null;
    _tts.onSkipNext = () => _jumpChapterAudio(1);
    _tts.onSkipPrevious = () => _jumpChapterAudio(-1);
    _tts.onEngineError = (message) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    };
    _audioStarted = true;
    await _tts.speakQueue(segments.map((s) => s.text).toList(), startIndex: start);
  }

  void _stopListening() {
    _tts.stop();
    setState(() {
      _audioStarted = false;
      _listening = false;
      _highlight = null;
    });
  }

  void _onSegmentStarted(int index) {
    final segments = _segments;
    if (!mounted || segments == null || index >= segments.length) return;
    final s = segments[index];
    final pageChanged = s.chapter != _chapter;
    setState(() {
      _chapter = s.chapter;
      _block = s.startBlock;
      _highlight = ReaderHighlight(s.chapter, s.startBlock, s.endBlock);
    });
    // PDF xem nguyên trang: lật tới trang đang đọc
    if (_isPdf && !_pdfTextMode && pageChanged && _pdfController.isReady) {
      _pdfController.goToPage(pageNumber: s.chapter + 1);
    }
    _tts.setNowPlaying(_book.title, subtitle: _chapterTitle());
    _saveProgress();
  }

  /// Nhảy sang chương/trang trước (-1) hoặc sau (+1) khi đang nghe.
  Future<void> _jumpChapterAudio(int direction) async {
    if (_segments == null) {
      await _startListening();
      if (_segments == null || _segments!.isEmpty) return;
    }
    final segments = _segments!;
    final chapters = <int>[];
    for (final s in segments) {
      if (chapters.isEmpty || chapters.last != s.chapter) chapters.add(s.chapter);
    }
    var pos = chapters.indexWhere((c) => c >= _chapter);
    if (pos == -1) pos = chapters.length - 1;
    final target = (pos + direction).clamp(0, chapters.length - 1);
    final index = segments.indexWhere((s) => s.chapter == chapters[target]);
    if (index == -1) return;

    if (_audioStarted && _tts.hasQueue) {
      await _tts.jumpTo(index);
    } else {
      await _startListening(startSegment: index);
    }
  }

  String _chapterTitle() {
    final chapters = _document?.chapters;
    if (chapters != null && _chapter < chapters.length) return chapters[_chapter].title;
    return _isPdf ? 'Trang ${_chapter + 1}' : 'Chương ${_chapter + 1}';
  }

  // ---------------- Giao diện ----------------

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: Text(_book.title, maxLines: 1, overflow: TextOverflow.ellipsis)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Lỗi')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 64, color: Colors.red),
                const SizedBox(height: 16),
                Text(_error!, textAlign: TextAlign.center),
                const SizedBox(height: 16),
                ElevatedButton(onPressed: _loadBook, child: const Text('Thử lại')),
              ],
            ),
          ),
        ),
      );
    }

    final settings = context.watch<ReaderSettingsProvider>().settings;
    final multiChapter = (_document?.chapters.length ?? 0) > 1;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_book.title, maxLines: 1, overflow: TextOverflow.ellipsis),
            if (_showsText || _listening)
              Text(
                _chapterTitle(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall,
              ),
          ],
        ),
        actions: [
          if (_isPdf)
            IconButton(
              tooltip: _pdfTextMode ? 'Xem nguyên trang' : 'Xem dạng chữ',
              icon: _isExtractingPdf
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : Icon(_pdfTextMode ? Icons.picture_as_pdf : Icons.article_outlined),
              onPressed: _isExtractingPdf ? null : _togglePdfTextMode,
            ),
          if (_showsText)
            IconButton(
              tooltip: 'Hiển thị',
              icon: const Icon(Icons.text_fields),
              onPressed: () => ReaderSettingsSheet.show(context),
            ),
          if (!_listening)
            IconButton(
              tooltip: 'Nghe',
              icon: const Icon(Icons.headphones),
              onPressed: _startListening,
            ),
          PopupMenuButton<String>(
            onSelected: _onMenuSelected,
            itemBuilder: (context) => [
              if (multiChapter && _showsText) _menuItem('toc', Icons.list, 'Mục lục'),
              if (_document != null) _menuItem('search', Icons.search, 'Tìm trong sách'),
              _menuItem('share', Icons.share, 'Chia sẻ'),
              _menuItem('voice', Icons.record_voice_over, 'Giọng và tốc độ đọc'),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(child: _buildContent(settings)),
          if (_listening) _buildPlayerBar(),
        ],
      ),
    );
  }

  PopupMenuEntry<String> _menuItem(String value, IconData icon, String title) => PopupMenuItem(
        value: value,
        child: ListTile(leading: Icon(icon), title: Text(title), contentPadding: EdgeInsets.zero),
      );

  void _onMenuSelected(String value) {
    switch (value) {
      case 'toc':
        _showToc();
      case 'search':
        _showSearch();
      case 'share':
        _share();
      case 'voice':
        _showVoiceSettings();
    }
  }

  Widget _buildContent(ReaderSettings settings) {
    if (_showsText) {
      return ReaderView(
        // Đổi giữa trang PDF và dạng chữ thì dựng lại từ vị trí hiện tại
        key: ValueKey('reader_${_pdfTextMode}_${_document.hashCode}'),
        document: _document!,
        settings: settings,
        initialChapter: _chapter,
        initialBlock: _block,
        highlight: _highlight,
        controller: _reader,
        onPositionChanged: _onPositionChanged,
      );
    }
    if (_pdfBytes != null) {
      return pdfrx.PdfViewer.data(
        _pdfBytes!,
        sourceName: 'pdf_${_book.id}',
        controller: _pdfController,
        initialPageNumber: _chapter + 1,
        params: pdfrx.PdfViewerParams(
          onPageChanged: (page) {
            if (page == null || page - 1 == _chapter) return;
            setState(() {
              _chapter = page - 1;
              _block = 0;
            });
            _saveProgress();
          },
        ),
      );
    }
    return const Center(child: Text('Sách không có nội dung'));
  }

  Widget _buildPlayerBar() {
    final theme = Theme.of(context);
    return Material(
      elevation: 8,
      color: theme.colorScheme.surfaceContainer,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
          child: Consumer<TtsService>(
            builder: (context, tts, _) {
              final isSpeaking = _audioStarted && tts.isSpeaking;
              final total = _segments?.length ?? 0;
              return Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_chapterTitle(), maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.titleSmall),
                        Text(
                          _isPreparingAudio
                              ? 'Đang chuẩn bị...'
                              : total > 0 && _audioStarted
                                  ? 'Đoạn ${tts.currentIndex + 1}/$total'
                                  : 'Sẵn sàng',
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Chương trước',
                    icon: const Icon(Icons.skip_previous),
                    onPressed: _isPreparingAudio ? null : () => _jumpChapterAudio(-1),
                  ),
                  _isPreparingAudio
                      ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2)),
                        )
                      : IconButton.filled(
                          tooltip: isSpeaking ? 'Tạm dừng' : 'Đọc',
                          icon: Icon(isSpeaking ? Icons.pause : Icons.play_arrow),
                          onPressed: () {
                            if (isSpeaking) {
                              tts.pause();
                            } else if (_audioStarted && tts.hasQueue) {
                              tts.resume();
                            } else {
                              _startListening();
                            }
                          },
                        ),
                  IconButton(
                    tooltip: 'Chương sau',
                    icon: const Icon(Icons.skip_next),
                    onPressed: _isPreparingAudio ? null : () => _jumpChapterAudio(1),
                  ),
                  IconButton(
                    tooltip: 'Giọng đọc',
                    icon: const Icon(Icons.tune),
                    onPressed: _showVoiceSettings,
                  ),
                  IconButton(
                    tooltip: 'Tắt nghe',
                    icon: const Icon(Icons.close),
                    onPressed: _stopListening,
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  void _showToc() {
    final chapters = _document!.chapters;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        builder: (context, scroll) => ListView.builder(
          controller: scroll,
          itemCount: chapters.length,
          itemBuilder: (context, i) => ListTile(
            selected: i == _chapter,
            title: Text(chapters[i].title, maxLines: 2, overflow: TextOverflow.ellipsis),
            onTap: () {
              Navigator.pop(context);
              _reader.jumpTo(i);
            },
          ),
        ),
      ),
    );
  }

  void _showSearch() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => SearchScreen(bookTitle: _book.title, content: _document?.plainText ?? ''),
    );
  }

  Future<void> _share() async {
    try {
      // PDF trên mobile: chia sẻ cả file
      if (_isPdf && !kIsWeb && _pdfBytes != null) {
        final dir = await getTemporaryDirectory();
        final file = File('${dir.path}/${_book.title}.pdf');
        await file.writeAsBytes(_pdfBytes!);
        await SharePlus.instance.share(
          ShareParams(text: 'Tôi đang đọc: ${_book.title}', files: [XFile(file.path)]),
        );
        return;
      }
      await SharePlus.instance.share(ShareParams(text: 'Tôi đang đọc: ${_book.title}'));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi khi chia sẻ: $e')));
    }
  }

  /// Tốc độ và giọng đọc.
  void _showVoiceSettings() {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Tốc độ đọc', style: Theme.of(context).textTheme.titleMedium),
            Slider(
              value: context.watch<TtsService>().rate,
              min: 0.5,
              max: 2.0,
              divisions: 15,
              label: '${(context.watch<TtsService>().rate * 100).toInt()}%',
              onChanged: (value) => context.read<TtsService>().setRate(value),
            ),
            const SizedBox(height: 8),
            const VoiceSelector(),
          ],
        ),
      ),
    );
  }
}
