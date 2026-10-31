# Kiến trúc

App dùng Flutter với `provider` + `ChangeNotifier`. Màn hình đọc state từ provider; provider và màn hình gọi xuống các service (singleton) để đọc file, lưu dữ liệu và phát TTS.

```
Screens / Widgets  ──watch──▶  Providers (ChangeNotifier)
        │                             │
        └──────────────┬──────────────┘
                       ▼
                   Services  ──▶  Hive, SharedPreferences, flutter_tts, audio_service, Google Drive
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
│   ├── tts_service.dart          # flutter_tts: hàng đợi đoạn, tốc độ, giọng, chia đoạn
│   ├── tts_audio_handler.dart    # audio_service: thông báo, tai nghe, màn hình khoá
│   ├── mobi_parser.dart          # Đọc MOBI/AZW (PalmDB, nén PalmDOC), trích text theo chương
│   ├── epub_repair.dart          # Sửa OPF/manifest EPUB lỗi để epubx mở được
│   ├── drive_service.dart        # Google Sign-In + Drive API (tắt trên web)
│   └── firebase_service.dart     # Chưa được gọi ở đâu, Firebase chưa khởi tạo
├── screens/
│   ├── home_screen.dart          # Danh sách sách
│   ├── file_import_screen.dart   # Nhập từ máy hoặc Google Drive
│   ├── book_reader_screen.dart   # Đọc EPUB/PDF/MOBI và chế độ nghe
│   ├── search_screen.dart        # Tìm trong nội dung text của sách
│   └── settings_screen.dart      # Giọng, tốc độ, cao độ, theme
├── widgets/                      # book_item, pdf_viewer (pdfrx), voice_selector, audio_*, highlight_widget
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

**SharedPreferences:** `voice_id`, `reading_speed`, `pitch`, `theme_mode`, `last_dir`.

## Đọc sách

`BookReaderScreen._loadBook()` lấy bytes file (từ đường dẫn, hoặc box `file_bytes` trên web) rồi chọn theo loại:

- **EPUB:** `katbook_epub_reader` (bên trong là epubx). Nếu mở lỗi, `EpubRepair.repair()` sửa OPF/manifest và mở lại; nếu vẫn lỗi thì hiện lý do từ thư viện.
- **PDF:** `pdfrx` để hiển thị và trích text.
- **MOBI/AZW:** `MobiParser` trích text theo chương, hiển thị bằng text reader của app. Không hỗ trợ DRM, nén HUFF/CDIC và ảnh.

## Luồng nghe (TTS)

1. `_buildSegments()` lấy text theo chương/đoạn và chia bằng `TtsService.splitText` (giới hạn độ dài của engine Android).
2. `TtsService.speakQueue()` đọc lần lượt từng đoạn; khi một đoạn xong thì đọc đoạn tiếp, màn hình cập nhật vị trí qua callback và lưu tiến độ.
3. Trên Android/iOS, `TtsAudioHandler` (audio_service) hiện thông báo, nhận play/pause/next/prev từ tai nghe và màn hình khoá. `wakelock_plus` giữ máy không ngủ khi đang nghe.
4. Trên web, trước lần đọc đầu tiên app tải lại danh sách giọng của trình duyệt để chọn đúng giọng `vi-VN`.

Tốc độ: flutter_tts trên Android/iOS coi 0.5 là bình thường, nên `TtsService` nhân tốc độ với 0.5 trên mobile và giữ nguyên trên web.

## Khác biệt theo nền tảng

| | Android/iOS | Web |
|--|-------------|-----|
| Lưu file sách | Đường dẫn file | Bytes trong Hive (`file_bytes`) |
| Google Drive | Có (cần OAuth thật) | Tắt |
| Phát nền, màn hình khoá | Có | Không |
| Chọn file | file_picker mặc định | Không lọc đuôi, không coi `focus` là huỷ (Safari iOS) |
