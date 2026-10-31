# Kiến trúc

App dùng Flutter với `provider` + `ChangeNotifier`. Màn hình đọc state từ provider; provider và màn hình gọi xuống các service (singleton) để đọc file, lưu dữ liệu và phát TTS.

```
Screens / Widgets  ──watch──▶  Providers (ChangeNotifier)
        │                             │
        └──────────────┬──────────────┘
                       ▼
                   Services  ──▶  Hive, SharedPreferences, flutter_tts, sherpa-onnx, just_audio, audio_service, Google Drive
```

## Thư mục `lib/`

```
lib/
├── main.dart                     # Khởi tạo StorageService, TtsService, AudioService; đăng ký provider
├── models/                       # Book, Highlight, Playlist (Hive, file .g.dart sinh tự động)
├── providers/
│   ├── book_provider.dart        # Thư viện sách: thêm/xoá, tiến độ đọc, nhập từ Drive
│   ├── theme_provider.dart       # Sáng/tối/theo hệ thống
│   ├── highlight_provider.dart   # Đánh dấu và ghi chú (đã đăng ký, chưa có UI dùng)
│   └── playlist_provider.dart    # Danh sách nghe (đã đăng ký, chưa có UI dùng)
├── services/
│   ├── storage_service.dart      # Hive box + SharedPreferences
│   ├── tts_service.dart          # Hàng đợi đoạn, tốc độ, giọng, chia đoạn; chọn bộ đọc (máy/offline/cloud)
│   ├── tts_audio_handler.dart    # audio_service: thông báo, tai nghe, màn hình khoá
│   ├── neural_tts/               # Bộ đọc ngoài giọng máy (xem mục "Bộ đọc")
│   │   ├── neural_tts_engine.dart    # TtsEngineType, SynthesizedAudio, interface NeuralTtsEngine
│   │   ├── neural_tts_player.dart    # Chia câu, tổng hợp trước câu sau, phát bằng just_audio
│   │   ├── cloud_tts_engine.dart     # Azure Speech và Google Cloud TTS qua REST
│   │   ├── offline_voices.dart       # Danh sách giọng Piper tiếng Việt và URL tải
│   │   ├── offline_tts.dart          # Export có điều kiện: offline_tts_io (mobile) / offline_tts_stub (web)
│   │   ├── offline_tts_io.dart       # Tải, giải nén giọng; sherpa-onnx chạy trong isolate riêng
│   │   └── audio_source*.dart        # Bytes -> AudioSource: file tạm (mobile), data URI (web)
│   ├── mobi_parser.dart          # Đọc MOBI/AZW (PalmDB, nén PalmDOC và HUFF/CDIC), trích text và ảnh theo chương
│   ├── epub_repair.dart          # Sửa OPF/manifest EPUB lỗi để epubx mở được
│   ├── drive_service.dart        # Google Sign-In + Drive API (tắt trên web)
│   └── firebase_service.dart     # Chưa được gọi ở đâu, Firebase chưa khởi tạo
├── screens/
│   ├── home_screen.dart          # Danh sách sách
│   ├── file_import_screen.dart   # Nhập từ máy hoặc Google Drive
│   ├── book_reader_screen.dart   # Đọc EPUB/PDF/MOBI và chế độ nghe
│   ├── search_screen.dart        # Tìm trong nội dung text của sách
│   ├── tts_settings_screen.dart  # Giọng đọc: chọn bộ đọc, tải giọng offline, nhập key cloud
│   └── settings_screen.dart      # Giọng, tốc độ, cao độ, theme
├── widgets/                      # book_item, pdf_viewer (pdfrx), voice_selector, tts_engine_settings, audio_*, highlight_widget
└── utils/
    ├── constants.dart
    └── file_picker_web_options_{stub,web}.dart   # Tuỳ chọn file_picker riêng cho web (import có điều kiện)
```

## Lưu trữ

**Hive boxes** (mở trong `StorageService.init()`):

| Box | Nội dung |
|-----|----------|
| `books` | Thông tin sách |
| `reading_states` | Vị trí đọc theo sách |
| `highlights` | Đánh dấu, ghi chú |
| `playlists` | Danh sách nghe |
| `file_bytes` | Nội dung file sách trên web (không có đường dẫn file) |

**SharedPreferences:** `voice_id`, `reading_speed`, `pitch`, `theme_mode`, `last_dir`, `tts_engine`, `offline_voice_id`, `azure_voice`, `azure_region`, `google_voice`.

**flutter_secure_storage:** `azure_tts_key`, `google_tts_key` (key API do người dùng nhập).

**Giọng offline** tải về `<app support>/tts_voices/vits-piper-<id>/` (model `.onnx`, `tokens.txt`, `espeak-ng-data`). Audio tạo ra ghi vào `<temp>/tts_audio/`.

