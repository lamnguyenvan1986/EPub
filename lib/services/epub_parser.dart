import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;
import 'package:libri_audio/models/reader_content.dart';

class EpubFormatException implements Exception {
  final String message;
  const EpubFormatException(this.message);

  @override
  String toString() => message;
}

/// Đọc file EPUB 2/3 thành [ReaderDocument] (chương, đoạn văn, tiêu đề, ảnh).
///
/// Tự đọc zip, OPF và XHTML thay vì dùng thư viện đọc EPUB có sẵn, để EPUB
/// dùng chung trình render với MOBI và PDF dạng chữ. Cố đọc được cả file lỗi
/// hay gặp: `properties="nav ..."`, manifest khai báo file không có trong zip,
/// tên file khác hoa/thường hoặc khác mã hoá URL, thẻ tự đóng kiểu XHTML.
class EpubParser {
  static const String drmMessage =
      'Sách EPUB này có DRM (khoá bản quyền) nên không mở được. Hãy dùng file EPUB không có DRM.';

  /// Dùng được với `compute()`.
  static ReaderDocument parse(Uint8List bytes) {
    final Archive archive;
    try {
      archive = ZipDecoder().decodeBytes(bytes);
    } catch (e) {
      throw const EpubFormatException('File EPUB bị hỏng (không giải nén được)');
    }
    final zip = _Zip(archive);

    final opfPath = _findOpfPath(zip);
    if (opfPath == null) {
      throw const EpubFormatException('File EPUB thiếu mục lục nội dung (content.opf)');
    }
    final opf = zip.readString(opfPath)!;
    final opfDir = _dirOf(opfPath);

    // Manifest: id -> (đường dẫn, media-type, properties)
    final manifest = <String, _Item>{};
    for (final m in RegExp(r'<(?:\w+:)?item\b[^>]*>').allMatches(opf)) {
      final tag = m.group(0)!;
      final id = _attr(tag, 'id');
      final href = _attr(tag, 'href');
      if (id == null || href == null) continue;
      manifest[id] = _Item(
        _resolve(opfDir, href),
        _attr(tag, 'media-type') ?? '',
        (_attr(tag, 'properties') ?? '').split(RegExp(r'\s+')),
      );
    }

    if (_hasContentDrm(zip, manifest)) {
      throw const EpubFormatException(drmMessage);
    }

    // Spine theo thứ tự đọc
    final spine = <_Item>[];
    for (final m in RegExp(r'<(?:\w+:)?itemref\b[^>]*>').allMatches(opf)) {
      final item = manifest[_attr(m.group(0)!, 'idref')];
      if (item != null && item.mediaType.contains('html')) spine.add(item);
    }
    if (spine.isEmpty) {
      // Spine trống: đọc mọi file HTML theo thứ tự manifest
      spine.addAll(manifest.values.where((i) => i.mediaType.contains('html') && !i.properties.contains('nav')));
    }

    final tocTitles = _readToc(zip, opf, manifest);

    final chapters = <ReaderChapter>[];
    for (final item in spine) {
      final source = zip.readString(item.path);
      if (source == null) continue; // file khai báo nhưng thiếu trong zip
      final doc = html_parser.parse(_fixSelfClosing(source));
      final blocks = HtmlBlockExtractor(
        resolveImage: (src) => zip.readBytes(_resolve(_dirOf(item.path), src)),
      ).extract(doc.body ?? doc.documentElement!);
      if (blocks.isEmpty) continue;

      var title = tocTitles[item.path.toLowerCase()];
      title ??= blocks.where((b) => b.type == ReaderBlockType.heading).map((b) => b.text!).firstOrNull;
      title ??= _clean(doc.querySelector('title')?.text ?? '');
      if (title.isEmpty) title = 'Chương ${chapters.length + 1}';
      chapters.add(ReaderChapter(title, blocks));
    }

    if (chapters.isEmpty) {
      throw const EpubFormatException('Không tìm thấy nội dung đọc được trong file EPUB');
    }

    final title = _clean(_xmlText(RegExp(r'<dc:title\b[^>]*>(.*?)</dc:title>', dotAll: true).firstMatch(opf)?.group(1)));
    final author = _clean(_xmlText(RegExp(r'<dc:creator\b[^>]*>(.*?)</dc:creator>', dotAll: true).firstMatch(opf)?.group(1)));
    return ReaderDocument(
      title: title.isEmpty ? 'Không có tiêu đề' : title,
      author: author.isEmpty ? null : author,
      chapters: chapters,
    );
  }

