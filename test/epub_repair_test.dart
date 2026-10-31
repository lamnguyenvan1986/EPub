import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:katbook_epub_reader/katbook_epub_reader.dart';
import 'package:libri_audio/services/epub_repair.dart';

/// EPUB 3 tối thiểu; [navProps] là thuộc tính properties của mục nav.
/// [extraItems] thêm vào manifest, [rename] đổi tên file trong zip.
Uint8List _epub3({
  String? navProps,
  bool withNcx = false,
  String extraItems = '',
  Map<String, String> rename = const {},
}) {
  final manifest = StringBuffer()
    ..write('<item id="c1" href="c1.xhtml" media-type="application/xhtml+xml"/>')
    ..write(extraItems);
  if (navProps != null) {
    manifest.write('<item id="nav" href="nav.xhtml" media-type="application/xhtml+xml" properties="$navProps"/>');
  }
  if (withNcx) {
    manifest.write('<item id="ncx" href="toc.ncx" media-type="application/x-dtbncx+xml"/>');
  }
  final files = <String, String>{
    'mimetype': 'application/epub+zip',
    'META-INF/container.xml':
        '<?xml version="1.0"?><container version="1.0" xmlns="urn:oasis:names:tc:opendocument:xmlns:container"><rootfiles><rootfile full-path="OEBPS/content.opf" media-type="application/oebps-package+xml"/></rootfiles></container>',
    'OEBPS/content.opf':
        '<?xml version="1.0"?><package xmlns="http://www.idpf.org/2007/opf" version="3.0" unique-identifier="id"><metadata xmlns:dc="http://purl.org/dc/elements/1.1/"><dc:title>Sách thử</dc:title><dc:identifier id="id">x1</dc:identifier><dc:language>vi</dc:language></metadata><manifest>$manifest</manifest><spine${withNcx ? ' toc="ncx"' : ''}><itemref idref="c1"/></spine></package>',
    'OEBPS/c1.xhtml':
        '<?xml version="1.0" encoding="utf-8"?><html xmlns="http://www.w3.org/1999/xhtml"><head><title>Chương 1</title></head><body><p>Xin chào.</p></body></html>',
    'OEBPS/nav.xhtml':
        '<?xml version="1.0" encoding="utf-8"?><html xmlns="http://www.w3.org/1999/xhtml" xmlns:epub="http://www.idpf.org/2007/ops"><head><title>Mục lục</title></head><body><nav epub:type="toc"><ol><li><a href="c1.xhtml">Chương 1</a></li></ol></nav></body></html>',
    'OEBPS/toc.ncx':
        '<?xml version="1.0"?><ncx xmlns="http://www.daisy.org/z3986/2005/ncx/" version="2005-1"><head><meta name="dtb:uid" content="x1"/></head><docTitle><text>Sách thử</text></docTitle><navMap><navPoint id="n1" playOrder="1"><navLabel><text>Chương 1</text></navLabel><content src="c1.xhtml"/></navPoint></navMap></ncx>',
  };
  final archive = Archive();
  files.forEach((name, content) =>
      archive.addFile(ArchiveFile.bytes(rename[name] ?? name, utf8.encode(content))));
  return ZipEncoder().encodeBytes(archive);
}

Future<bool> _opens(Uint8List bytes) async {
  final controller = KatbookEpubController();
  final ok = await controller.openBook(bytes);
  controller.dispose();
  return ok;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('mục nav có nhiều thuộc tính: lỗi trước khi sửa, mở được sau khi sửa', () async {
    final bytes = _epub3(navProps: 'nav scripted');
    expect(await _opens(bytes), isFalse);

    final repaired = EpubRepair.repair(bytes);
    expect(repaired, isNotNull);
    expect(await _opens(repaired!), isTrue);
  });

  test('EPUB 3 không có nav nhưng có NCX: đọc mục lục từ NCX', () async {
    final bytes = _epub3(withNcx: true);
    expect(await _opens(bytes), isFalse);

    final repaired = EpubRepair.repair(bytes);
    expect(repaired, isNotNull);
    expect(await _opens(repaired!), isTrue);
  });

  test('manifest khai báo file không có trong zip: thêm file rỗng', () async {
    final bytes = _epub3(
      navProps: 'nav',
      extraItems: '<item id="notes" href="notes.html" media-type="application/xhtml+xml"/>',
    );
    expect(await _opens(bytes), isFalse);

    final repaired = EpubRepair.repair(bytes);
    expect(repaired, isNotNull);
    expect(await _opens(repaired!), isTrue);
  });

  test('tên file trong zip khác hoa/thường: chép sang đúng tên, giữ nội dung', () async {
    final bytes = _epub3(navProps: 'nav', rename: {'OEBPS/c1.xhtml': 'OEBPS/C1.xhtml'});
    expect(await _opens(bytes), isFalse);

    final repaired = EpubRepair.repair(bytes)!;
    final controller = KatbookEpubController();
    expect(await controller.openBook(repaired), isTrue);
    expect(controller.paragraphs, isNotEmpty);
    controller.dispose();
  });

  test('EPUB hợp lệ thì không cần sửa', () {
    expect(EpubRepair.repair(_epub3(navProps: 'nav')), isNull);
  });

  test('dữ liệu không phải zip trả về null', () {
    expect(EpubRepair.repair(Uint8List.fromList([1, 2, 3])), isNull);
  });
}
