import 'dart:typed_data';

import 'package:libri_audio/models/reader_content.dart';
import 'package:pdfrx/pdfrx.dart';

/// Trích chữ PDF thành [ReaderDocument] cho chế độ "xem dạng chữ" (reflow) và TTS.
///
/// Mỗi trang PDF là một chương "Trang N", để vị trí đọc (chương = trang) khớp
/// với chế độ xem nguyên trang. PDF ảnh scan không có lớp chữ thì trang trống.
class PdfTextExtractor {
  static Future<ReaderDocument> extract(Uint8List bytes, {required String title}) async {
    final document = await PdfDocument.openData(Uint8List.fromList(bytes));
    try {
      final chapters = <ReaderChapter>[];
      for (int i = 0; i < document.pages.length; i++) {
        var blocks = const <ReaderBlock>[];
        try {
          final text = await document.pages[i].loadText();
          blocks = [for (final p in reflowParagraphs(text?.fullText ?? '')) ReaderBlock.paragraph(p)];
        } catch (e) {
          print('Lỗi trích chữ trang PDF $i: $e');
        }
        chapters.add(ReaderChapter('Trang ${i + 1}', blocks));
      }
      return ReaderDocument(title: title, chapters: chapters);
    } finally {
      await document.dispose();
    }
  }

  static final RegExp _sentenceEnd = RegExp(r'[.!?:;…"”’)\]]$');
  static final RegExp _listStart = RegExp(r'^([-•●▪*–]|\d+[.)]|[a-zA-Z][.)])\s');

  /// Ghép các dòng của một trang PDF thành đoạn văn.
  ///
  /// PDF lưu chữ theo dòng hiển thị, nên câu bị ngắt giữa chừng. Dòng được nối
  /// vào đoạn trước, trừ khi: có dòng trống, dòng trước kết thúc câu và ngắn hơn
  /// hẳn dòng dài nhất (dòng cuối đoạn), hoặc dòng mới là mục danh sách.
  /// Từ bị ngắt bằng gạch nối cuối dòng được nối lại.
  static List<String> reflowParagraphs(String pageText) {
    final lines = pageText.replaceAll('\r\n', '\n').replaceAll('\r', '\n').split('\n')
        .map((l) => l.replaceAll(RegExp(r'[ \t ]+'), ' ').trim())
        .toList();
    final maxLength = lines.fold<int>(0, (m, l) => l.length > m ? l.length : m);

    final paragraphs = <String>[];
    final buffer = StringBuffer();
    var previous = '';

    void flush() {
      final text = buffer.toString().trim();
      if (text.isNotEmpty) paragraphs.add(text);
      buffer.clear();
      previous = '';
    }

    for (final line in lines) {
      if (line.isEmpty) {
        flush();
        continue;
      }
      if (previous.isNotEmpty) {
        final endsParagraph = _sentenceEnd.hasMatch(previous) && previous.length < maxLength * 0.8;
        if (endsParagraph || _listStart.hasMatch(line)) {
          flush();
        }
      }
      if (buffer.isEmpty) {
        buffer.write(line);
      } else if (RegExp(r'\p{L}-$', unicode: true).hasMatch(previous) &&
          RegExp(r'^\p{Ll}', unicode: true).hasMatch(line)) {
        // Từ bị ngắt bằng gạch nối cuối dòng ("infor-" + "mation"): bỏ gạch, nối liền
        final text = buffer.toString();
        buffer
          ..clear()
          ..write(text.substring(0, text.length - 1))
          ..write(line);
      } else {
        buffer
          ..write(' ')
          ..write(line);
      }
      previous = line;
    }
    flush();
    return paragraphs;
  }
}
