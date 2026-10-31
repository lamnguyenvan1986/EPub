import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:libri_audio/services/mobi_parser.dart';

/// Tạo file MOBI tối thiểu: PalmDB + record 0 (PalmDOC + MOBI header + EXTH) + record text.
Uint8List buildMobi({
  required List<List<int>> textRecords,
  int compression = MobiParser.COMPRESSION_NONE,
  int encryption = 0,
  int extraFlags = 0,
  String title = 'Sách thử',
  String? author,
  List<List<int>> huffRecords = const [],
  List<List<int>> imageRecords = const [],
}) {
  const mobiHeaderLength = 232;
  final nameBytes = utf8.encode(title);

  final exth = BytesBuilder();
  if (author != null) {
    final authorBytes = utf8.encode(author);
    final rec = ByteData(8)
      ..setUint32(0, 100)
      ..setUint32(4, 8 + authorBytes.length);
    final body = BytesBuilder()
      ..add(rec.buffer.asUint8List())
      ..add(authorBytes);
    final head = ByteData(12)
      ..setUint32(4, 12 + body.length)
      ..setUint32(8, 1);
    final headBytes = head.buffer.asUint8List()..setAll(0, ascii.encode('EXTH'));
    exth
      ..add(headBytes)
      ..add(body.takeBytes());
  }
  final exthBytes = exth.takeBytes();

  final r0Length = 16 + mobiHeaderLength + exthBytes.length + nameBytes.length;
  final r0 = ByteData(r0Length);
  final textLength = textRecords.fold<int>(0, (n, r) => n + r.length);
  r0
    ..setUint16(0, compression)
    ..setUint32(4, textLength)
    ..setUint16(8, textRecords.length)
    ..setUint16(10, 4096)
    ..setUint16(12, encryption)
    ..setUint32(20, mobiHeaderLength)
    ..setUint32(24, 2)
    ..setUint32(28, 65001)
    ..setUint32(84, 16 + mobiHeaderLength + exthBytes.length)
    ..setUint32(88, nameBytes.length)
    ..setUint32(128, author != null ? 0x40 : 0)
    ..setUint16(0xF2, extraFlags);
  // Thứ tự record: 0, text, HUFF/CDIC, ảnh
  if (huffRecords.isNotEmpty) {
    r0
      ..setUint32(0x70, 1 + textRecords.length)
      ..setUint32(0x74, huffRecords.length);
  }
  r0.setUint32(0x6C, imageRecords.isEmpty ? 0xFFFFFFFF : 1 + textRecords.length + huffRecords.length);
  final record0 = r0.buffer.asUint8List()
    ..setAll(16, ascii.encode('MOBI'))
    ..setAll(16 + mobiHeaderLength, exthBytes)
    ..setAll(16 + mobiHeaderLength + exthBytes.length, nameBytes);

  final records = [
    record0,
    ...textRecords.map(Uint8List.fromList),
    ...huffRecords.map(Uint8List.fromList),
    ...imageRecords.map(Uint8List.fromList),
  ];
  final headerLength = 78 + records.length * 8 + 2;
  final header = ByteData(headerLength);
  final headerBytes = header.buffer.asUint8List()
    ..setAll(0, ascii.encode('test'))
    ..setAll(60, ascii.encode('BOOKMOBI'));
  header.setUint16(76, records.length);
  var offset = headerLength;
  for (int i = 0; i < records.length; i++) {
    header.setUint32(78 + i * 8, offset);
    offset += records[i].length;
  }

  final out = BytesBuilder()..add(headerBytes);
  for (final r in records) {
    out.add(r);
  }
  return out.takeBytes();
}

/// Bộ mã HUFF/CDIC nhỏ để test: 255 cụm 1 byte (mã 8 bit, terminal) và 2 cụm
/// mã 9 bit (đi qua bảng mincode/maxcode), trong đó 1 cụm nén đệ quy.
class TestHuff {
  static const String plainPhrase = 'xin chào ';
  static const String nestedPhrase = 'AB';

