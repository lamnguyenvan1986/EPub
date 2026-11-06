import 'package:flutter/material.dart';
import 'package:libri_audio/models/reader_content.dart';
import 'package:libri_audio/providers/reader_settings_provider.dart';
import 'package:libri_audio/widgets/reader/reader_paginator.dart';

/// Khoảng khối đang được đọc bằng TTS: khối `start..end` (tính cả hai đầu) của chương [chapter].
@immutable
class ReaderHighlight {
  final int chapter;
  final int start;
  final int end;

  const ReaderHighlight(this.chapter, this.start, this.end);

  bool contains(int chapter, int block) => chapter == this.chapter && block >= start && block <= end;

  @override
  bool operator ==(Object other) =>
      other is ReaderHighlight && other.chapter == chapter && other.start == start && other.end == end;

  @override
  int get hashCode => Object.hash(chapter, start, end);
}

/// Điều khiển [ReaderView] từ bên ngoài (mục lục, tìm kiếm).
class ReaderController {
  _ReaderViewState? _state;

  void jumpTo(int chapter, {int block = 0}) => _state?._jumpTo(chapter, block);
}

/// Trình đọc chung cho mọi sách dạng chữ: EPUB, MOBI/AZW và PDF dạng chữ.
///
/// Hiển thị một chương mỗi lần, cuộn dọc hoặc chia trang theo [settings].
/// Khối đang được TTS đọc ([highlight]) được tô nền và tự cuộn/lật tới.
class ReaderView extends StatefulWidget {
  final ReaderDocument document;
  final ReaderSettings settings;
  final int initialChapter;
  final int initialBlock;
  final ReaderHighlight? highlight;
  final ReaderController? controller;

  /// Vị trí đọc thay đổi (chương, khối đầu tiên đang hiện).
  final void Function(int chapter, int block)? onPositionChanged;

  const ReaderView({
    super.key,
    required this.document,
    required this.settings,
    this.initialChapter = 0,
    this.initialBlock = 0,
    this.highlight,
    this.controller,
    this.onPositionChanged,
  });

  @override
  State<ReaderView> createState() => _ReaderViewState();
}

class _ReaderViewState extends State<ReaderView> {
  late int _chapter;

  /// Khối cần hiện khi dựng chương (vị trí ban đầu, hoặc đích nhảy tới).
  int _targetBlock = 0;

  // Chế độ cuộn
  ScrollController _scroll = ScrollController(keepScrollOffset: false);
  final Map<int, GlobalKey> _blockKeys = {};

  // Chế độ chia trang
  PageController? _pageController;
  List<ReaderPage> _pages = const [];
  Object? _pagesKey;

  /// Tăng mỗi lần chia trang lại: PageView mới nhận đúng trang đầu của controller mới
  /// (PageView cũ giữ nguyên offset pixel khi đổi controller).
  int _pagination = 0;
  int _page = 0;
  bool _hasPrevChapter = false;

  List<ReaderChapter> get _chapters => widget.document.chapters;
  bool get _paginate => widget.settings.layout == ReaderLayout.paginate;

  @override
  void initState() {
    super.initState();
    widget.controller?._state = this;
    _chapter = widget.initialChapter.clamp(0, _chapters.length - 1);
    _targetBlock = widget.initialBlock;
    _scheduleScrollToTarget();
  }

