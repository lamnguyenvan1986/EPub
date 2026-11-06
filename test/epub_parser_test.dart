import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libri_audio/models/reader_content.dart';
import 'package:libri_audio/services/epub_parser.dart';

/// PNG 1x1 tối thiểu (đủ để parser nhận ra kích thước).
final Uint8List _png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==',
);

/// EPUB tối thiểu. [manifestExtra]/[files] thêm mục manifest và file; [rename] đổi tên file trong zip.
Uint8List _epub({
  String navProps = 'nav',
  String c1Body = '<h1>Chương một</h1><p>Xin chào.</p><p>Đoạn <b>hai</b>\n  có xuống dòng.</p>',
  String manifestExtra = '',
  String spineExtra = '',
  Map<String, Object> files = const {},
  Map<String, String> rename = const {},
  bool withNav = true,
  bool withNcx = false,
}) {
  final manifest = StringBuffer()
    ..write('<item id="c1" href="Text/c1.xhtml" media-type="application/xhtml+xml"/>')
    ..write('<item id="img" href="Images/a%20b.png" media-type="image/png"/>')
    ..write(manifestExtra);
  if (withNav) manifest.write('<item id="nav" href="nav.xhtml" media-type="application/xhtml+xml" properties="$navProps"/>');
  if (withNcx) manifest.write('<item id="ncx" href="toc.ncx" media-type="application/x-dtbncx+xml"/>');

  final all = <String, Object>{
    'mimetype': 'application/epub+zip',
    'META-INF/container.xml':
        '<?xml version="1.0"?><container version="1.0" xmlns="urn:oasis:names:tc:opendocument:xmlns:container"><rootfiles><rootfile full-path="OEBPS/content.opf" media-type="application/oebps-package+xml"/></rootfiles></container>',
    'OEBPS/content.opf':
        '<?xml version="1.0"?><package xmlns="http://www.idpf.org/2007/opf" version="3.0" unique-identifier="id"><metadata xmlns:dc="http://purl.org/dc/elements/1.1/"><dc:title>Sách &amp; thử</dc:title><dc:creator>Tác Giả</dc:creator><dc:identifier id="id">x1</dc:identifier></metadata><manifest>$manifest</manifest><spine${withNcx ? ' toc="ncx"' : ''}><itemref idref="c1"/>$spineExtra</spine></package>',
    'OEBPS/Text/c1.xhtml':
        '<?xml version="1.0" encoding="utf-8"?><html xmlns="http://www.w3.org/1999/xhtml"><head><title/></head><body>$c1Body<p><img src="../Images/a%20b.png" alt=""/></p><div/><p>Cuối chương.</p></body></html>',
    'OEBPS/Images/a b.png': _png,
    'OEBPS/nav.xhtml':
        '<?xml version="1.0" encoding="utf-8"?><html xmlns="http://www.w3.org/1999/xhtml" xmlns:epub="http://www.idpf.org/2007/ops"><head><title>Mục lục</title></head><body><nav epub:type="toc"><ol><li><a href="Text/c1.xhtml#top">Mở đầu</a></li></ol></nav></body></html>',
    'OEBPS/toc.ncx':
        '<?xml version="1.0"?><ncx xmlns="http://www.daisy.org/z3986/2005/ncx/" version="2005-1"><navMap><navPoint id="n1" playOrder="1"><navLabel><text>Theo NCX</text></navLabel><content src="Text/c1.xhtml"/></navPoint></navMap></ncx>',
    ...files,
  };
  final archive = Archive();
  all.forEach((name, content) {
    final bytes = content is String ? utf8.encode(content) : content as List<int>;
    archive.addFile(ArchiveFile.bytes(rename[name] ?? name, bytes));
  });
  return Uint8List.fromList(ZipEncoder().encodeBytes(archive));
}

