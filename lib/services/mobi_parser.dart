import 'dart:convert';
import 'dart:typed_data';
import 'package:html/parser.dart' as html_parser;

/// Một chương của sách MOBI: tiêu đề và các đoạn văn (text thuần).
class MobiChapter {
  final String title;
  final List<String> paragraphs;

  const MobiChapter(this.title, this.paragraphs);
}

class MobiBook {
  final String title;
  final String? author;
  final List<MobiChapter> chapters;

  const MobiBook({required this.title, this.author, required this.chapters});
}

class MobiFormatException implements Exception {
  final String message;
  const MobiFormatException(this.message);

  @override
  String toString() => message;
}

/// Đọc file MOBI/AZW (định dạng PalmDB) và trích text theo chương.
///
/// Hỗ trợ nén PalmDOC và không nén. Không hỗ trợ nén HUFF/CDIC và file có DRM.
class MobiParser {
  static const int COMPRESSION_NONE = 1;
  static const int COMPRESSION_PALMDOC = 2;
  static const int COMPRESSION_HUFF = 17480;

  /// Dùng được với `compute()`.
  static MobiBook parse(Uint8List bytes) {
    final data = ByteData.sublistView(bytes);
    if (bytes.length < 78) {
      throw const MobiFormatException('File MOBI không hợp lệ');
    }

    final type = latin1.decode(bytes.sublist(60, 68), allowInvalid: true);
    if (type != 'BOOKMOBI' && type != 'TEXtREAd') {
      throw const MobiFormatException('Không phải file MOBI');
    }

    final recordCount = data.getUint16(76);
    if (recordCount == 0 || 78 + recordCount * 8 > bytes.length) {
      throw const MobiFormatException('File MOBI bị hỏng (bảng record)');
    }
    final offsets = List<int>.generate(recordCount, (i) => data.getUint32(78 + i * 8));

    Uint8List record(int index) {
      final start = offsets[index];
      final end = index + 1 < recordCount ? offsets[index + 1] : bytes.length;
      if (start > end || end > bytes.length) {
        throw const MobiFormatException('File MOBI bị hỏng (record)');
      }
      return Uint8List.sublistView(bytes, start, end);
    }

    final record0 = record(0);
    final r0 = ByteData.sublistView(record0);
    final compression = r0.getUint16(0);
    final textRecordCount = r0.getUint16(8);
    final encryption = record0.length >= 14 ? r0.getUint16(12) : 0;

    if (encryption != 0) {
      throw const MobiFormatException('File MOBI có DRM, không thể đọc');
    }
    if (compression == COMPRESSION_HUFF) {
      throw const MobiFormatException('File MOBI dùng nén HUFF/CDIC, chưa được hỗ trợ');
    }
    if (compression != COMPRESSION_NONE && compression != COMPRESSION_PALMDOC) {
      throw MobiFormatException('Kiểu nén MOBI không hỗ trợ: $compression');
    }

    // MOBI header (không có ở file PalmDOC thuần "TEXtREAd")
    var encoding = 1252;
    var extraFlags = 0;
    String? title;
    String? author;
    final hasMobiHeader = record0.length >= 24 &&
        latin1.decode(record0.sublist(16, 20), allowInvalid: true) == 'MOBI';
    if (hasMobiHeader) {
      final headerLength = r0.getUint32(20);
      encoding = r0.getUint32(28);
      if (headerLength >= 0xE4 && record0.length >= 0xF4) {
        extraFlags = r0.getUint16(0xF2);
      }

      if (record0.length >= 92) {
        final nameOffset = r0.getUint32(84);
        final nameLength = r0.getUint32(88);
        if (nameOffset + nameLength <= record0.length) {
          title = _decode(record0.sublist(nameOffset, nameOffset + nameLength), encoding);
        }
      }

      final exthFlags = record0.length >= 132 ? r0.getUint32(128) : 0;
      if (exthFlags & 0x40 != 0) {
        final exth = _readExth(record0, 16 + headerLength, encoding);
        author = exth[100];
        title = exth[503] ?? title;
      }
    }
    title ??= latin1.decode(bytes.sublist(0, 32), allowInvalid: true).split('\u0000').first;

    // Ghép các record text
    final text = BytesBuilder(copy: false);
    for (int i = 1; i <= textRecordCount && i < recordCount; i++) {
      var rec = record(i);
      final trailing = _trailingSize(rec, extraFlags);
      if (trailing > 0 && trailing <= rec.length) {
        rec = Uint8List.sublistView(rec, 0, rec.length - trailing);
      }
      text.add(compression == COMPRESSION_PALMDOC ? palmDocDecompress(rec) : rec);
    }

    final html = _decode(text.takeBytes(), encoding);
    final chapters = htmlToChapters(html);
    if (chapters.isEmpty) {
      throw const MobiFormatException('Không tìm thấy nội dung trong file MOBI');
    }

    return MobiBook(title: title.trim(), author: author?.trim(), chapters: chapters);
  }

