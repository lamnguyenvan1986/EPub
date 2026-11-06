import 'package:libri_audio/models/reader_content.dart';
import 'package:libri_audio/services/tts_service.dart';

/// Một đoạn trong hàng đợi TTS, kèm khoảng khối nó đọc (để tô sáng trên trình đọc).
class ReaderTtsSegment {
  final String text;
  final int chapter;
  final int startBlock;
  final int endBlock;

  const ReaderTtsSegment(this.text, this.chapter, this.startBlock, this.endBlock);
}

/// Tạo hàng đợi TTS từ [ReaderDocument], dùng chung cho EPUB, MOBI và PDF.
///
/// Mỗi khối chữ là một hoặc nhiều đoạn TTS ([TtsService.splitText] chia khối dài
/// và tách theo dòng), mọi phần đều trỏ về đúng khối đó để tô sáng chính xác.
/// Ảnh bị bỏ qua.
List<ReaderTtsSegment> buildTtsSegments(ReaderDocument document) {
  final segments = <ReaderTtsSegment>[];
  for (int c = 0; c < document.chapters.length; c++) {
    final blocks = document.chapters[c].blocks;
    for (int i = 0; i < blocks.length; i++) {
      if (!blocks[i].isText) continue;
      for (final chunk in TtsService.splitText(blocks[i].text!)) {
        segments.add(ReaderTtsSegment(chunk, c, i, i));
      }
    }
  }
  return segments;
}

/// Đoạn đầu tiên đọc tới khối [block] của chương [chapter] (hoặc đoạn sau đó).
int segmentIndexFor(List<ReaderTtsSegment> segments, int chapter, int block) {
  for (int i = 0; i < segments.length; i++) {
    final s = segments[i];
    if (s.chapter > chapter || (s.chapter == chapter && s.endBlock >= block)) return i;
  }
  return segments.isEmpty ? 0 : segments.length - 1;
}
