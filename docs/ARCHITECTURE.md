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
├── models/
│   ├── book_model.dart, highlight_model.dart, playlist_model.dart  # Hive (file .g.dart sinh tự động)
│   └── reader_content.dart       # Mô hình nội dung chung: ReaderDocument > ReaderChapter > ReaderBlock (đoạn, tiêu đề, ảnh)
├── providers/
│   ├── book_provider.dart        # Thư viện sách: thêm/xoá, tiến độ đọc, nhập từ Drive
│   ├── theme_provider.dart       # Sáng/tối/theo hệ thống
│   ├── reader_settings_provider.dart  # Tùy chọn hiển thị trình đọc (font, cỡ, giãn dòng, lề, nền, cuộn/lật trang)
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
│   │   ├── offline_tts.dart          # Export có điều kiện: offline_tts_io (mobile) / offline_tts_web (web)
│   │   ├── offline_tts_io.dart       # Tải, giải nén giọng; sherpa-onnx chạy trong isolate riêng
│   │   ├── offline_tts_web.dart      # Gọi window.libriPiper (web/piper/) qua dart:js_interop
│   │   └── audio_source*.dart        # Bytes -> AudioSource: file tạm (mobile), data URI (web)
│   ├── mobi_parser.dart          # Đọc MOBI/AZW/PRC (PalmDB, nén PalmDOC và HUFF/CDIC), trích text và ảnh theo chương; PalmDOC thuần đọc như chữ trơn
│   ├── epub_parser.dart          # Đọc EPUB 2/3 (zip, OPF, nav/NCX, XHTML) thành ReaderDocument; HtmlBlockExtractor
│   ├── pdf_text_extractor.dart   # Trích chữ PDF theo trang, ghép dòng thành đoạn (xem dạng chữ, TTS)
│   ├── reader_tts_segments.dart  # Hàng đợi TTS từ ReaderDocument, mỗi đoạn trỏ về khối để tô sáng
│   ├── drive_service.dart        # Google Sign-In + Drive API (web: chỉ xin quyền qua Google Identity Services)
│   └── firebase_service.dart     # Chưa được gọi ở đâu, Firebase chưa khởi tạo
├── screens/
│   ├── home_screen.dart          # Danh sách sách
│   ├── file_import_screen.dart   # Nhập từ máy hoặc Google Drive
│   ├── book_reader_screen.dart   # Đọc EPUB/PDF/MOBI, thanh nghe TTS, mục lục
│   ├── search_screen.dart        # Tìm trong nội dung text của sách
│   ├── tts_settings_screen.dart  # Giọng đọc: chọn bộ đọc, tải giọng offline, nhập key cloud
│   └── settings_screen.dart      # Giọng, tốc độ, cao độ, theme
├── widgets/
│   ├── reader/
│   │   ├── reader_view.dart          # Trình đọc chung: cuộn hoặc lật trang, tô sáng khối đang đọc
│   │   ├── reader_paginator.dart     # Chia chương thành trang bằng TextPainter
│   │   └── reader_settings_sheet.dart  # Bảng tùy chọn hiển thị (nút Tt)
│   └── book_item, voice_selector, tts_engine_settings, audio_*, highlight_widget
└── utils/
    ├── constants.dart
    └── file_picker_web_options_{stub,web}.dart   # Tuỳ chọn file_picker riêng cho web (import có điều kiện)
