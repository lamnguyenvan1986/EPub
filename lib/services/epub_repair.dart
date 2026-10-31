import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';

/// Sửa những lỗi mục lục hay gặp trong file EPUB thực tế mà thư viện
/// epubx (dùng bên trong katbook_epub_reader) không chấp nhận.
///
/// - EPUB 3: epubx chỉ tìm mục `nav` khi thuộc tính `properties` đúng bằng
///   `"nav"`, nên `properties="nav scripted"` hay `"cover-image nav"` bị báo
///   "TOC item, not found". Sửa thành `properties="nav"`.
/// - EPUB 3 không có mục `nav` nhưng có file NCX: đánh dấu là EPUB 2 để
///   epubx đọc mục lục từ NCX.
/// - Manifest khai báo file không có trong zip ("file ... not found in
///   archive"): nếu có file trùng tên khác hoa/thường hoặc khác mã hoá URL thì
///   chép sang đúng tên; nếu thiếu hẳn thì thêm file rỗng để vẫn đọc được phần
///   còn lại của sách.
///
/// Trả về bytes mới, hoặc `null` nếu không có gì để sửa.
class EpubRepair {
  static Uint8List? repair(Uint8List bytes) {
    final Archive archive;
    try {
      archive = ZipDecoder().decodeBytes(bytes);
    } catch (e) {
      return null;
    }

    final opfPath = _findOpfPath(archive);
    if (opfPath == null) return null;
    final opfFile = archive.findFile(opfPath);
    if (opfFile == null) return null;

    final opf = utf8.decode(opfFile.content, allowMalformed: true);
    final fixed = fixOpf(opf);
    final added = _missingFiles(archive, opfPath, opf);
    if (fixed == null && added.isEmpty) return null;

    final out = Archive();
    for (final file in archive.files) {
      if (!file.isFile) continue;
      if (file.name == opfPath && fixed != null) {
        out.addFile(ArchiveFile.bytes(file.name, utf8.encode(fixed)));
      } else {
        final copy = ArchiveFile.bytes(file.name, file.content);
        // mimetype phải để không nén theo chuẩn EPUB
        if (file.name == 'mimetype') copy.compression = CompressionType.none;
        out.addFile(copy);
      }
    }
    added.forEach((name, content) => out.addFile(ArchiveFile.bytes(name, content)));
    return ZipEncoder().encodeBytes(out);
  }

  static const String _emptyXhtml =
      '<?xml version="1.0" encoding="utf-8"?><html xmlns="http://www.w3.org/1999/xhtml">'
      '<head><title></title></head><body></body></html>';

  /// Các file manifest khai báo nhưng zip không có, tính đường dẫn giống epubx
  /// (`ZipPathUtils.combine` trên href đã giải mã URL). Trả về tên file cần
  /// thêm và nội dung.
  static Map<String, List<int>> _missingFiles(Archive archive, String opfPath, String opf) {
    final names = {for (final f in archive.files) if (f.isFile) f.name: f};
    final byLowerName = <String, ArchiveFile>{};
    for (final f in names.values) {
      byLowerName.putIfAbsent(_normalize(f.name).toLowerCase(), () => f);
    }
    final opfDir = opfPath.contains('/') ? opfPath.substring(0, opfPath.lastIndexOf('/')) : '';

    final added = <String, List<int>>{};
    final hrefPattern = RegExp(r'''\bhref\s*=\s*(["'])([^"']*)\1''');
    final typePattern = RegExp(r'''\bmedia-type\s*=\s*(["'])([^"']*)\1''');
    for (final m in RegExp(r'<item\b[^>]*>').allMatches(opf)) {
      final item = m.group(0)!;
      final rawHref = hrefPattern.firstMatch(item)?.group(2);
      if (rawHref == null || rawHref.isEmpty) continue;
      final href = rawHref.replaceAll('&amp;', '&');

      final String expected;
      try {
        final decoded = Uri.decodeFull(href);
        expected = Uri.parse(opfDir.isEmpty ? decoded : '$opfDir/$decoded').normalizePath().path;
      } catch (e) {
        continue;
      }
      if (names.containsKey(expected) || added.containsKey(expected)) continue;

      final match = byLowerName[_normalize(expected).toLowerCase()];
      if (match != null) {
        added[expected] = match.content;
        continue;
      }
      final type = typePattern.firstMatch(item)?.group(2) ?? '';
      added[expected] = type.contains('html') ? utf8.encode(_emptyXhtml) : <int>[];
    }
    return added;
  }

  static String _normalize(String path) {
    try {
      return Uri.decodeFull(path);
    } catch (e) {
      return path;
    }
  }

  /// Sửa nội dung file OPF; trả về `null` nếu không cần sửa.
  static String? fixOpf(String opf) {
    final versionMatch = RegExp(r'<package\b[^>]*\bversion\s*=\s*"(\d)').firstMatch(opf);
    if (versionMatch == null || versionMatch.group(1) != '3') return null;

    final itemPattern = RegExp(r'<item\b[^>]*>');
    final propsPattern = RegExp(r'''\bproperties\s*=\s*(["'])([^"']*)\1''');
    var hasExactNav = false;
    var fixedNav = false;

    var result = opf.replaceAllMapped(itemPattern, (m) {
      final item = m.group(0)!;
      final props = propsPattern.firstMatch(item);
      if (props == null) return item;
      final tokens = props.group(2)!.trim().split(RegExp(r'\s+'));
      if (!tokens.contains('nav')) return item;
      if (tokens.length == 1) {
        hasExactNav = true;
        return item;
      }
      if (hasExactNav || fixedNav) return item;
      fixedNav = true;
      return item.replaceRange(props.start, props.end, 'properties="nav"');
    });

    if (fixedNav) return result;
    if (hasExactNav) return null;

    // Không có mục nav: dùng NCX nếu có
    final hasNcx = RegExp(r'<spine\b[^>]*\btoc\s*=').hasMatch(opf);
    if (!hasNcx) return null;
    result = opf.replaceRange(
      versionMatch.start,
      versionMatch.end,
      versionMatch.group(0)!.replaceFirst(RegExp(r'"3$'), '"2'),
    );
    return result;
  }

  static String? _findOpfPath(Archive archive) {
    final container = archive.findFile('META-INF/container.xml');
    if (container == null) return null;
    final xml = utf8.decode(container.content, allowMalformed: true);
    return RegExp(r'''full-path\s*=\s*["']([^"']+)["']''').firstMatch(xml)?.group(1);
  }
}