  /// Ghi chuỗi mã: phần tử 0..254 là byte, 255 là [plainPhrase], 256 là [nestedPhrase].
  static Uint8List encode(List<int> symbols) {
    final bits = <int>[];
    void put(int code, int len) {
      for (int i = len - 1; i >= 0; i--) {
        bits.add((code >> i) & 1);
      }
    }

    for (final r in symbols) {
      if (r < 255) {
        put(255 - r, 8);
      } else {
        put(256 - r, 9);
      }
    }
    final out = Uint8List((bits.length + 7) ~/ 8);
    for (int i = 0; i < bits.length; i++) {
      if (bits[i] == 1) out[i >> 3] |= 0x80 >> (i & 7);
    }
    return out;
  }

  static List<int> symbolsFor(String text) => utf8.encode(text);

  static List<Uint8List> records() {
    final huff = ByteData(24 + 256 * 4 + 64 * 4);
    huff.buffer.asUint8List().setAll(0, ascii.encode('HUFF'));
    huff
      ..setUint32(4, 0x18)
      ..setUint32(8, 24)
      ..setUint32(12, 24 + 256 * 4);
    for (int i = 0; i < 256; i++) {
      // byte đầu 0: mã 9 bit (không terminal); còn lại mã 8 bit, maxcode 255
      huff.setUint32(24 + i * 4, i == 0 ? 8 : (8 | 0x80 | (255 << 8)));
    }
    for (int len = 1; len <= 32; len++) {
      final base = 24 + 256 * 4 + (len - 1) * 8;
      final (min, max) = switch (len) { 8 => (1, 255), 9 => (0, 256), _ => (0, 0) };
      huff
        ..setUint32(base, min)
        ..setUint32(base + 4, max);
    }

    final phrases = <(List<int>, bool)>[
      for (int b = 0; b < 255; b++) ([b], true),
      (utf8.encode(plainPhrase), true),
      (encode(utf8.encode(nestedPhrase)), false),
    ];
    final body = BytesBuilder();
    final offsets = <int>[];
    final tableLength = phrases.length * 2;
    for (final (bytes, decoded) in phrases) {
      offsets.add(tableLength + body.length);
      final len = ByteData(2)..setUint16(0, bytes.length | (decoded ? 0x8000 : 0));
      body
        ..add(len.buffer.asUint8List())
        ..add(bytes);
    }
    final cdic = ByteData(16 + tableLength);
    cdic.buffer.asUint8List().setAll(0, ascii.encode('CDIC'));
    cdic
      ..setUint32(4, 0x10)
      ..setUint32(8, phrases.length)
      ..setUint32(12, 9);
    for (int i = 0; i < offsets.length; i++) {
      cdic.setUint16(16 + i * 2, offsets[i]);
    }
    final cdicBytes = BytesBuilder()
      ..add(cdic.buffer.asUint8List())
      ..add(body.takeBytes());
    return [huff.buffer.asUint8List(), cdicBytes.takeBytes()];
  }
}

