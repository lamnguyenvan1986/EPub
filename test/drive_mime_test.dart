import 'package:flutter_test/flutter_test.dart';
import 'package:libri_audio/services/drive_service.dart';

void main() {
  group('DriveService.isBookFileName', () {
    test('nhận các đuôi sách', () {
      for (final name in ['a.pdf', 'b.EPUB', 'c.mobi', 'd.azw', 'e.AZW3']) {
        expect(DriveService.isBookFileName(name), isTrue, reason: name);
      }
    });

    test('bỏ qua file khác', () {
      for (final name in ['notes.txt', 'photo.jpg', 'archive.zip', 'azw3']) {
        expect(DriveService.isBookFileName(name), isFalse, reason: name);
      }
    });
  });

  group('DriveService.resolveBookMimeType', () {
    test('file AZW3 bị Drive gán octet-stream được nhận là MOBI', () {
      expect(
        DriveService.resolveBookMimeType('book.azw3', 'application/octet-stream'),
        'application/x-mobipocket-ebook',
      );
    });

    test('giữ MIME của Drive khi tên file không có đuôi', () {
      expect(
        DriveService.resolveBookMimeType('book', 'application/pdf'),
        'application/pdf',
      );
    });

    test('ưu tiên đuôi file', () {
      expect(
        DriveService.resolveBookMimeType('book.epub', 'application/zip'),
        'application/epub+zip',
      );
    });
  });
}
