/// Giọng Piper tiếng Việt chạy offline bằng sherpa-onnx.
///
/// File model lấy từ bản phát hành tts-models của sherpa-onnx, tải về khi
/// người dùng chọn (không đóng gói vào app).
class OfflineVoice {
  final String id;
  final String label;
  final String description;
  /// Dung lượng tải về (file nén), MB.
  final int sizeMb;

  /// Thư mục của giọng trong kho rhasspy/piper-voices trên Hugging Face (bản web).
  final String hfDir;

  const OfflineVoice(this.id, this.label, this.description, this.sizeMb, this.hfDir);

  /// Tên thư mục trong file nén, cũng là tên file trên GitHub.
  String get archiveName => 'vits-piper-$id';

  String get modelFileName => '$id.onnx';

  String get downloadUrl =>
      'https://github.com/k2-fsa/sherpa-onnx/releases/download/tts-models/$archiveName.tar.bz2';

  /// Bản web tải model gốc của Piper từ Hugging Face (cho phép CORS, GitHub thì không).
  String get webModelUrl =>
      'https://huggingface.co/rhasspy/piper-voices/resolve/main/$hfDir/$modelFileName';

  String get webConfigUrl => '$webModelUrl.json';
}

// Chỉ dùng VAIS1000: hai giọng Piper tiếng Việt khác (25hours_single, vivos)
// không có ký hiệu thanh điệu trong tokens.txt nên đọc mất dấu.
const List<OfflineVoice> offlineViVoices = [
  OfflineVoice('vi_VN-vais1000-medium', 'VAIS1000',
      'Giọng Piper tiếng Việt, âm thanh 22 kHz', 64, 'vi/vi_VN/vais1000/medium'),
];

OfflineVoice offlineVoiceById(String? id) =>
    offlineViVoices.firstWhere((v) => v.id == id, orElse: () => offlineViVoices.first);