## Đọc sách

`BookReaderScreen._loadBook()` lấy bytes file (từ đường dẫn, hoặc box `file_bytes` trên web) rồi chọn theo loại:

- **EPUB:** `katbook_epub_reader` (bên trong là epubx). Nếu mở lỗi, `EpubRepair.repair()` sửa OPF/manifest và mở lại; nếu vẫn lỗi thì hiện lý do từ thư viện.
- **PDF:** `pdfrx` để hiển thị và trích text.
- **MOBI/AZW:** `MobiParser` trích nội dung theo chương thành các khối (`MobiBlock`: đoạn văn hoặc ảnh), hiển thị bằng text reader của app. Ảnh lấy từ record ảnh theo `recindex` (MOBI) hoặc `kindle:embed` (KF8), chỉ giữ JPEG/PNG/GIF/BMP. `MobiChapter.paragraphs` chỉ gồm chữ, dùng cho TTS và lưu vị trí. Nén HUFF/CDIC giải bằng `HuffCdicReader` (chỉ dùng số nguyên dưới 2^53 nên chạy đúng trên web). File có DRM báo lỗi, không giải mã.

## Luồng nghe (TTS)

1. `_buildSegments()` lấy text theo chương/đoạn và chia bằng `TtsService.splitText` (giới hạn độ dài của engine Android).
2. `TtsService.speakQueue()` đọc lần lượt từng đoạn; khi một đoạn xong thì đọc đoạn tiếp, màn hình cập nhật vị trí qua callback và lưu tiến độ.
3. Trên Android/iOS, `TtsAudioHandler` (audio_service) hiện thông báo, nhận play/pause/next/prev từ tai nghe và màn hình khoá. `wakelock_plus` giữ máy không ngủ khi đang nghe.
4. Trên web, trước lần đọc đầu tiên app tải lại danh sách giọng của trình duyệt để chọn đúng giọng `vi-VN`.

## Bộ đọc

`TtsService.engineType` chọn một trong bốn bộ đọc (lưu ở `tts_engine`):

| Bộ đọc | Cách chạy | Nền tảng |
|--------|-----------|----------|
| Giọng của máy | flutter_tts | Tất cả |
| Giọng offline (Piper VAIS1000) | sherpa-onnx trong isolate riêng, ghi WAV | Android/iOS (web chưa có) |
| Microsoft Azure | REST `<region>.tts.speech.microsoft.com`, trả MP3 | Tất cả (web chưa thử với key thật) |
| Google Cloud | REST `texttospeech.googleapis.com` với API key, trả MP3 | Tất cả (CORS cho phép) |

Với ba bộ đọc sau, `_speakCurrent()` gọi `NeuralTtsPlayer.speak()`: đoạn được chia nhỏ (300 ký tự cho offline, 1000 cho cloud), câu kế tiếp được tổng hợp trong lúc câu hiện tại đang phát, audio phát bằng just_audio. Tốc độ đổi bằng `AudioPlayer.setSpeed` (giữ cao độ), nên không cần tổng hợp lại; cao độ không áp dụng cho các bộ đọc này. Engine được tạo lúc đọc lần đầu và bỏ đi khi đổi cài đặt.

Nếu engine lỗi (thiếu key, mất mạng, chưa tải giọng), `TtsService` đọc tiếp bằng giọng máy cho đến lần bấm đọc sau, lưu lỗi ở `engineError` và gọi `onEngineError` (màn đọc sách hiện SnackBar).

`sherpa_onnx` ghim ở 1.13.8: từ 2.0.0 thư viện bỏ espeak-ng nên model Piper không đọc được text thường. Hai giọng Piper tiếng Việt khác (`25hours_single`, `vivos`) không có ký hiệu thanh điệu trong `tokens.txt` nên đọc mất dấu, vì vậy chỉ dùng VAIS1000.

Tốc độ: flutter_tts trên Android/iOS coi 0.5 là bình thường, nên `TtsService` nhân tốc độ với 0.5 trên mobile và giữ nguyên trên web.

## Khác biệt theo nền tảng

| | Android/iOS | Web |
|--|-------------|-----|
| Lưu file sách | Đường dẫn file | Bytes trong Hive (`file_bytes`) |
| Google Drive | Có (cần OAuth thật) | Tắt |
| Phát nền, màn hình khoá | Có | Không |
| Giọng offline (sherpa-onnx) | Có (tải 64 MB) | Không |
| Giọng cloud Azure/Google | Có | Có (Google đã thử; Azure chưa thử) |
| Chọn file | file_picker mặc định | Không lọc đuôi, không coi `focus` là huỷ (Safari iOS) |