```

Ngoài `lib/`, giọng offline trên web nằm ở `web/piper/`: `piper_bridge.js` (tạo `window.libriPiper`, nạp cùng trang) và `piper_worker.js` (Web Worker chạy espeak-ng + onnxruntime-web). Thư viện trong `web/piper/vendor/` do `tool/fetch_piper_web.sh` tải lúc build.

## Lưu trữ

**Hive boxes** (mở trong `StorageService.init()`):

| Box | Nội dung |
|-----|----------|
| `books` | Thông tin sách |
| `reading_states` | Vị trí đọc theo sách |
| `highlights` | Đánh dấu, ghi chú |
| `playlists` | Danh sách nghe |
| `file_bytes` | Nội dung file sách trên web (không có đường dẫn file) |

**SharedPreferences:** `voice_id`, `reading_speed`, `pitch`, `theme_mode`, `reader_settings`, `last_dir`, `tts_engine`, `offline_voice_id`, `azure_voice`, `azure_region`, `google_voice`.

**flutter_secure_storage:** `azure_tts_key`, `google_tts_key` (key API do người dùng nhập).

**Giọng offline** tải về `<app support>/tts_voices/vits-piper-<id>/` (model `.onnx`, `tokens.txt`, `espeak-ng-data`). Audio tạo ra ghi vào `<temp>/tts_audio/`. Trên web, model `.onnx` và `.onnx.json` lưu trong Cache Storage `libri-piper-voices` của trình duyệt.

## Đọc sách

Mọi sách dạng chữ đi qua cùng một đường: parser của từng định dạng tạo `ReaderDocument` (chương > khối: đoạn văn, tiêu đề, ảnh), rồi `ReaderView` hiển thị theo `ReaderSettings` của người đọc. Vì vậy EPUB, MOBI và PDF dạng chữ có cùng font, cỡ chữ, giãn dòng, lề, màu nền, chế độ cuộn/lật trang, và cùng cách tô sáng khi nghe.

`BookReaderScreen._loadBook()` lấy bytes file (từ đường dẫn, hoặc box `file_bytes` trên web) rồi chọn theo loại:

- **EPUB:** `EpubParser.parse` (chạy bằng `compute`). Tự đọc zip, `container.xml`, OPF, spine; tên chương lấy từ nav (EPUB 3), NCX, tiêu đề đầu chương hoặc `<title>`. XHTML đổi thành khối bằng `HtmlBlockExtractor` (bỏ script/style/ẩn, giữ `<br>` thành xuống dòng, ảnh `<img>` và `<svg><image>`). Chịu được lỗi hay gặp: `properties="nav ..."`, file khai báo nhưng thiếu trong zip, tên file khác hoa/thường hoặc mã hoá URL, thẻ tự đóng kiểu XHTML. File có DRM (`encryption.xml` mã hoá file nội dung, không tính font) báo lỗi rõ.
- **MOBI/AZW:** `MobiParser` trích chương thành `MobiBlock` (đoạn hoặc ảnh), `MobiBook.toReaderDocument()` đổi sang mô hình chung. Ảnh lấy từ record ảnh theo `recindex` (MOBI) hoặc `kindle:embed` (KF8), chỉ giữ JPEG/PNG/GIF/BMP. Nén HUFF/CDIC giải bằng `HuffCdicReader` (chỉ dùng số nguyên dưới 2^53 nên chạy đúng trên web). File có DRM báo lỗi, không giải mã.
- **PDF:** mặc định xem nguyên trang bằng `pdfrx`. Nút "Xem dạng chữ" gọi `PdfTextExtractor.extract`: mỗi trang thành một chương "Trang N", dòng được ghép lại thành đoạn (`reflowParagraphs`: tách đoạn ở dòng trống, dòng cuối câu ngắn, mục danh sách; nối từ bị gạch nối). PDF ảnh scan không có lớp chữ thì báo không xem dạng chữ được.

Vị trí đọc lưu là (chương, khối trong chương); với PDF chương là số trang (từ 0), nên hai chế độ xem PDF dùng chung vị trí.

`ReaderView` hiển thị một chương mỗi lần:

- **Cuộn:** `ListView.builder`, cuối chương có nút sang chương trước/sau. Nhảy tới một khối bằng cách ước lượng offset rồi `Scrollable.ensureVisible` khi khối đã được dựng.
- **Lật trang:** `ReaderPaginator` đo chữ bằng `TextPainter` (cùng kiểu chữ và `textScaler`) và cắt đoạn dài tại đầu dòng; ảnh giữ tỉ lệ nhờ `imageSizeOf` (đọc kích thước từ header PNG/JPEG/GIF/BMP/WebP). Lật bằng vuốt hoặc chạm mép trái/phải; vuốt qua trang cuối sang chương sau. Mỗi lần chia trang lại (đổi cỡ chữ, xoay màn hình) tạo PageView mới, vì PageView giữ offset pixel cũ khi đổi controller.

Tùy chọn hiển thị lưu ở SharedPreferences `reader_settings` (JSON). Font có sẵn: Noto Sans và Liberation Serif (`assets/fonts/`, đủ dấu tiếng Việt, giấy phép OFL).

## Luồng nghe (TTS)

1. `buildTtsSegments()` tạo hàng đợi từ `ReaderDocument` (PDF: trích chữ trước nếu chưa có): mỗi khối chữ chia bằng `TtsService.splitText`, mọi phần trỏ về (chương, khối) của nó; ảnh bị bỏ qua.
2. `TtsService.speakQueue()` đọc lần lượt từng đoạn. Khi một đoạn bắt đầu, màn hình tô sáng khối đó trên `ReaderView` (tự cuộn/lật tới, sang chương nếu cần), PDF xem nguyên trang thì lật tới trang đang đọc, rồi lưu tiến độ.
3. Nghe chạy ngay trong màn đọc: thanh điều khiển ở dưới (chương trước/sau, đọc/dừng, giọng, tắt).
4. Trên Android/iOS, `TtsAudioHandler` (audio_service) hiện thông báo, nhận play/pause/next/prev từ tai nghe và màn hình khoá. `wakelock_plus` giữ máy không ngủ khi đang nghe.
5. Trên web, trước lần đọc đầu tiên app tải lại danh sách giọng của trình duyệt để chọn đúng giọng `vi-VN`.

## Bộ đọc

`TtsService.engineType` chọn một trong bốn bộ đọc (lưu ở `tts_engine`):

| Bộ đọc | Cách chạy | Nền tảng |
|--------|-----------|----------|
| Giọng của máy | flutter_tts | Tất cả |
| Giọng offline (Piper VAIS1000) | Mobile: sherpa-onnx trong isolate riêng, ghi WAV. Web: piper_phonemize + onnxruntime-web trong Web Worker, trả WAV | Tất cả |
| Microsoft Azure | REST `<region>.tts.speech.microsoft.com`, trả MP3 | Tất cả (web chưa thử với key thật) |
| Google Cloud | REST `texttospeech.googleapis.com` với API key, trả MP3 | Tất cả (CORS cho phép) |

Với ba bộ đọc sau, `_speakCurrent()` gọi `NeuralTtsPlayer.speak()`: đoạn được chia nhỏ (300 ký tự cho offline, 1000 cho cloud), câu kế tiếp được tổng hợp trong lúc câu hiện tại đang phát, audio phát bằng just_audio. Tốc độ đổi bằng `AudioPlayer.setSpeed` (giữ cao độ), nên không cần tổng hợp lại; cao độ không áp dụng cho các bộ đọc này. Engine được tạo lúc đọc lần đầu và bỏ đi khi đổi cài đặt.

Nếu engine lỗi (thiếu key, mất mạng, chưa tải giọng), `TtsService` đọc tiếp bằng giọng máy cho đến lần bấm đọc sau, lưu lỗi ở `engineError` và gọi `onEngineError` (màn đọc sách hiện SnackBar).

`sherpa_onnx` ghim ở 1.13.8: từ 2.0.0 thư viện bỏ espeak-ng nên model Piper không đọc được text thường. Hai giọng Piper tiếng Việt khác (`25hours_single`, `vivos`) không có ký hiệu thanh điệu trong `tokens.txt` nên đọc mất dấu, vì vậy chỉ dùng VAIS1000.

Giọng offline trên web: model tải từ Hugging Face `rhasspy/piper-voices` (GitHub release không cho CORS). Worker dùng espeak-ng gốc của Piper (`@diffusionstudio/piper-wasm`) để đổi text thành phoneme theo `phoneme_id_map` trong `.onnx.json`, rồi chạy model bằng onnxruntime-web 1.18 một luồng (GitHub Pages không bật cross-origin isolation). Trên máy tính, một câu 3 giây tổng hợp mất khoảng 0,5 giây.

Tốc độ: flutter_tts trên Android/iOS coi 0.5 là bình thường, nên `TtsService` nhân tốc độ với 0.5 trên mobile và giữ nguyên trên web.

## Khác biệt theo nền tảng

| | Android/iOS | Web |
|--|-------------|-----|
| Lưu file sách | Đường dẫn file | Bytes trong Hive (`file_bytes`) |
| Google Drive | Có (cần OAuth thật) | Có (cần OAuth client Web, xin quyền lại sau khoảng 1 giờ) |
| Phát nền, màn hình khoá | Có | Không |
| Giọng offline Piper | Có, sherpa-onnx (tải 64 MB) | Có, onnxruntime-web (tải 64 MB + 40 MB thư viện lần đầu) |
| Giọng cloud Azure/Google | Có | Có (Google đã thử; Azure chưa thử) |
| Chọn file | file_picker mặc định | Không lọc đuôi, không coi `focus` là huỷ (Safari iOS) |
