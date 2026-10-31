import 'dart:convert';
import 'dart:typed_data';
import 'package:html/parser.dart' as html_parser;

/// Một khối nội dung trong chương: đoạn văn hoặc ảnh (khoá trong [MobiBook.images]).
class MobiBlock {
  final String? text;
  final int? imageIndex;

  const MobiBlock.text(String this.text) : imageIndex = null;
  const MobiBlock.image(int this.imageIndex) : text = null;

  bool get isImage => imageIndex != null;
}

/// Một chương của sách MOBI: tiêu đề và các khối nội dung theo thứ tự.
class MobiChapter {
  final String title;
  final List<MobiBlock> blocks;

  /// Chỉ các đoạn văn (dùng cho TTS và lưu vị trí đọc).
  final List<String> paragraphs;

  MobiChapter(this.title, this.blocks)
      : paragraphs = [for (final b in blocks) if (b.text != null) b.text!];
}

class MobiBook {
  final String title;
  final String? author;
  final List<MobiChapter> chapters;

  /// Ảnh trong sách, khoá là số thứ tự ảnh (recindex, bắt đầu từ 1).
  final Map<int, Uint8List> images;

  const MobiBook({
    required this.title,
    this.author,
    required this.chapters,
    this.images = const {},
  });
}

class MobiFormatException implements Exception {
  final String message;
  const MobiFormatException(this.message);

  @override
  String toString() => message;
}

/// Đọc file MOBI/AZW (định dạng PalmDB) và trích text theo chương.
///
/// Hỗ trợ nén PalmDOC, HUFF/CDIC và không nén; lấy ảnh JPEG/PNG/GIF/BMP.
/// File có DRM không đọc được (báo lỗi rõ ràng).
class MobiParser {
  static const int COMPRESSION_NONE = 1;
  static const int COMPRESSION_PALMDOC = 2;
  static const int COMPRESSION_HUFF = 17480;

