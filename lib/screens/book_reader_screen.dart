import 'dart:convert';
import 'dart:html' as html;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:provider/provider.dart';
import 'package:libri_audio/models/book_model.dart';
import 'package:share_plus/share_plus.dart';
import 'package:libri_audio/services/tts_service.dart';
import 'package:libri_audio/services/storage_service.dart';
import 'package:libri_audio/widgets/voice_selector.dart';
import 'package:libri_audio/screens/search_screen.dart';
import 'package:libri_audio/providers/book_provider.dart' show BookProvider;

class BookReaderScreen extends StatefulWidget {
  final Book book;
  final bool autoPlay;
  
  const BookReaderScreen({super.key, required this.book, this.autoPlay = false});

  @override
  State<BookReaderScreen> createState() => _BookReaderScreenState();
}

class _BookReaderScreenState extends State<BookReaderScreen> {
  late Book _book;
  int _currentChapterIndex = 0;
  int _currentPosition = 0;
  bool _isAudioMode = false;
  String? _textContent;
  bool _isLoading = true;
  String? _error;
  final TextEditingController _searchController = TextEditingController();
  
  @override
  void initState() {
    super.initState();
    _book = widget.book;
    _loadBook();
    
    // Register to listen for highlights (placeholder - update UI on highlight change)
    // TODO: Implement highlight listener
    if (mounted) {
      setState(() {});
    }
    
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
        _currentPosition = savedState.position;
      }
      
      if (_book.fileType == 'epub') {
        await _loadEpub();
      } else if (_book.fileType == 'pdf') {
        _isAudioMode = false; // PDF không hỗ trợ TTS tốt
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
      if (_book.filePath == null) return;
      // Use basic EPUB parsing for now - simplified
      _textContent = 'EPUB content loading...'; // Placeholder
      return;
    } catch (e) {
      print('Error loading EPUB: $e');
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
    
    if (_book.fileType == 'pdf') {
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
      body: _textContent != null
        ? SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: SelectableText(
              _textContent!,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          )
        : const Center(child: Text('No content available')),
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

  // Web-specific PDF viewer using iframe
  Widget _buildPdfReaderWeb(String dataUri) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_book.title),
        actions: [
          IconButton(
            icon: const Icon(Icons.volume_up),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('PDF text-to-speech not supported')),
              );
            },
          ),
        ],
      ),
      body: Builder(
        builder: (context) {
          // Use dart:html to create iframe on web
          final iframe = html.IFrameElement()
            ..src = dataUri
            ..style.border = 'none'
            ..style.width = '100%'
            ..style.height = '100%';

          // Add to body and return a placeholder widget
          html.document.body?.append(iframe);

          // Return a widget that keeps the iframe alive
          return Container();
        },
      ),
    );
  }

  Widget _buildPdfReader() {
    if (kIsWeb) {
      // On web, use an iframe to display PDF
      // The filePath on web is just a filename, we need to get the actual bytes
      final storage = StorageService();
      final bytes = storage.getBookFileBytes(_book.id);

      if (bytes != null) {
        // Convert bytes to base64 data URI
        final base64Pdf = base64Encode(bytes);
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

    return Scaffold(
      appBar: AppBar(
        title: Text(_book.title),
        actions: [
          IconButton(
            icon: const Icon(Icons.volume_up),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('PDF text-to-speech not supported')),
              );
            },
          ),
        ],
      ),
      body: PDFView(
        filePath: _book.filePath!,
        enableSwipe: true,
        swipeHorizontal: true,
        autoSpacing: true,
        pageFling: true,
        pageSnap: true,
        defaultPage: _currentChapterIndex,
        fitPolicy: FitPolicy.BOTH,
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
  
  void _goToNextChapter() {
    final total = _getTotalChapters();
    if (_currentChapterIndex < total - 1) {
      _currentChapterIndex++;
      _loadEpub();
      context.read<BookProvider>().saveReadingProgress(
        _book.id, _currentChapterIndex, _currentPosition,
      );
    }
  }
  
  void _goToPreviousChapter() {
    if (_currentChapterIndex > 0) {
      _currentChapterIndex--;
      _loadEpub();
      context.read<BookProvider>().saveReadingProgress(
        _book.id, _currentChapterIndex, _currentPosition,
      );
    }
  }
  
  void _goToNextChapterAudio() {
    _goToNextChapter();
    _startAudioReading();
  }
  
  void _goToPreviousChapterAudio() {
    _goToPreviousChapter();
    _startAudioReading();
  }
  
  int _getTotalChapters() {
    // This would need to be implemented properly with EPUB parsing
    return 1; // Placeholder
  }
  
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
  
  Future<void> _shareBook() async {
    // Share book title and file info
    await SharePlus.instance.share(
      'Tôi đang đọc: ${_book.title}\n\nTải app LibriAudio để đọc sách: https://example.com' as ShareParams,
    );
  }
  
  void _exportBook() async {
    // TODO: Implement file save
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Xuất file: ${_book.title}')),
    );
  }
  
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
