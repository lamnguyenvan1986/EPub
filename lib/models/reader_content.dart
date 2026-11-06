import 'dart:typed_data';

/// Loại khối nội dung trong một chương.
enum ReaderBlockType { paragraph, heading, image }

/// Một khối nội dung: đoạn văn, tiêu đề hoặc ảnh.
///
/// Đây là mô hình chung cho mọi định dạng (EPUB, MOBI/AZW, PDF dạng chữ):
/// parser của từng định dạng chuyển nội dung về các khối này, còn trình đọc
/// ([ReaderView]) và TTS chỉ làm việc với khối, không cần biết file gốc.
class ReaderBlock {
  final ReaderBlockType type;

  /// Nội dung chữ (đoạn văn, tiêu đề). `null` với ảnh.
  final String? text;

  /// Bytes ảnh (JPEG/PNG/GIF/BMP/WebP). `null` với chữ.
  final Uint8List? image;

  /// Cấp tiêu đề 1-6 (chỉ dùng với [ReaderBlockType.heading]).
  final int level;

  const ReaderBlock.paragraph(String this.text)
      : type = ReaderBlockType.paragraph,
        image = null,
        level = 0;

  const ReaderBlock.heading(String this.text, {this.level = 2})
      : type = ReaderBlockType.heading,
        image = null;

  const ReaderBlock.image(Uint8List this.image)
      : type = ReaderBlockType.image,
        text = null,
        level = 0;

  bool get isImage => type == ReaderBlockType.image;
  bool get isText => !isImage;
}

/// Một chương: tiêu đề (cho mục lục, chế độ nghe) và các khối theo thứ tự.
class ReaderChapter {
  final String title;
  final List<ReaderBlock> blocks;

  const ReaderChapter(this.title, this.blocks);

  /// Text của cả chương, mỗi khối chữ một dòng.
  String get plainText => [
        for (final b in blocks)
          if (b.isText) b.text!,
      ].join('\n');
}

/// Nội dung sách đã tách ra để trình đọc chung hiển thị.
///
/// Vị trí đọc trong sách là (chỉ số chương, chỉ số khối trong chương).
class ReaderDocument {
  final String title;
  final String? author;
  final List<ReaderChapter> chapters;

  const ReaderDocument({required this.title, this.author, required this.chapters});

  bool get isEmpty => chapters.every((c) => c.blocks.isEmpty);

  /// Text toàn sách cho tìm kiếm.
  String get plainText => chapters.map((c) => c.plainText).where((t) => t.isNotEmpty).join('\n');
}

/// Kích thước điểm ảnh của ảnh, đọc từ phần đầu file (không giải mã cả ảnh).
///
/// Dùng để giữ đúng tỉ lệ ảnh khi chia trang. Trả về `null` nếu không nhận ra định dạng.
({int width, int height})? imageSizeOf(Uint8List data) {
  int u16be(int i) => (data[i] << 8) | data[i + 1];
  int u16le(int i) => data[i] | (data[i + 1] << 8);
  int u32be(int i) => (data[i] << 24 | data[i + 1] << 16 | data[i + 2] << 8 | data[i + 3]) & 0xFFFFFFFF;
  int u32le(int i) => (data[i] | data[i + 1] << 8 | data[i + 2] << 16 | data[i + 3] << 24) & 0xFFFFFFFF;

  try {
    // PNG: IHDR ngay sau chữ ký 8 byte
    if (data.length >= 24 && data[0] == 0x89 && data[1] == 0x50 && data[2] == 0x4E && data[3] == 0x47) {
      return (width: u32be(16), height: u32be(20));
    }
    // GIF
    if (data.length >= 10 && data[0] == 0x47 && data[1] == 0x49 && data[2] == 0x46) {
      return (width: u16le(6), height: u16le(8));
    }
    // BMP
    if (data.length >= 26 && data[0] == 0x42 && data[1] == 0x4D) {
      final h = u32le(22);
      // Chiều cao âm nghĩa là ảnh lưu từ trên xuống
      return (width: u32le(18), height: h > 0x7FFFFFFF ? 0x100000000 - h : h);
    }
    // JPEG: tìm marker SOFn
    if (data.length >= 4 && data[0] == 0xFF && data[1] == 0xD8) {
      var i = 2;
      while (i + 9 < data.length) {
        if (data[i] != 0xFF) {
          i++;
          continue;
        }
        final marker = data[i + 1];
        if (marker == 0xD8 || marker == 0x01 || (marker >= 0xD0 && marker <= 0xD7) || marker == 0xFF) {
          i++;
          continue;
        }
        final length = u16be(i + 2);
        final isSof = marker >= 0xC0 && marker <= 0xCF && marker != 0xC4 && marker != 0xC8 && marker != 0xCC;
        if (isSof) {
          return (width: u16be(i + 7), height: u16be(i + 5));
        }
        i += 2 + length;
      }
    }
    // WebP (VP8 / VP8L / VP8X)
    if (data.length >= 30 &&
        data[0] == 0x52 && data[1] == 0x49 && data[2] == 0x46 && data[3] == 0x46 &&
        data[8] == 0x57 && data[9] == 0x45 && data[10] == 0x42 && data[11] == 0x50) {
      final chunk = String.fromCharCodes(data.sublist(12, 16));
      if (chunk == 'VP8 ') {
        return (width: u16le(26) & 0x3FFF, height: u16le(28) & 0x3FFF);
      }
      if (chunk == 'VP8L') {
        final bits = u32le(21);
        return (width: (bits & 0x3FFF) + 1, height: ((bits >> 14) & 0x3FFF) + 1);
      }
      if (chunk == 'VP8X') {
        final w = data[24] | data[25] << 8 | data[26] << 16;
        final h = data[27] | data[28] << 8 | data[29] << 16;
        return (width: w + 1, height: h + 1);
      }
    }
  } catch (_) {
    // Header hỏng: coi như không biết kích thước
  }
  return null;
}