  static const String drmMessage = 'Sách này có DRM (khoá bản quyền của Amazon/Kindle) nên không mở được. '
      'Hãy dùng file MOBI/AZW không có DRM.';

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
      throw const MobiFormatException(drmMessage);
    }
    if (compression != COMPRESSION_NONE && compression != COMPRESSION_PALMDOC && compression != COMPRESSION_HUFF) {
      throw MobiFormatException('Kiểu nén MOBI không hỗ trợ: $compression');
    }

    // MOBI header (không có ở file PalmDOC thuần "TEXtREAd")
    var encoding = 1252;
    var extraFlags = 0;
    var firstImageIndex = -1;
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
      if (record0.length >= 0x70) {
        final value = r0.getUint32(0x6C);
        if (value > 0 && value < recordCount) firstImageIndex = value;
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

    HuffCdicReader? huff;
    if (compression == COMPRESSION_HUFF) {
      if (!hasMobiHeader || record0.length < 0x78) {
        throw const MobiFormatException('File MOBI nén HUFF thiếu header');
      }
      final huffIndex = r0.getUint32(0x70);
      final huffCount = r0.getUint32(0x74);
      if (huffCount == 0 || huffIndex + huffCount > recordCount) {
        throw const MobiFormatException('File MOBI bị hỏng (bảng HUFF/CDIC)');
      }
      huff = HuffCdicReader([for (int i = 0; i < huffCount; i++) record(huffIndex + i)]);
    }

    // Ghép các record text
    final text = BytesBuilder(copy: false);
    for (int i = 1; i <= textRecordCount && i < recordCount; i++) {
      var rec = record(i);
      final trailing = _trailingSize(rec, extraFlags);
      if (trailing > 0 && trailing <= rec.length) {
        rec = Uint8List.sublistView(rec, 0, rec.length - trailing);
      }
      if (huff != null) {
        text.add(huff.decompress(rec));
      } else {
        text.add(compression == COMPRESSION_PALMDOC ? palmDocDecompress(rec) : rec);
      }
    }

    final html = _decode(text.takeBytes(), encoding);
    final parsed = htmlToChapters(html);

    // Lấy ảnh được nhắc tới trong nội dung; bỏ khối ảnh không đọc được
    final images = <int, Uint8List>{};
    final chapters = <MobiChapter>[];
    for (final chapter in parsed) {
      final blocks = <MobiBlock>[];
      for (final block in chapter.blocks) {
        final index = block.imageIndex;
        if (index != null && !images.containsKey(index)) {
          final recordIndex = firstImageIndex + index - 1;
          if (firstImageIndex < 0 || recordIndex >= recordCount) continue;
          final image = record(recordIndex);
          if (!isImageData(image)) continue;
          images[index] = Uint8List.fromList(image);
        }
        blocks.add(block);
      }
      if (blocks.isNotEmpty) chapters.add(MobiChapter(chapter.title, blocks));
    }
    if (chapters.isEmpty) {
      throw const MobiFormatException('Không tìm thấy nội dung trong file MOBI');
    }

    return MobiBook(title: title.trim(), author: author?.trim(), chapters: chapters, images: images);
  }

  /// Ảnh JPEG, PNG, GIF hoặc BMP (các định dạng Flutter hiển thị được).
  static bool isImageData(Uint8List data) {
    if (data.length < 4) return false;
    if (data[0] == 0xFF && data[1] == 0xD8) return true; // JPEG
    if (data[0] == 0x89 && data[1] == 0x50 && data[2] == 0x4E && data[3] == 0x47) return true; // PNG
    if (data[0] == 0x47 && data[1] == 0x49 && data[2] == 0x46 && data[3] == 0x38) return true; // GIF
    return data[0] == 0x42 && data[1] == 0x4D; // BMP
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
  static final RegExp _imgTag = RegExp(r'<img\b[^>]*>', caseSensitive: false);
  static final RegExp _recIndex = RegExp(r'\b(?:hi|lo)?recindex\s*=\s*"?0*(\d+)', caseSensitive: false);
  static final RegExp _kindleEmbed = RegExp(r'kindle:embed:([0-9A-Va-v]+)');
  // Ký tự vùng riêng đánh dấu vị trí ảnh (parser HTML giữ nguyên, khác với \0)
  static final RegExp _imageMarker = RegExp('^(\\d+)\$');

  /// Số thứ tự ảnh (từ 1) trong thẻ `<img>`: `recindex="00001"` (MOBI) hoặc
  /// `src="kindle:embed:0001"` (KF8, số base32).
  static int? imageIndexOf(String imgTag) {
    final rec = _recIndex.firstMatch(imgTag);
    if (rec != null) return int.tryParse(rec.group(1)!);
    final embed = _kindleEmbed.firstMatch(imgTag);
    if (embed != null) return int.tryParse(embed.group(1)!, radix: 32);
    return null;
  }

  /// Tách HTML của MOBI thành chương (theo `<mbp:pagebreak/>`), đoạn văn và ảnh.
  static List<MobiChapter> htmlToChapters(String html) {
    final chapters = <MobiChapter>[];
    for (final part in html.split(_pageBreak)) {
      // Ảnh thành một dòng riêng chứa dấu đánh dấu, để giữ đúng thứ tự với chữ
      final marked = part.replaceAllMapped(_imgTag, (m) {
        final index = imageIndexOf(m.group(0)!);
        return index == null || index <= 0 ? '' : '\n$index\n';
      });
      final text = html_parser.parseFragment(marked.replaceAll(_blockEnd, '\n')).text ?? '';
      final blocks = <MobiBlock>[];
      for (final rawLine in text.split('\n')) {
        final line = rawLine.replaceAll(RegExp(r'\s+'), ' ').trim();
        if (line.isEmpty) continue;
        final image = _imageMarker.firstMatch(line);
        blocks.add(image != null ? MobiBlock.image(int.parse(image.group(1)!)) : MobiBlock.text(line));
      }
      if (blocks.isEmpty) continue;

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
      chapters.add(MobiChapter(title, blocks));
    }
    return chapters;
  }
}

/// Giải nén HUFF/CDIC (kiểu nén 17480, thường gặp ở sách Kindle cũ).
///
/// Record đầu là bảng mã HUFF, các record sau là từ điển CDIC. Mỗi mã Huffman
/// trỏ tới một cụm byte trong từ điển; cụm chưa giải nén thì giải nén đệ quy.
/// Chỉ dùng số nguyên dưới 2^53 và phép bit 32-bit để chạy đúng cả trên web.
class HuffCdicReader {
  /// dict1[byte đầu của mã]: (độ dài mã, có kết thúc hay không, maxcode).
  final List<int> _codeLen = List.filled(256, 0);
  final List<bool> _term = List.filled(256, false);
  final List<int> _dict1Max = List.filled(256, 0);
  final List<int> _minCode = List.filled(33, 0);
  final List<int> _maxCode = List.filled(33, 0);
  final List<Uint8List?> _slices = [];
  final List<bool> _decoded = [];

  // Dùng nhân thay cho `1 << i` vì trên web phép dịch bit chỉ có 32 bit
  static final List<int> _pow2 = List.generate(33, (i) {
    var v = 1;
    for (int j = 0; j < i; j++) {
      v *= 2;
    }
    return v;
  });

