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
  final record0 = r0.buffer.asUint8List()
    ..setAll(16, ascii.encode('MOBI'))
    ..setAll(16 + mobiHeaderLength, exthBytes)
    ..setAll(16 + mobiHeaderLength + exthBytes.length, nameBytes);

  final records = [record0, ...textRecords.map(Uint8List.fromList)];
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

    test('rejects DRM, HUFF compression and non-MOBI data', () {
      final text = [utf8.encode('<p>x</p>')];
      expect(() => MobiParser.parse(buildMobi(textRecords: text, encryption: 2)),
          throwsA(isA<MobiFormatException>()));
      expect(() => MobiParser.parse(buildMobi(textRecords: text, compression: MobiParser.COMPRESSION_HUFF)),
          throwsA(isA<MobiFormatException>()));
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