  static String? _findOpfPath(_Zip zip) {
    final container = zip.readString('META-INF/container.xml');
    if (container != null) {
      final path = RegExp(r'''full-path\s*=\s*["']([^"']+)["']''').firstMatch(container)?.group(1);
      if (path != null && zip.contains(_decode(path))) return _decode(path);
    }
    // Thiếu container.xml: lấy file .opf đầu tiên
    return zip.names.where((n) => n.toLowerCase().endsWith('.opf')).firstOrNull;
  }

  /// `META-INF/encryption.xml` mã hoá file nội dung (không chỉ font nhúng) nghĩa là có DRM.
  static bool _hasContentDrm(_Zip zip, Map<String, _Item> manifest) {
    final xml = zip.readString('META-INF/encryption.xml');
    if (xml == null) return false;
    for (final m in RegExp(r'''<(?:\w+:)?CipherReference\b[^>]*URI\s*=\s*["']([^"']+)["']''').allMatches(xml)) {
      final path = _decode(m.group(1)!).toLowerCase();
      final isFont = RegExp(r'\.(ttf|otf|woff2?)$').hasMatch(path) ||
          manifest.values.any((i) => i.path.toLowerCase() == path && i.mediaType.contains('font'));
      if (!isFont) return true;
    }
    return false;
  }

  /// Tên chương từ mục lục (nav của EPUB 3, hoặc NCX). Khoá là đường dẫn file viết thường.
  static Map<String, String> _readToc(_Zip zip, String opf, Map<String, _Item> manifest) {
    final titles = <String, String>{};
    void add(String baseDir, String href, String label) {
      final path = _resolve(baseDir, href).toLowerCase();
      final text = _clean(label);
      if (text.isNotEmpty) titles.putIfAbsent(path, () => text);
    }

    final nav = manifest.values.where((i) => i.properties.contains('nav')).firstOrNull;
    final navSource = nav == null ? null : zip.readString(nav.path);
    if (navSource != null) {
      final doc = html_parser.parse(_fixSelfClosing(navSource));
      final navs = doc.querySelectorAll('nav');
      final toc = navs.where((n) => (n.attributes['epub:type'] ?? '').contains('toc')).firstOrNull ??
          navs.firstOrNull;
      for (final a in toc?.querySelectorAll('a[href]') ?? const <dom.Element>[]) {
        add(_dirOf(nav!.path), a.attributes['href']!, a.text);
      }
    }

    final ncxId = RegExp(r'''<(?:\w+:)?spine\b[^>]*\btoc\s*=\s*["']([^"']+)["']''').firstMatch(opf)?.group(1);
    final ncx = manifest[ncxId] ??
        manifest.values.where((i) => i.mediaType.contains('dtbncx')).firstOrNull;
    final ncxSource = ncx == null ? null : zip.readString(ncx.path);
    if (ncxSource != null) {
      final pattern = RegExp(
        r'<navLabel\b[^>]*>\s*<text\b[^>]*>(.*?)</text>\s*</navLabel>\s*<content\b[^>]*\bsrc\s*=\s*"([^"]*)"',
        dotAll: true,
      );
      for (final m in pattern.allMatches(ncxSource)) {
        add(_dirOf(ncx!.path), m.group(2)!, _xmlText(m.group(1)));
      }
    }
    return titles;
  }