  static String _decode(List<int> bytes, int encoding) {
    return encoding == 65001
        ? utf8.decode(bytes, allowMalformed: true)
        : latin1.decode(bytes, allowInvalid: true);
  }

  static Map<int, String> _readExth(Uint8List record0, int start, int encoding) {
    final result = <int, String>{};
    if (start + 12 > record0.length) return result;
    final d = ByteData.sublistView(record0);
    if (latin1.decode(record0.sublist(start, start + 4), allowInvalid: true) != 'EXTH') {
      return result;
    }
    final count = d.getUint32(start + 8);
    var pos = start + 12;
    for (int i = 0; i < count && pos + 8 <= record0.length; i++) {
      final type = d.getUint32(pos);
      final length = d.getUint32(pos + 4);
      if (length < 8 || pos + length > record0.length) break;
      result.putIfAbsent(type, () => _decode(record0.sublist(pos + 8, pos + length), encoding));
      pos += length;
    }
    return result;
  }

  /// Số byte dữ liệu phụ ở cuối mỗi record text (theo extra data flags).
  static int _trailingSize(Uint8List rec, int flags) {
    int entrySize(int size) {
      var bitPos = 0;
      var result = 0;
      while (size > 0) {
        final v = rec[size - 1];
        result |= (v & 0x7F) << bitPos;
        bitPos += 7;
        size -= 1;
        if ((v & 0x80) != 0 || bitPos >= 28) break;
      }
      return result;
    }

    var num = 0;
    var testFlags = flags >> 1;
    while (testFlags != 0) {
      if (testFlags & 1 != 0) {
        num += entrySize(rec.length - num);
      }
      testFlags >>= 1;
    }
    if (flags & 1 != 0 && rec.length - num - 1 >= 0) {
      num += (rec[rec.length - num - 1] & 0x3) + 1;
    }
    return num;
  }

  /// Giải nén PalmDOC (LZ77 đơn giản).
  static Uint8List palmDocDecompress(Uint8List input) {
    final out = <int>[];
    var i = 0;
    while (i < input.length) {
      final c = input[i++];
      if (c >= 1 && c <= 8) {
        // c byte literal tiếp theo
        for (int j = 0; j < c && i < input.length; j++) {
          out.add(input[i++]);
        }
      } else if (c < 0x80) {
        out.add(c);
      } else if (c >= 0xC0) {
        // khoảng trắng + ký tự
        out.add(0x20);
        out.add(c ^ 0x80);
      } else {
        if (i >= input.length) break;
        final pair = ((c << 8) | input[i++]) & 0x3FFF;
        final distance = pair >> 3;
        final length = (pair & 0x7) + 3;
        if (distance == 0 || distance > out.length) continue;
        for (int j = 0; j < length; j++) {
          out.add(out[out.length - distance]);
        }
      }
    }
    return Uint8List.fromList(out);
  }

  static final RegExp _pageBreak = RegExp(r'<mbp:pagebreak\s*/?>', caseSensitive: false);
  static final RegExp _blockEnd = RegExp(
    r'<(br|/p|/div|/h[1-6]|/li|/blockquote|/tr)\b[^>]*>',
    caseSensitive: false,
  );
  static final RegExp _heading = RegExp(r'<h[1-6]\b[^>]*>(.*?)</h[1-6]>', caseSensitive: false, dotAll: true);

  /// Tách HTML của MOBI thành chương (theo `<mbp:pagebreak/>`) và đoạn văn.
  static List<MobiChapter> htmlToChapters(String html) {
    final chapters = <MobiChapter>[];
    for (final part in html.split(_pageBreak)) {
      final text = html_parser.parseFragment(part.replaceAll(_blockEnd, '\n')).text ?? '';
      final paragraphs = text
          .split('\n')
          .map((line) => line.replaceAll(RegExp(r'\s+'), ' ').trim())
          .where((line) => line.isNotEmpty)
          .toList();
      if (paragraphs.isEmpty) continue;

      var title = '';
      final heading = _heading.firstMatch(part);
      if (heading != null) {
        title = (html_parser.parseFragment(heading.group(1)!).text ?? '')
            .replaceAll(RegExp(r'\s+'), ' ')
            .trim();
      }
      if (title.isEmpty) {
        title = 'Chương ${chapters.length + 1}';
      }
      chapters.add(MobiChapter(title, paragraphs));
    }
    return chapters;
  }
}
