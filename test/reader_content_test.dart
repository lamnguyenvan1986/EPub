import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libri_audio/models/reader_content.dart';
import 'package:libri_audio/providers/reader_settings_provider.dart';
import 'package:libri_audio/services/mobi_parser.dart';
import 'package:libri_audio/services/pdf_text_extractor.dart';
import 'package:libri_audio/services/reader_tts_segments.dart';
import 'package:libri_audio/widgets/reader/reader_paginator.dart';
import 'package:libri_audio/widgets/reader/reader_view.dart';
import 'package:provider/provider.dart';

final Uint8List _png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==',
);

ReaderDocument _doc({int chapters = 2, int paragraphs = 30}) => ReaderDocument(
      title: 'Thử',
      chapters: [
        for (int c = 0; c < chapters; c++)
          ReaderChapter('Chương ${c + 1}', [
            ReaderBlock.heading('Chương ${c + 1}', level: 1),
            for (int p = 0; p < paragraphs; p++)
              ReaderBlock.paragraph('Đoạn $p của chương ${c + 1}. ' * 6),
            ReaderBlock.image(_png),
          ]),
      ],
    );

void main() {
  group('PDF dạng chữ', () {
    test('ghép dòng bị ngắt thành đoạn, tách đoạn ở dòng cuối câu ngắn', () {
      const page = 'Đây là một câu khá dài bị ngắt ở cuối dòng thứ nhất\n'
          'và tiếp tục ở dòng thứ hai rồi kết thúc.\n'
          'Đoạn mới bắt đầu ở đây và cũng khá dài như dòng đầu\n'
          'tiên của trang.';
      expect(PdfTextExtractor.reflowParagraphs(page), [
        'Đây là một câu khá dài bị ngắt ở cuối dòng thứ nhất và tiếp tục ở dòng thứ hai rồi kết thúc.',
        'Đoạn mới bắt đầu ở đây và cũng khá dài như dòng đầu tiên của trang.',
      ]);
    });

    test('dòng trống, mục danh sách và gạch nối cuối dòng', () {
      const page = 'Tiêu đề\n\nMở đầu danh sách như sau đây là các mục\n- mục một\n- mục hai\nThis is a much longer line with some infor-\nmation.';
      expect(PdfTextExtractor.reflowParagraphs(page), [
        'Tiêu đề',
        'Mở đầu danh sách như sau đây là các mục',
        '- mục một',
        '- mục hai',
        'This is a much longer line with some information.',
      ]);
    });
  });

  test('hàng đợi TTS: mỗi khối chữ một đoạn, bỏ ảnh, khối dài chia nhỏ cùng trỏ về khối', () {
    final long = 'Câu khá dài để thử chia nhỏ. ' * 300;
    final doc = ReaderDocument(title: 't', chapters: [
      ReaderChapter('A', [
        const ReaderBlock.heading('Tiêu đề'),
        const ReaderBlock.paragraph('Một.'),
        ReaderBlock.image(_png),
        ReaderBlock.paragraph(long),
      ]),
      const ReaderChapter('B', [ReaderBlock.paragraph('Ba.')]),
    ]);
    final segments = buildTtsSegments(doc);
    expect(segments.take(2).map((s) => s.text), ['Tiêu đề', 'Một.']);
    final longParts = segments.where((s) => s.chapter == 0 && s.startBlock == 3).toList();
    expect(longParts.length, greaterThan(1));
    expect(longParts.map((s) => s.text).join(' '), long.trim());
    expect((segments.last.chapter, segments.last.startBlock), (1, 0));
    expect(segmentIndexFor(segments, 0, 2), 2); // ảnh: đọc từ khối chữ kế tiếp
    expect(segmentIndexFor(segments, 1, 0), segments.length - 1);
  });

  test('PDF: câu thơ và dòng tên tác giả ngắn không bị dồn vào một đoạn', () {
    const page = 'Truyện Kiều\nNguyễn Du\nTrăm năm trong cõi người ta,\nChữ tài chữ mệnh khéo là ghét nhau.\n'
        'Đầu đời Gia Tĩnh triều Minh, bốn phương phẳng lặng, hai kinh vững vàng. Có nhà viên ngoại\n'
        'họ Vương, gia tư nghĩ cũng thường thường bậc trung, một trai con thứ rốt lòng, Vương Quan\n'
        'là chữ, nối dòng nho gia.';
    expect(PdfTextExtractor.reflowParagraphs(page), [
      'Truyện Kiều',
      'Nguyễn Du',
      'Trăm năm trong cõi người ta,',
      'Chữ tài chữ mệnh khéo là ghét nhau.',
      'Đầu đời Gia Tĩnh triều Minh, bốn phương phẳng lặng, hai kinh vững vàng. Có nhà viên ngoại '
          'họ Vương, gia tư nghĩ cũng thường thường bậc trung, một trai con thứ rốt lòng, Vương Quan '
          'là chữ, nối dòng nho gia.',
    ]);
  });

  test('MOBI: xuống dòng trong mã HTML không cắt đoạn; tên chương đầu chương thành tiêu đề', () {
    final chapters = MobiParser.htmlToChapters('<h2>Hồi 1</h2><p>Câu dài bị\nxuống dòng\r\ntrong file.</p><p>Thơ<br/>dòng hai</p>');
    expect(chapters.single.paragraphs, ['Hồi 1', 'Câu dài bị xuống dòng trong file.', 'Thơ', 'dòng hai']);
    final doc = MobiBook(title: 'M', chapters: chapters).toReaderDocument();
    expect(doc.chapters.single.blocks.first.type, ReaderBlockType.heading);
  });

  test('MOBI chuyển sang mô hình chung, bỏ ảnh không có trong file', () {
    final mobi = MobiBook(
      title: 'M',
      chapters: [MobiChapter('C1', const [MobiBlock.text('Chữ'), MobiBlock.image(1), MobiBlock.image(9)])],
      images: {1: _png},
    );
    final doc = mobi.toReaderDocument();
    expect(doc.chapters.single.blocks.map((b) => b.type).toList(), [ReaderBlockType.paragraph, ReaderBlockType.image]);
  });

  test('ReaderSettings lưu/đọc JSON và chặn giá trị lạ', () {
    const s = ReaderSettings(fontSize: 22, theme: ReaderTheme.sepia, layout: ReaderLayout.paginate, justify: true);
    expect(ReaderSettings.fromJson(s.toJson()), s);
    final bad = ReaderSettings.fromJson(const {'fontSize': 500, 'fontFamily': 'Comic', 'theme': 'x'});
    expect(bad.fontSize, 36);
    expect(bad.fontFamily, 'NotoSans');
    expect(bad.theme, ReaderTheme.app);
  });

  testWidgets('chia trang: không mất chữ, đoạn dài nối tiếp qua trang', (tester) async {
    final chapter = _doc(chapters: 1).chapters.first;
    const styles = ReaderStyles(ReaderSettings(fontSize: 18), Colors.black);
    final pages = ReaderPaginator.paginate(chapter, const Size(300, 400), styles);
    expect(pages.length, greaterThan(3));

    // Ghép lại các phần chữ của mỗi khối phải ra đúng khối gốc
    final pieces = <int, StringBuffer>{};
    var images = 0;
    for (final page in pages) {
      for (final item in page.items) {
        if (item.isImage) {
          images++;
          continue;
        }
        expect(item.start, (pieces[item.block]?.length ?? 0));
        (pieces[item.block] ??= StringBuffer()).write(chapter.blocks[item.block].text!.substring(item.start, item.end));
      }
    }
    expect(images, 1);
    for (final entry in pieces.entries) {
      expect(entry.value.toString(), chapter.blocks[entry.key].text);
    }
  });

  Widget app(Widget child, {ReaderSettings settings = const ReaderSettings()}) => ChangeNotifierProvider(
        create: (_) => ReaderSettingsProvider(initial: settings),
        child: MaterialApp(home: Scaffold(body: child)),
      );

  testWidgets('chế độ cuộn: hiện chương, tô sáng khối đang đọc và theo sang chương khác', (tester) async {
    final doc = _doc();
    final positions = <(int, int)>[];
    Widget view(ReaderHighlight? h) => app(ReaderView(
          document: doc,
          settings: const ReaderSettings(),
          highlight: h,
          onPositionChanged: (c, b) => positions.add((c, b)),
        ));

    await tester.pumpWidget(view(null));
    await tester.pumpAndSettle();
    expect(find.text('Chương 1'), findsOneWidget);
    expect(find.byType(DecoratedBox), findsNothing);

    await tester.pumpWidget(view(const ReaderHighlight(1, 20, 21)));
    await tester.pumpAndSettle();
    expect(positions.last.$1, 1);
    final highlighted = find.ancestor(
      of: find.textContaining('Đoạn 19 của chương 2'),
      matching: find.byType(DecoratedBox),
    );
    expect(highlighted, findsOneWidget);
    expect(tester.getRect(find.textContaining('Đoạn 19 của chương 2')).top, lessThan(600));
  });

  testWidgets('chế độ lật trang: chạm mép phải sang trang sau, theo khối TTS', (tester) async {
    final doc = _doc(chapters: 1);
    const settings = ReaderSettings(layout: ReaderLayout.paginate);
    Widget view(ReaderHighlight? h) => app(ReaderView(document: doc, settings: settings, highlight: h), settings: settings);

    await tester.pumpWidget(view(null));
    await tester.pumpAndSettle();
    final first = find.textContaining(RegExp(r'^\d+/\d+$'));
    expect(tester.widget<Text>(first).data, startsWith('1/'));

    await tester.tapAt(Offset(tester.getSize(find.byType(ReaderView)).width - 10, 300));
    await tester.pumpAndSettle();
    expect(tester.widget<Text>(first).data, startsWith('2/'));

    await tester.pumpWidget(view(const ReaderHighlight(0, 29, 29)));
    await tester.pumpAndSettle();
    expect(find.textContaining('Đoạn 28 của chương 1'), findsWidgets);
  });

  testWidgets('đổi từ cuộn sang lật trang giữ vị trí đang đọc, lật trang vẫn chạy', (tester) async {
    final doc = _doc(chapters: 1);
    Widget view(ReaderSettings settings) => app(ReaderView(document: doc, settings: settings), settings: settings);

    await tester.pumpWidget(view(const ReaderSettings()));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView), const Offset(0, -1500));
    await tester.pumpAndSettle();

    await tester.pumpWidget(view(const ReaderSettings(layout: ReaderLayout.paginate)));
    await tester.pumpAndSettle();
    final footer = find.textContaining(RegExp(r'^\d+/\d+$'));
    final before = int.parse(tester.widget<Text>(footer).data!.split('/').first);
    expect(before, greaterThan(1));
    // Trang đang hiện đúng là trang footer báo: không bắt đầu bằng tiêu đề chương
    expect(find.text('Chương 1'), findsOneWidget); // chỉ còn tên chương ở chân trang

    await tester.tapAt(Offset(tester.getSize(find.byType(ReaderView)).width - 10, 300));
    await tester.pumpAndSettle();
    expect(tester.widget<Text>(footer).data, startsWith('${before + 1}/'));
  });

  testWidgets('đổi cỡ chữ ở chế độ lật trang: trang hiện ra khớp số trang ở chân trang', (tester) async {
    final doc = _doc(chapters: 1);
    Widget view(ReaderSettings settings) => app(ReaderView(document: doc, settings: settings), settings: settings);
    const paged = ReaderSettings(layout: ReaderLayout.paginate);

    await tester.pumpWidget(view(paged));
    await tester.pumpAndSettle();
    final size = tester.getSize(find.byType(ReaderView));
    for (int i = 0; i < 3; i++) {
      await tester.tapAt(Offset(size.width - 10, 300));
      await tester.pumpAndSettle();
    }
    await tester.pumpWidget(view(paged.copyWith(fontSize: 26)));
    await tester.pumpAndSettle();

    final footer = find.textContaining(RegExp(r'^\d+/\d+$'));
    final page = int.parse(tester.widget<Text>(footer).data!.split('/').first);
    final pageView = tester.widget<PageView>(find.byType(PageView));
    expect(pageView.controller!.page!.round() + 1, page);
  });
}