  /// Parser HTML5 không hiểu thẻ tự đóng kiểu XHTML (`<title/>`, `<div/>`),
  /// có thể nuốt cả phần sau làm nội dung. Đổi thành cặp thẻ mở/đóng.
  static String _fixSelfClosing(String source) {
    const voidTags = {'br', 'hr', 'img', 'input', 'meta', 'link', 'area', 'base', 'col', 'embed', 'source', 'track', 'wbr', 'param'};
    return source.replaceAllMapped(RegExp(r'<([A-Za-z][\w:.-]*)(\s[^<>]*?)?/>'), (m) {
      final tag = m.group(1)!;
      if (voidTags.contains(tag.toLowerCase())) return m.group(0)!;
      return '<$tag${m.group(2) ?? ''}></$tag>';
    });
  }

  static String? _attr(String tag, String name) {
    final m = RegExp('\\s${RegExp.escape(name)}\\s*=\\s*(["\'])(.*?)\\1', dotAll: true).firstMatch(tag);
    return m == null ? null : _xmlText(m.group(2));
  }

  static String _xmlText(String? raw) {
    if (raw == null || raw.isEmpty) return '';
    return html_parser.parseFragment(raw.replaceAll(RegExp(r'<!\[CDATA\[|\]\]>'), '')).text ?? '';
  }

  static String _clean(String text) => text.replaceAll(RegExp(r'\s+'), ' ').trim();

  static String _dirOf(String path) => path.contains('/') ? path.substring(0, path.lastIndexOf('/')) : '';

  static String _decode(String path) {
    try {
      return Uri.decodeFull(path);
    } catch (e) {
      return path;
    }
  }

  /// Đường dẫn trong zip của [href] (tương đối với [baseDir]), bỏ phần `#...`.
  static String _resolve(String baseDir, String href) {
    var path = href;
    final hash = path.indexOf('#');
    if (hash >= 0) path = path.substring(0, hash);
    path = _decode(path);
    if (path.startsWith('/')) return path.substring(1);
    final parts = <String>[];
    for (final part in (baseDir.isEmpty ? path : '$baseDir/$path').split('/')) {
      if (part.isEmpty || part == '.') continue;
      if (part == '..') {
        if (parts.isNotEmpty) parts.removeLast();
      } else {
        parts.add(part);
      }
    }
    return parts.join('/');
  }
}

class _Item {
  final String path;
  final String mediaType;
  final List<String> properties;
  const _Item(this.path, this.mediaType, this.properties);
}

/// Tra file trong zip theo tên, không phân biệt hoa/thường và mã hoá URL.
class _Zip {
  final Map<String, ArchiveFile> _byName = {};
  final Map<String, ArchiveFile> _byLower = {};

  _Zip(Archive archive) {
    for (final f in archive.files) {
      if (!f.isFile) continue;
      _byName[f.name] = f;
      _byLower.putIfAbsent(EpubParser._decode(f.name).toLowerCase(), () => f);
    }
  }

  Iterable<String> get names => _byName.keys;

  ArchiveFile? _find(String path) => _byName[path] ?? _byLower[EpubParser._decode(path).toLowerCase()];

  bool contains(String path) => _find(path) != null;

  Uint8List? readBytes(String path) {
    final file = _find(path);
    if (file == null) return null;
    try {
      return file.readBytes();
    } catch (e) {
      return null; // file trong zip hỏng: bỏ qua
    }
  }

  String? readString(String path) {
    final bytes = readBytes(path);
    if (bytes == null) return null;
    // Bỏ BOM UTF-8
    final start = bytes.length >= 3 && bytes[0] == 0xEF && bytes[1] == 0xBB && bytes[2] == 0xBF ? 3 : 0;
    return utf8.decode(Uint8List.sublistView(bytes, start), allowMalformed: true);
  }
}

