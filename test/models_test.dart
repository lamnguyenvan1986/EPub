import 'package:flutter_test/flutter_test.dart';
import 'package:libri_audio/models/book_model.dart';
import 'package:libri_audio/models/highlight_model.dart';
import 'package:libri_audio/models/playlist_model.dart';

void main() {
  group('Model Tests', () {
    test('Book model - Create and convert toMap', () {
      final book = Book(
        title: 'Test Book',
        fileType: 'epub',
        filePath: '/path/to/book.epub',
      );

      expect(book.id, isNotNull);
      expect(book.title, 'Test Book');
      expect(book.fileType, 'epub');

      final map = book.toMap();
      expect(map['title'], 'Test Book');
      expect(map['fileType'], 'epub');
    });

    test('Book model - CopyWith', () {
      final book = Book(
        title: 'Original Title',
        fileType: 'epub',
        author: 'Author 1',
      );

      final updatedBook = book.copyWith(
        title: 'Updated Title',
        author: 'Author 2',
      );

      expect(updatedBook.title, 'Updated Title');
      expect(updatedBook.author, 'Author 2');
      expect(book.title, 'Original Title');
    });

    test('Highlight model - Create and convert toMap', () {
      final highlight = Highlight(
        bookId: 'book123',
        text: 'This is a highlight',
        note: 'Important note',
        chapterIndex: 5,
        positionStart: 100,
        positionEnd: 150,
      );

      expect(highlight.bookId, 'book123');
      expect(highlight.text, 'This is a highlight');
      expect(highlight.note, 'Important note');

      final map = highlight.toMap();
      expect(map['bookId'], 'book123');
      expect(map['note'], 'Important note');
    });

    test('Playlist model - Create and convert toMap', () {
      final playlist = Playlist(
        name: 'My Favorites',
        bookIds: ['book1', 'book2', 'book3'],
      );

      expect(playlist.name, 'My Favorites');
      expect(playlist.bookIds.length, 3);

      final map = playlist.toMap();
      expect(map['name'], 'My Favorites');
      expect(map['bookIds'], isA<List<dynamic>>());
    });

    test('Book model - From Map', () {
      final originalBook = Book(
        title: 'Test Book',
        fileType: 'pdf',
        author: 'Test Author',
      );

      final map = originalBook.toMap();
      final restoredBook = Book.fromMap(map);

      expect(restoredBook.title, originalBook.title);
      expect(restoredBook.fileType, originalBook.fileType);
      expect(restoredBook.author, originalBook.author);
    });

    test('Book model - Reading state', () {
      final book = Book(
        title: 'Test Book',
        fileType: 'epub',
        chapterIndex: 3,
        position: 1500,
      );

      expect(book.chapterIndex, 3);
      expect(book.position, 1500);
    });
  });

  group('Validation Tests', () {
    test('Book - Required fields', () {
      expect(() => Book(
        title: '',
        fileType: 'epub',
      ), throwsA(isA<AssertionError>()));

      expect(() => Book(
        title: 'Test',
        fileType: '',
      ), throwsA(isA<AssertionError>()));
    });

    test('Highlight - Required fields', () {
      expect(() => Highlight(
        bookId: '',
        text: 'Test',
        chapterIndex: 0,
        positionStart: 0,
        positionEnd: 0,
      ), throwsA(isA<AssertionError>()));
    });

    test('Playlist - Required fields', () {
      final playlist = Playlist(
        name: 'Test Playlist',
        bookIds: [],
      );

      expect(playlist.name, 'Test Playlist');
    });
  });
}