void main() {
  test('đọc metadata, chương, tiêu đề, đoạn văn và ảnh theo thứ tự', () {
    final doc = EpubParser.parse(_epub());
    expect(doc.title, 'Sách & thử');
    expect(doc.author, 'Tác Giả');
    expect(doc.chapters, hasLength(1));

    final chapter = doc.chapters.first;
    expect(chapter.title, 'Mở đầu'); // từ nav, bỏ phần #top
    final blocks = chapter.blocks;
    expect(blocks.map((b) => b.type).toList(), [
      ReaderBlockType.heading,
      ReaderBlockType.paragraph,
      ReaderBlockType.paragraph,
      ReaderBlockType.image,
      ReaderBlockType.paragraph,
    ]);
    expect(blocks[0].text, 'Chương một');
    expect(blocks[0].level, 1);
    expect(blocks[2].text, 'Đoạn hai có xuống dòng.');
    expect(blocks[3].image, _png);
    // <div/> tự đóng không nuốt phần sau
    expect(blocks[4].text, 'Cuối chương.');
  });

  test('properties="nav scripted" vẫn đọc được mục lục', () {
    final doc = EpubParser.parse(_epub(navProps: 'nav scripted'));
    expect(doc.chapters.first.title, 'Mở đầu');
  });

  test('không có nav thì lấy tên chương từ NCX', () {
    final doc = EpubParser.parse(_epub(withNav: false, withNcx: true));
    expect(doc.chapters.first.title, 'Theo NCX');
  });

  test('không có mục lục thì lấy tiêu đề đầu tiên trong chương', () {
    final doc = EpubParser.parse(_epub(withNav: false));
    expect(doc.chapters.first.title, 'Chương một');
  });

  test('manifest khai báo file thiếu trong zip: bỏ qua, đọc phần còn lại', () {
    final doc = EpubParser.parse(_epub(
      manifestExtra: '<item id="notes" href="Text/notes.html" media-type="application/xhtml+xml"/>',
      spineExtra: '<itemref idref="notes"/>',
    ));
    expect(doc.chapters, hasLength(1));
  });

  test('tên file khác hoa/thường vẫn tìm được', () {
    final doc = EpubParser.parse(_epub(rename: {'OEBPS/Text/c1.xhtml': 'OEBPS/text/C1.xhtml'}));
    expect(doc.chapters.first.blocks.first.text, 'Chương một');
  });

  test('br trong đoạn thơ giữ xuống dòng, script/style bị bỏ', () {
    final doc = EpubParser.parse(_epub(
      c1Body: '<style>p{}</style><p>Dòng một<br/>Dòng hai</p><script>x()</script>',
    ));
    expect(doc.chapters.first.blocks.first.text, 'Dòng một\nDòng hai');
  });

  test('nhiều chương theo thứ tự spine', () {
    final doc = EpubParser.parse(_epub(
      manifestExtra: '<item id="c2" href="Text/c2.xhtml" media-type="application/xhtml+xml"/>',
      spineExtra: '<itemref idref="c2"/>',
      files: {'OEBPS/Text/c2.xhtml': '<html><body><h2>Hai</h2><p>Nội dung hai.</p></body></html>'},
    ));
    expect(doc.chapters.map((c) => c.title).toList(), ['Mở đầu', 'Hai']);
    expect(doc.plainText, contains('Nội dung hai.'));
  });

  test('file không phải zip báo lỗi dễ hiểu', () {
    expect(() => EpubParser.parse(Uint8List.fromList([1, 2, 3])), throwsA(isA<EpubFormatException>()));
  });

  test('EPUB có DRM (mã hoá file nội dung) báo lỗi DRM', () {
    final bytes = _epub(files: {
      'META-INF/encryption.xml':
          '<encryption><EncryptedData><CipherData><CipherReference URI="OEBPS/Text/c1.xhtml"/></CipherData></EncryptedData></encryption>',
    });
    expect(
      () => EpubParser.parse(bytes),
      throwsA(predicate((e) => e is EpubFormatException && e.message == EpubParser.drmMessage)),
    );
  });

  test('chỉ mã hoá font nhúng thì vẫn đọc được', () {
    final bytes = _epub(files: {
      'META-INF/encryption.xml':
          '<encryption><EncryptedData><CipherData><CipherReference URI="OEBPS/Fonts/a.otf"/></CipherData></EncryptedData></encryption>',
    });
    expect(EpubParser.parse(bytes).chapters, hasLength(1));
  });

  test('imageSizeOf đọc được kích thước PNG', () {
    expect(imageSizeOf(_png), (width: 1, height: 1));
    expect(imageSizeOf(Uint8List.fromList([0, 1, 2])), isNull);
  });
}