/// Chuyển DOM HTML thành các [ReaderBlock]: đoạn văn, tiêu đề, ảnh theo đúng thứ tự.
///
/// Dùng cho EPUB; [resolveImage] nhận giá trị `src` của ảnh và trả về bytes.
class HtmlBlockExtractor {
  final Uint8List? Function(String src) resolveImage;

  HtmlBlockExtractor({required this.resolveImage});

  static const _blockTags = {
    'p', 'div', 'section', 'article', 'aside', 'header', 'footer', 'main', 'blockquote', 'pre',
    'li', 'ul', 'ol', 'dl', 'dt', 'dd', 'table', 'tr', 'td', 'th', 'tbody', 'thead', 'figure',
    'figcaption', 'hr', 'body', 'center', 'address', 'nav',
  };
  static const _skipTags = {'script', 'style', 'head', 'title', 'noscript', 'template', 'rt', 'rp'};

  final List<ReaderBlock> _blocks = [];
  final StringBuffer _buffer = StringBuffer();

  List<ReaderBlock> extract(dom.Element root) {
    _blocks.clear();
    _buffer.clear();
    _walk(root, pre: false);
    _flush();
    return List.of(_blocks);
  }

  void _flush() {
    final text = _buffer
        .toString()
        .split('\n')
        .map((l) => l.replaceAll(RegExp(r'[ \t\r\f\u00A0]+'), ' ').trim())
        .where((l) => l.isNotEmpty)
        .join('\n');
    _buffer.clear();
    if (text.isNotEmpty) _blocks.add(ReaderBlock.paragraph(text));
  }

  void _addImage(String? src) {
    if (src == null || src.isEmpty || src.startsWith('data:')) {
      final data = src == null ? null : _dataUri(src);
      if (data == null) return;
      _flush();
      _blocks.add(ReaderBlock.image(data));
      return;
    }
    final bytes = resolveImage(src);
    if (bytes == null || bytes.isEmpty) return;
    _flush();
    _blocks.add(ReaderBlock.image(bytes));
  }

  static Uint8List? _dataUri(String src) {
    try {
      final data = UriData.parse(src);
      return data.mimeType.startsWith('image/') ? data.contentAsBytes() : null;
    } catch (e) {
      return null;
    }
  }

  void _walk(dom.Node node, {required bool pre}) {
    if (node is dom.Text) {
      final text = pre ? node.data : node.data.replaceAll(RegExp(r'\s+'), ' ');
      _buffer.write(text);
      return;
    }
    if (node is! dom.Element) {
      for (final child in node.nodes) {
        _walk(child, pre: pre);
      }
      return;
    }

    final tag = (node.localName ?? '').toLowerCase();
    if (_skipTags.contains(tag)) return;
    if ((node.attributes['epub:type'] ?? '').contains('pagebreak')) return;
    if (node.attributes['hidden'] != null || (node.attributes['style'] ?? '').replaceAll(' ', '').contains('display:none')) {
      return;
    }

    switch (tag) {
      case 'br':
        _buffer.write('\n');
        return;
      case 'img':
        _addImage(node.attributes['src']);
        return;
      case 'image': // ảnh trong <svg>
        _addImage(node.attributes['xlink:href'] ?? node.attributes['href']);
        return;
      case 'svg':
        for (final img in node.querySelectorAll('image')) {
          _addImage(img.attributes['xlink:href'] ?? img.attributes['href']);
        }
        return;
    }

    final headingLevel = RegExp(r'^h([1-6])$').firstMatch(tag);
    if (headingLevel != null && node.querySelector('img, image') == null) {
      _flush();
      final text = node.text.replaceAll(RegExp(r'\s+'), ' ').trim();
      if (text.isNotEmpty) {
        _blocks.add(ReaderBlock.heading(text, level: int.parse(headingLevel.group(1)!)));
      }
      return;
    }

    final isBlock = _blockTags.contains(tag) || headingLevel != null;
    if (isBlock) _flush();
    for (final child in node.nodes) {
      _walk(child, pre: pre || tag == 'pre');
    }
    if (isBlock) _flush();
  }
}