void main() {
  const html = '<html><body><h1>Chương Một</h1><p>Xin chào &amp; tạm biệt.</p>'
      '<p>Đoạn thứ hai.</p><mbp:pagebreak/><h2>Chương Hai</h2><p>Nội dung<br/>xuống dòng</p>'
      '</body></html>';

  group('MobiParser', () {
    test('reads title, author and chapters from an uncompressed file', () {
      final bytes = utf8.encode(html);
      final book = MobiParser.parse(buildMobi(
        textRecords: [bytes.sublist(0, 60), bytes.sublist(60)],
        author: 'Tác giả',
      ));

      expect(book.title, 'Sách thử');
      expect(book.author, 'Tác giả');
      expect(book.chapters.map((c) => c.title), ['Chương Một', 'Chương Hai']);
      expect(book.chapters[0].paragraphs, ['Chương Một', 'Xin chào & tạm biệt.', 'Đoạn thứ hai.']);
      expect(book.chapters[1].paragraphs, ['Chương Hai', 'Nội dung', 'xuống dòng']);
    });

    test('reads PalmDOC compressed text', () {
      // Text ASCII (0x09-0x7F) là chuỗi PalmDOC hợp lệ (literal)
      const text = '<p>Hello world</p><mbp:pagebreak/><p>Second</p>';
      final book = MobiParser.parse(buildMobi(
        textRecords: [ascii.encode(text)],
        compression: MobiParser.COMPRESSION_PALMDOC,
      ));

      expect(book.chapters.length, 2);
      expect(book.chapters[0].paragraphs, ['Hello world']);
      expect(book.chapters[1].paragraphs, ['Second']);
    });

    test('strips trailing entries and multibyte bytes from text records', () {
      final record = [
        ...utf8.encode('<p>Có dấu</p>'),
        0x00, // multibyte: (0 & 3) + 1 = 1 byte
        0xAA, 0xBB, 0x83, // trailing entry dài 3 byte
      ];
      final book = MobiParser.parse(buildMobi(textRecords: [record], extraFlags: 0x3));

      expect(book.chapters.single.paragraphs, ['Có dấu']);
    });

    test('reads HUFF/CDIC compressed text', () {
      final records = TestHuff.records();
      final text1 = TestHuff.encode([...TestHuff.symbolsFor('<p>'), 255, ...TestHuff.symbolsFor('bạn</p>')]);
      final text2 = TestHuff.encode([...TestHuff.symbolsFor('<p>'), 256, 256, ...TestHuff.symbolsFor('</p>')]);
      final book = MobiParser.parse(buildMobi(
        textRecords: [text1, text2],
        compression: MobiParser.COMPRESSION_HUFF,
        huffRecords: records,
      ));

      expect(book.chapters.single.paragraphs, ['xin chào bạn', 'ABAB']);
    });

    test('HUFF/CDIC without tables is reported as corrupt', () {
      final text = [utf8.encode('<p>x</p>')];
      expect(
        () => MobiParser.parse(buildMobi(textRecords: text, compression: MobiParser.COMPRESSION_HUFF)),
        throwsA(isA<MobiFormatException>()),
      );
    });

    test('keeps images in place and drops missing or unknown ones', () {
      final jpeg = [0xFF, 0xD8, 0xFF, 0xE0, 1, 2, 3];
      final png = [0x89, 0x50, 0x4E, 0x47, 4, 5];
      final notImage = ascii.encode('FLIS0000');
      final content = utf8.encode('<p>Trước ảnh</p><p><img recindex="00001" /></p><p>Giữa<img hirecindex="2"/>sau</p>'
          '<img recindex="3"><img recindex="9"><mbp:pagebreak/><img src="kindle:embed:0002?mime=image/png"/>');
      final book = MobiParser.parse(buildMobi(textRecords: [content], imageRecords: [jpeg, png, notImage]));

      expect(book.images.keys, unorderedEquals([1, 2]));
      expect(book.images[1], jpeg);
      final blocks = book.chapters[0].blocks;
      expect(blocks.map((b) => b.isImage ? 'img${b.imageIndex}' : b.text),
          ['Trước ảnh', 'img1', 'Giữa', 'img2', 'sau']);
      expect(book.chapters[0].paragraphs, ['Trước ảnh', 'Giữa', 'sau']);
      // Chương chỉ có ảnh vẫn được giữ
      expect(book.chapters[1].blocks.single.imageIndex, 2);
      expect(book.chapters[1].paragraphs, isEmpty);
    });

    test('rejects DRM with a clear message and non-MOBI data', () {
      final text = [utf8.encode('<p>x</p>')];
      expect(
        () => MobiParser.parse(buildMobi(textRecords: text, encryption: 2)),
        throwsA(isA<MobiFormatException>().having((e) => e.message, 'message', contains('DRM'))),
      );
      expect(() => MobiParser.parse(Uint8List(200)), throwsA(isA<MobiFormatException>()));
    });
  });

  group('MobiParser.palmDocDecompress', () {
    test('handles literals, space pairs and back references', () {
      final input = Uint8List.fromList([
        ...ascii.encode('abc'),
        0x02, 0xFF, 0xFE, // 2 byte literal thô
        0xE4, // ' ' + 'd'
        // back reference: distance 7 (đầu chuỗi), length 3 → "abc"
        0x80 | ((7 << 3) >> 8), (7 << 3) & 0xFF,
      ]);
      final out = MobiParser.palmDocDecompress(input);
      expect(out, [...ascii.encode('abc'), 0xFF, 0xFE, ...ascii.encode(' d'), ...ascii.encode('abc')]);
    });
  });
}