  HuffCdicReader(List<Uint8List> records) {
    if (records.isEmpty) throw const MobiFormatException('Thiếu bảng HUFF');
    _loadHuff(records.first);
    for (final cdic in records.skip(1)) {
      _loadCdic(cdic);
    }
  }

  void _loadHuff(Uint8List huff) {
    if (huff.length < 16 || latin1.decode(huff.sublist(0, 4), allowInvalid: true) != 'HUFF') {
      throw const MobiFormatException('File MOBI bị hỏng (header HUFF)');
    }
    final d = ByteData.sublistView(huff);
    final off1 = d.getUint32(8);
    final off2 = d.getUint32(12);
    if (off1 + 256 * 4 > huff.length || off2 + 64 * 4 > huff.length) {
      throw const MobiFormatException('File MOBI bị hỏng (bảng HUFF)');
    }
    for (int i = 0; i < 256; i++) {
      final v = d.getUint32(off1 + i * 4);
      final len = v & 0x1F;
      _codeLen[i] = len;
      _term[i] = v & 0x80 != 0;
      _dict1Max[i] = (v >>> 8) + 1;
      if (len > 0) _dict1Max[i] = _dict1Max[i] * _pow2[32 - len] - 1;
    }
    for (int len = 1; len <= 32; len++) {
      final min = d.getUint32(off2 + (len - 1) * 8);
      final max = d.getUint32(off2 + (len - 1) * 8 + 4);
      _minCode[len] = min * _pow2[32 - len];
      _maxCode[len] = (max + 1) * _pow2[32 - len] - 1;
    }
  }

  void _loadCdic(Uint8List cdic) {
    if (cdic.length < 16 || latin1.decode(cdic.sublist(0, 4), allowInvalid: true) != 'CDIC') {
      throw const MobiFormatException('File MOBI bị hỏng (header CDIC)');
    }
    final d = ByteData.sublistView(cdic);
    final phrases = d.getUint32(8);
    final bits = d.getUint32(12);
    final remaining = phrases - _slices.length;
    final n = remaining < _pow2[bits.clamp(0, 32)] ? remaining : _pow2[bits.clamp(0, 32)];
    for (int i = 0; i < n; i++) {
      if (16 + i * 2 + 2 > cdic.length) break;
      final off = d.getUint16(16 + i * 2);
      if (16 + off + 2 > cdic.length) {
        _slices.add(Uint8List(0));
        _decoded.add(true);
        continue;
      }
      final blen = d.getUint16(16 + off);
      final start = 18 + off;
      final end = (start + (blen & 0x7FFF)).clamp(start, cdic.length);
      _slices.add(Uint8List.sublistView(cdic, start, end));
      _decoded.add(blen & 0x8000 != 0);
    }
  }

  /// 32 bit liền nhau bắt đầu từ bit [pos] (byte ngoài mảng coi là 0).
  static int _peek32(Uint8List data, int pos) {
    final byte = pos >> 3;
    final shift = pos & 7;
    int at(int i) => byte + i < data.length ? data[byte + i] : 0;
    final hi = at(0) * 0x1000000 + at(1) * 0x10000 + at(2) * 0x100 + at(3);
    if (shift == 0) return hi;
    // (hi << shift) | (byte thứ 5 >> (8 - shift)), giữ 32 bit thấp
    return (hi % _pow2[32 - shift]) * _pow2[shift] + (at(4) >> (8 - shift));
  }

  Uint8List decompress(Uint8List data) => _unpack(data, 0);

  Uint8List _unpack(Uint8List data, int depth) {
    if (depth > 32) throw const MobiFormatException('File MOBI bị hỏng (HUFF lặp vô hạn)');
    final out = BytesBuilder(copy: false);
    final totalBits = data.length * 8;
    var pos = 0;
    while (true) {
      final code = _peek32(data, pos);
      final top = code ~/ 0x1000000;
      var len = _codeLen[top];
      var maxCode = _dict1Max[top];
      if (len == 0) throw const MobiFormatException('File MOBI bị hỏng (mã HUFF)');
      if (!_term[top]) {
        while (len < 32 && code < _minCode[len]) {
          len++;
        }
        maxCode = _maxCode[len];
      }
      pos += len;
      if (pos > totalBits) break;

      final r = (maxCode - code) ~/ _pow2[32 - len];
      if (r < 0 || r >= _slices.length) {
        throw const MobiFormatException('File MOBI bị hỏng (từ điển CDIC)');
      }
      if (!_decoded[r]) {
        _slices[r] = _unpack(_slices[r]!, depth + 1);
        _decoded[r] = true;
      }
      out.add(_slices[r]!);
    }
    return out.takeBytes();
  }
}
