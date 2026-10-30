import 'package:flutter_test/flutter_test.dart';
import 'package:libri_audio/services/tts_service.dart';

void main() {
  group('TtsService.splitText', () {
    test('keeps short paragraphs as separate chunks', () {
      final chunks = TtsService.splitText('Đoạn một.\n\nĐoạn hai.\nĐoạn ba.');
      expect(chunks, ['Đoạn một.', 'Đoạn hai.', 'Đoạn ba.']);
    });

    test('drops empty text', () {
      expect(TtsService.splitText('  \n\n  '), isEmpty);
    });

    test('splits long paragraphs under the max length', () {
      const sentence = 'Đây là một câu khá dài để kiểm tra việc chia đoạn. ';
      final text = List.filled(200, sentence).join();
      final chunks = TtsService.splitText(text, maxLength: 500);

      expect(chunks.length, greaterThan(1));
      for (final chunk in chunks) {
        expect(chunk.length, lessThanOrEqualTo(500));
      }
      expect(chunks.join(' ').replaceAll(RegExp(r'\s+'), ' '),
          text.trim().replaceAll(RegExp(r'\s+'), ' '));
    });

    test('splits a single very long sentence on spaces', () {
      final text = List.filled(300, 'chữ').join(' ');
      final chunks = TtsService.splitText(text, maxLength: 100);

      for (final chunk in chunks) {
        expect(chunk.length, lessThanOrEqualTo(100));
      }
      expect(chunks.join(' '), text);
    });
  });
}