  @override
  void didUpdateWidget(ReaderView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller?._state = null;
      widget.controller?._state = this;
    }
    if (oldWidget.settings.layout != widget.settings.layout) {
      // Đổi chế độ: giữ vị trí khối đang đọc (tính theo chế độ cũ)
      _targetBlock = oldWidget.settings.layout == ReaderLayout.paginate
          ? (_pages.isEmpty ? _targetBlock : _pages[_page.clamp(0, _pages.length - 1)].firstBlock)
          : (_firstVisibleBlock() ?? _targetBlock);
      _resetControllers();
      _scheduleScrollToTarget();
    }
    final h = widget.highlight;
    if (h != null && h != oldWidget.highlight) _follow(h);
  }

  @override
  void dispose() {
    if (widget.controller?._state == this) widget.controller?._state = null;
    _scroll.dispose();
    _pageController?.dispose();
    super.dispose();
  }

  /// Bỏ controller cũ sau khung hình hiện tại (widget cũ có thể vẫn đang gắn với nó).
  void _disposeLater(ChangeNotifier? controller) {
    if (controller == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) => controller.dispose());
  }

  void _resetControllers() {
    _disposeLater(_scroll);
    _scroll = ScrollController(keepScrollOffset: false);
    _disposeLater(_pageController);
    _pageController = null;
    _pagesKey = null;
    _blockKeys.clear();
  }

  /// Khối đầu tiên đang hiện trên màn hình.
  int _currentBlock() {
    if (_paginate) return _pages.isEmpty ? _targetBlock : _pages[_page.clamp(0, _pages.length - 1)].firstBlock;
    return _firstVisibleBlock() ?? _targetBlock;
  }

  void _jumpTo(int chapter, int block) {
    if (chapter < 0 || chapter >= _chapters.length) return;
    setState(() {
      if (chapter != _chapter) {
        _chapter = chapter;
        _resetControllers();
      }
      _targetBlock = block;
    });
    if (_paginate && _pageController != null && _pageController!.hasClients) {
      _showPageOf(block, animate: false);
    } else {
      _scheduleScrollToTarget();
    }
    widget.onPositionChanged?.call(chapter, block);
  }

  /// Theo khối TTS đang đọc: đổi chương nếu cần, rồi cuộn/lật để khối hiện trên màn hình.
  void _follow(ReaderHighlight h) {
    if (h.chapter != _chapter) {
      _jumpTo(h.chapter, h.start);
      return;
    }
    if (_paginate) {
      if (_pages.isNotEmpty && !_pages[_page.clamp(0, _pages.length - 1)].containsBlock(h.start)) {
        _showPageOf(h.start, animate: true);
      }
      return;
    }
    if (!_isBlockVisible(h.start)) {
      _scrollToBlock(h.start, animate: true);
    }
  }

  // ---------------- Chế độ cuộn ----------------

  void _scheduleScrollToTarget() {
    if (_paginate) return; // chế độ trang tính trang đích lúc dựng
    final target = _targetBlock;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _scrollToBlock(target, animate: false);
    });
  }

  /// Cuộn tới khối [index]. ListView chỉ dựng phần đang hiện, nên ước lượng vị trí
  /// theo tỉ lệ rồi tinh chỉnh bằng `ensureVisible` khi khối đã được dựng.
  Future<void> _scrollToBlock(int index, {required bool animate, int attempt = 0}) async {
    if (!mounted || _paginate || !_scroll.hasClients) return;
    if (index <= 0) {
      _scroll.jumpTo(0);
      return;
    }
    final context = _blockKeys[index]?.currentContext;
    if (context != null) {
      await Scrollable.ensureVisible(
        context,
        alignment: 0.15,
        duration: animate ? const Duration(milliseconds: 300) : Duration.zero,
      );
      return;
    }
    if (attempt >= 6) return;

    final position = _scroll.position;
    final visible = _firstVisibleBlock();
    final count = _chapters[_chapter].blocks.length;
    double offset;
    if (visible == null || attempt == 0) {
      offset = position.maxScrollExtent * index / count;
    } else {
      // Khối đích còn ở trước/sau phần đang hiện: dịch một màn hình về phía đó
      final step = position.viewportDimension * 0.9;
      offset = position.pixels + (index > visible ? step : -step);
    }
    _scroll.jumpTo(offset.clamp(0.0, position.maxScrollExtent));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToBlock(index, animate: animate, attempt: attempt + 1);
    });
  }

  int? _firstVisibleBlock() {
    final viewport = context.findRenderObject() as RenderBox?;
    if (viewport == null || !viewport.attached) return null;
    final top = viewport.localToGlobal(Offset.zero).dy;
    int? best;
    for (final entry in _blockKeys.entries) {
      final box = entry.value.currentContext?.findRenderObject() as RenderBox?;
      if (box == null || !box.attached) continue;
      final y = box.localToGlobal(Offset.zero).dy;
      if (y + box.size.height > top + 1 && (best == null || entry.key < best)) best = entry.key;
    }
    return best;
  }

  bool _isBlockVisible(int index) {
    final viewport = context.findRenderObject() as RenderBox?;
    final box = _blockKeys[index]?.currentContext?.findRenderObject() as RenderBox?;
    if (viewport == null || box == null || !box.attached) return false;
    final top = viewport.localToGlobal(Offset.zero).dy;
    final y = box.localToGlobal(Offset.zero).dy;
    return y >= top && y + 24 <= top + viewport.size.height;
  }

  void _reportScrollPosition() {
    final block = _firstVisibleBlock();
    if (block != null) widget.onPositionChanged?.call(_chapter, block);
  }

  void _changeChapter(int delta, {bool atEnd = false}) {
    final next = _chapter + delta;
    if (next < 0 || next >= _chapters.length) return;
    final block = atEnd ? (_chapters[next].blocks.length - 1).clamp(0, 1 << 30) : 0;
    _jumpTo(next, block);
  }

  Widget _buildScroll(ReaderStyles styles, Color background) {
    final chapter = _chapters[_chapter];
    final m = widget.settings.margin;
    return NotificationListener<ScrollEndNotification>(
      onNotification: (_) {
        _reportScrollPosition();
        return false;
      },
      child: ListView.builder(
        key: ValueKey('chapter_$_chapter'),
        controller: _scroll,
        padding: EdgeInsets.fromLTRB(m, 16, m, 32),
        itemCount: chapter.blocks.length + 1,
        itemBuilder: (context, index) {
          if (index == chapter.blocks.length) return _chapterNav(styles);
          final key = _blockKeys.putIfAbsent(index, () => GlobalKey());
          return KeyedSubtree(
            key: key,
            child: Padding(
              padding: EdgeInsets.only(bottom: styles.blockGap),
              child: _buildBlock(chapter.blocks[index], index, styles,
                  maxImageHeight: MediaQuery.sizeOf(context).height * 0.8),
            ),
          );
        },
      ),
    );
  }

  Widget _chapterNav(ReaderStyles styles) {
    final hasPrev = _chapter > 0;
    final hasNext = _chapter < _chapters.length - 1;
    if (!hasPrev && !hasNext) return const SizedBox(height: 48);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Row(
        children: [
          if (hasPrev)
            TextButton.icon(
              onPressed: () => _changeChapter(-1),
              icon: const Icon(Icons.chevron_left),
              label: const Text('Chương trước'),
              style: TextButton.styleFrom(foregroundColor: styles.textColor),
            ),
          const Spacer(),
          if (hasNext)
            FilledButton.tonalIcon(
              onPressed: () => _changeChapter(1),
              icon: const Icon(Icons.chevron_right),
              label: const Text('Chương sau'),
            ),
        ],
      ),
    );
  }

  // ---------------- Chế độ chia trang ----------------

  void _showPageOf(int block, {required bool animate}) {
    final page = _pageIndexOf(block);
    final controller = _pageController;
    if (controller == null || !controller.hasClients) return;
    final target = page + (_hasPrevChapter ? 1 : 0);
    if (animate) {
      controller.animateToPage(target, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
    } else {
      controller.jumpToPage(target);
    }
  }

  int _pageIndexOf(int block) {
    for (int i = _pages.length - 1; i >= 0; i--) {
      if (_pages[i].items.isNotEmpty && _pages[i].firstBlock <= block) return i;
    }
    return 0;
  }

  Widget _buildPaginated(ReaderStyles styles, Color background) {
    return LayoutBuilder(builder: (context, constraints) {
      final m = widget.settings.margin;
      const footer = 28.0;
      final size = Size(constraints.maxWidth - m * 2, constraints.maxHeight - 24 - footer);
      final scaler = MediaQuery.textScalerOf(context);
      final key = (_chapter, size, widget.settings, scaler, styles.textColor);
      if (key != _pagesKey) {
        final keepBlock = _pagesKey == null ? _targetBlock : _currentBlock();
        _pages = ReaderPaginator.paginate(_chapters[_chapter], size, styles, textScaler: scaler);
        _pagesKey = key;
        _pagination++;
        _page = _pageIndexOf(keepBlock);
        _hasPrevChapter = _chapter > 0;
        _disposeLater(_pageController);
        _pageController = PageController(keepPage: false, initialPage: _page + (_hasPrevChapter ? 1 : 0));
      }
      final hasNext = _chapter < _chapters.length - 1;
      final offset = _hasPrevChapter ? 1 : 0;
      final count = _pages.length + offset + (hasNext ? 1 : 0);

      return Stack(
        children: [
          PageView.builder(
            key: ValueKey('pages_${_chapter}_$_pagination'),
            controller: _pageController,
            itemCount: count,
            onPageChanged: (index) {
              // Trang đệm ở hai đầu: vuốt qua là sang chương trước/sau
              if (_hasPrevChapter && index == 0) {
                WidgetsBinding.instance.addPostFrameCallback((_) => _changeChapter(-1, atEnd: true));
                return;
              }
              if (hasNext && index == count - 1) {
                WidgetsBinding.instance.addPostFrameCallback((_) => _changeChapter(1));
                return;
              }
              _page = index - offset;
              widget.onPositionChanged?.call(_chapter, _pages[_page].firstBlock);
              setState(() {});
            },
            itemBuilder: (context, index) {
              final page = index - offset;
              if (page < 0 || page >= _pages.length) {
                return Center(child: Text(page < 0 ? 'Chương trước' : 'Chương sau', style: styles.paragraph));
              }
              return Padding(
                padding: EdgeInsets.fromLTRB(m, 16, m, 8 + footer),
                // Chữ đo lệch vài pixel thì cắt đi, không báo tràn
                child: ClipRect(
                  child: OverflowBox(
                    alignment: Alignment.topCenter,
                    maxHeight: double.infinity,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (final item in _pages[page].items)
                          Padding(
                            padding: EdgeInsets.only(
                              bottom: _isLastPiece(item) && item != _pages[page].items.last ? styles.blockGap : 0,
                            ),
                            child: _buildPageItem(item, styles),
                          ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
          // Chạm mép trái/phải để lật trang
          Positioned.fill(
            child: Row(
              children: [
                _tapZone(() => _turnPage(-1)),
                const Spacer(flex: 3),
                _tapZone(() => _turnPage(1)),
              ],
            ),
          ),
          Positioned(
            left: m,
            right: m,
            bottom: 8,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _chapters[_chapter].title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: styles.textColor.withValues(alpha: 0.6)),
                  ),
                ),
                Text(
                  '${_page + 1}/${_pages.length}',
                  style: TextStyle(fontSize: 12, color: styles.textColor.withValues(alpha: 0.6)),
                ),
              ],
            ),
          ),
        ],
      );
    });
  }

  Widget _tapZone(VoidCallback onTap) => Expanded(
        flex: 1,
        child: GestureDetector(behavior: HitTestBehavior.translucent, onTap: onTap),
      );

  void _turnPage(int delta) {
    final controller = _pageController;
    if (controller == null || !controller.hasClients) return;
    final next = _page + delta;
    if (next < 0) {
      _changeChapter(-1, atEnd: true);
    } else if (next >= _pages.length) {
      _changeChapter(1);
    } else {
      controller.animateToPage(next + (_hasPrevChapter ? 1 : 0),
          duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
    }
  }

  /// Phần cuối của khối (để thêm khoảng cách sau khối như ở chế độ cuộn).
  bool _isLastPiece(PageItem item) {
    if (item.isImage) return true;
    final block = _chapters[_chapter].blocks[item.block];
    return item.end >= block.text!.length;
  }

  Widget _buildPageItem(PageItem item, ReaderStyles styles) {
    final block = _chapters[_chapter].blocks[item.block];
    if (item.isImage) {
      return SizedBox(height: item.imageHeight, child: _image(block));
    }
    return _text(block, item.block, styles, block.text!.substring(item.start, item.end));
  }

  // ---------------- Khối ----------------

  Widget _buildBlock(ReaderBlock block, int index, ReaderStyles styles, {required double maxImageHeight}) {
    if (block.isImage) {
      return LayoutBuilder(builder: (context, constraints) {
        final height = ReaderStyles.imageHeight(block.image!, constraints.maxWidth, maxImageHeight);
        return SizedBox(height: height, child: _image(block));
      });
    }
    return _text(block, index, styles, block.text!);
  }

  Widget _image(ReaderBlock block) => Center(
        child: Image.memory(
          block.image!,
          fit: BoxFit.contain,
          gaplessPlayback: true,
          // Ảnh hỏng thì bỏ qua, không làm vỡ trang
          errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
        ),
      );

  Widget _text(ReaderBlock block, int index, ReaderStyles styles, String text) {
    final highlighted = widget.highlight?.contains(_chapter, index) ?? false;
    final child = Text(text, style: styles.styleOf(block), textAlign: styles.alignOf(block));
    if (!highlighted) return child;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(4),
      ),
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = widget.settings.colors(Theme.of(context));
    final styles = ReaderStyles(widget.settings, colors.text);
    if (_chapters.isEmpty) {
      return ColoredBox(color: colors.background, child: const Center(child: Text('Sách không có nội dung')));
    }
    final chapter = _chapters[_chapter];
    Widget body;
    if (chapter.blocks.isEmpty) {
      body = ListView(
        padding: EdgeInsets.all(widget.settings.margin),
        children: [
          const SizedBox(height: 48),
          Text('Trang này không có chữ', textAlign: TextAlign.center, style: styles.paragraph),
          _chapterNav(styles),
        ],
      );
    } else {
      body = _paginate ? _buildPaginated(styles, colors.background) : _buildScroll(styles, colors.background);
    }
    return ColoredBox(
      color: colors.background,
      child: DefaultTextStyle(style: styles.paragraph, child: body),
    );
  }
}
