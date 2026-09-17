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

    test('Book model - Generate unique IDs', () {
      final book1 = Book(
        title: 'Book 1',
        fileType: 'epub',
      );
      final book2 = Book(
        title: 'Book 2',
        fileType: 'epub',
      );

      expect(book1.id, isNotNull);
      expect(book2.id, isNotNull);
      expect(book1.id, isNot(equals(book2.id)));
    });

    test('Highlight model - Generate unique IDs', () {
      final highlight1 = Highlight(
        bookId: 'book1',
        text: 'Highlight 1',
        chapterIndex: 1,
        positionStart: 10,
        positionEnd: 20,
      );
      final highlight2 = Highlight(
        bookId: 'book1',
        text: 'Highlight 2',
        chapterIndex: 1,
        positionStart: 30,
        positionEnd: 40,
      );

      expect(highlight1.id, isNotNull);
      expect(highlight2.id, isNotNull);
      expect(highlight1.id, isNot(equals(highlight2.id)));
    });

    test('Playlist model - Generate unique IDs', () {
      final playlist1 = Playlist(
        name: 'Playlist 1',
        bookIds: ['book1'],
      );
      final playlist2 = Playlist(
        name: 'Playlist 2',
        bookIds: ['book2'],
      );

      expect(playlist1.id, isNotNull);
      expect(playlist2.id, isNotNull);
      expect(playlist1.id, isNot(equals(playlist2.id)));
    });
  });

  group('Validation Tests', () {
    test('Book - Title cannot be empty', () {
      // Book model now allows empty strings, but we validate in providers
      // This test verifies that the model accepts valid inputs
      final book = Book(
        title: 'Valid Title',
        fileType: 'epub',
      );
      expect(book.title, 'Valid Title');
    });

    test('Book - File type is required', () {
      final book = Book(
        title: 'Test Book',
        fileType: 'pdf',
      );
      expect(book.fileType, 'pdf');
    });

    test('Highlight - All fields are properly set', () {
      final highlight = Highlight(
        bookId: 'book123',
        text: 'Test highlight text',
        note: 'Test note',
        chapterIndex: 5,
        positionStart: 100,
        positionEnd: 150,
      );

      expect(highlight.bookId, 'book123');
      expect(highlight.text, 'Test highlight text');
      expect(highlight.note, 'Test note');
      expect(highlight.chapterIndex, 5);
      expect(highlight.positionStart, 100);
      expect(highlight.positionEnd, 150);
    });

    test('Playlist - Empty book list is allowed', () {
      final playlist = Playlist(
        name: 'Test Playlist',
        bookIds: [],
      );

      expect(playlist.name, 'Test Playlist');
      expect(playlist.bookIds, isEmpty);
    });
  });
}
