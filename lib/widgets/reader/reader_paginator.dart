import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:libri_audio/models/reader_content.dart';
import 'package:libri_audio/providers/reader_settings_provider.dart';

/// Một phần của khối trên một trang: đoạn chữ `[start, end)` của khối [block],
/// hoặc cả ảnh (khi đó [imageHeight] là chiều cao hiển thị).
class PageItem {
  final int block;
  final int start;
  final int end;
  final double imageHeight;

  const PageItem.text(this.block, this.start, this.end) : imageHeight = 0;
  const PageItem.image(this.block, this.imageHeight)
      : start = 0,
        end = 0;

  bool get isImage => imageHeight > 0;
}

class ReaderPage {
  final List<PageItem> items;
  const ReaderPage(this.items);

  int get firstBlock => items.isEmpty ? 0 : items.first.block;
  int get lastBlock => items.isEmpty ? 0 : items.last.block;

  bool containsBlock(int block) => block >= firstBlock && block <= lastBlock;
}

/// Kiểu chữ của từng loại khối, dùng chung cho chế độ cuộn, chia trang và bộ chia trang.
class ReaderStyles {
  final ReaderSettings settings;
  final Color textColor;

  const ReaderStyles(this.settings, this.textColor);

  TextStyle get paragraph => settings.textStyle(textColor);

  TextStyle heading(int level) => settings.textStyle(textColor).copyWith(
        fontSize: settings.fontSize * (level <= 1 ? 1.5 : level == 2 ? 1.3 : 1.15),
        fontWeight: FontWeight.bold,
        height: 1.3,
      );

  TextStyle styleOf(ReaderBlock block) =>
      block.type == ReaderBlockType.heading ? heading(block.level) : paragraph;

  TextAlign alignOf(ReaderBlock block) =>
      settings.justify && block.type == ReaderBlockType.paragraph ? TextAlign.justify : TextAlign.start;

  /// Khoảng cách sau mỗi khối.
  double get blockGap => settings.fontSize * 0.8;

  /// Chiều cao hiển thị của ảnh: vừa chiều rộng (không phóng quá 2 lần), không cao quá [maxHeight].
  static double imageHeight(Uint8List bytes, double maxWidth, double maxHeight) {
    final size = imageSizeOf(bytes);
    if (size == null || size.width <= 0 || size.height <= 0) return maxHeight * 0.5;
    final width = size.width * 2.0 < maxWidth ? size.width * 2.0 : maxWidth;
    final height = width * size.height / size.width;
    return height > maxHeight ? maxHeight : height;
  }
}

/// Chia một chương thành các trang vừa khung [size] (đã trừ lề).
///
/// Đo chữ bằng [TextPainter] với cùng kiểu chữ và [textScaler] như lúc hiển thị,
/// nên mỗi đoạn được cắt đúng tại đầu dòng. Đoạn dài được chia qua nhiều trang.
class ReaderPaginator {
  static List<ReaderPage> paginate(
    ReaderChapter chapter,
    Size size,
    ReaderStyles styles, {
    TextScaler textScaler = TextScaler.noScaling,
  }) {
    final pageHeight = size.height - 1; // chừa sai số làm tròn khi vẽ
    final pages = <ReaderPage>[];
    var items = <PageItem>[];
    var y = 0.0;

    void newPage() {
      if (items.isNotEmpty) pages.add(ReaderPage(items));
      items = [];
      y = 0;
    }

    for (int i = 0; i < chapter.blocks.length; i++) {
      final block = chapter.blocks[i];
      if (block.isImage) {
        final height = ReaderStyles.imageHeight(block.image!, size.width, pageHeight);
        if (y + height > pageHeight) newPage();
        items.add(PageItem.image(i, height));
        y += height + styles.blockGap;
        continue;
      }

      final text = block.text!;
      final painter = TextPainter(
        text: TextSpan(text: text, style: styles.styleOf(block)),
        textAlign: styles.alignOf(block),
        textDirection: TextDirection.ltr,
        textScaler: textScaler,
      )..layout(maxWidth: size.width);
      final lines = painter.computeLineMetrics();

      // Tiêu đề không nằm một mình cuối trang
      if (block.type == ReaderBlockType.heading && y > 0 && y + painter.height + styles.paragraph.fontSize! * 3 > pageHeight) {
        newPage();
      }

      var segmentStart = 0;
      for (final line in lines) {
        if (y + line.height > pageHeight && y > 0) {
          final lineTop = line.baseline - line.ascent;
          final offset = painter.getPositionForOffset(Offset(0, lineTop + line.height / 2)).offset;
          if (offset > segmentStart) items.add(PageItem.text(i, segmentStart, offset));
          newPage();
          segmentStart = offset;
        }
        y += line.height;
      }
      if (segmentStart < text.length) {
        items.add(PageItem.text(i, segmentStart, text.length));
      }
      painter.dispose();
      y += styles.blockGap;
    }
    newPage();
    if (pages.isEmpty) pages.add(const ReaderPage([]));
    return pages;
  }
}
