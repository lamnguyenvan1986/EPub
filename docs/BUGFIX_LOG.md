# Nhật ký sửa lỗi – LibriAudio

## 2026-10-30

Sửa các bug tìm được khi rà soát code. Số thứ tự (#) khớp với báo cáo phân tích bug.
Kiểm tra: `flutter analyze` (Flutter 3.47.9) từ 7 lỗi biên dịch xuống 0 lỗi (còn 2 info về tên hằng UPPER_SNAKE theo quy ước dự án).
Chưa chạy trên thiết bị thật; cần thử TTS và Google Drive trên Android/iOS.

### Lỗi build

| # | File | Lỗi | Cách sửa |
|---|------|-----|----------|
| 1 | `lib/providers/book_provider.dart` | Gọi `_drive.downloadFile/isAuthenticated/listPdfAndEpubFiles` trên `DriveService?`, getter `drive` che prefix import `drive` | Dùng `final DriveService _drive = DriveService()` (singleton), đổi getter thành `driveService` |
| 2 | `lib/services/drive_service.dart` | `GoogleSignIn()` không tồn tại ở google_sign_in 7.x | Dùng `GoogleSignIn.instance` và gọi `initialize()` một lần trước khi đăng nhập |
| 3 | `pubspec.yaml` | Khai báo `assets/icons/`, `assets/images/` không có trong repo | Bỏ khai báo assets không tồn tại |

### Crash khi chạy

| # | File | Lỗi | Cách sửa |
|---|------|-----|----------|
| 4 | `lib/services/storage_service.dart` | Class `ReadingState` khai báo lại, che mất model Hive nên `saveReadingState` ném `HiveError: unknown type` | Xoá class trùng, dùng `ReadingState` trong `book_model.dart`; `getReadingState` kiểm tra kiểu |
| 5 | `lib/services/storage_service.dart` | Chưa đăng ký `PlaylistAdapter` | Đăng ký adapter (có kiểm tra `isAdapterRegistered`) |
| 6 | `lib/screens/book_reader_screen.dart` | `String as ShareParams` luôn ném `TypeError` | Dùng `ShareParams(text: ...)` |
| 9 | `lib/widgets/voice_selector.dart` | `value` của Dropdown (`'vi-VN'`) không khớp item nào → assert | Loại tên giọng trùng, chỉ đặt `value` khi có trong danh sách, hiện "Giọng mặc định" khi chưa chọn |
| 30 | `lib/main.dart` | `StorageService.init()` lỗi bị nuốt, sau đó crash `LateInitializationError` | Hiển thị màn hình lỗi khởi động thay vì chạy tiếp |

### Text-to-Speech

| # | File | Lỗi | Cách sửa |
|---|------|-----|----------|
| 7 | `lib/services/tts_service.dart` | Đưa cả cuốn sách vào một lần `speak()` (Android giới hạn ~4000 ký tự) | Chia text thành hàng đợi đoạn ≤ 3000 ký tự (`splitText`), đọc nối tiếp bằng completion handler |
| 10 | `lib/services/tts_service.dart` | `isSpeaking` không về false khi đọc xong | Đăng ký completion/cancel/error handler |
| 11 | `lib/services/tts_service.dart` | Resume đọc lại từ đầu sách | Pause giữ vị trí đoạn, resume đọc tiếp từ đoạn hiện tại |
| 12, 13 | `lib/screens/book_reader_screen.dart` | Nút chuyển chương không điều hướng reader; trộn chỉ số paragraph và chương; tổng chương dùng sai danh sách | Dùng `KatbookEpubReaderState.jumpToChapter` qua `GlobalKey`, chỉ số chương lấy từ `flatChapters` |
| 12 | `lib/screens/book_reader_screen.dart` | Chế độ nghe luôn đọc lại từ đầu sách, bỏ qua vị trí đã lưu | Hàng đợi TTS gắn với chương/trang và paragraph; bắt đầu từ vị trí đang đọc, chuyển chương/trang khi nghe, lưu tiến độ theo từng đoạn; reader mở lại đúng vị trí (`initialPosition`) |
| 14 | `lib/screens/book_reader_screen.dart` | `autoPlay` chạy trước khi sách load xong | Bắt đầu nghe sau khi load xong |
| 15 | `lib/screens/book_reader_screen.dart` | Thoát màn hình vẫn tiếp tục đọc | `dispose()` dừng TTS và giải phóng `KatbookEpubController` |
| 16 | `lib/widgets/pdf_viewer.dart`, `book_reader_screen.dart` | PDF không có nút nghe | Thêm `onListen` vào `PdfViewer`, nghe PDF theo từng trang |
| 27 | `lib/services/tts_service.dart` | `setPitch` dùng giá trị chưa clamp | Dùng `_pitch` |
| 28 | `lib/services/tts_service.dart` | `setVoice` thiếu `locale` (Android cần) | Truyền cả `name` và `locale` |
| 29 | `lib/services/tts_service.dart`, `storage_service.dart` | Tốc độ, cao độ, giọng đọc không được lưu | Lưu/khôi phục qua SharedPreferences |
| 33 | `lib/services/tts_service.dart` | `setLanguage` gọi `toUpperCase()` | Truyền nguyên mã ngôn ngữ |

### Đọc sách, PDF, web

| # | File | Lỗi | Cách sửa |
|---|------|-----|----------|
| 17 | `lib/screens/book_reader_screen.dart` | PDF trên web là trang trắng (`Container()`) | Dùng `PdfViewer` (pdfrx) trên mọi nền tảng; chia sẻ trên web chỉ gửi text |
| 18 | `book_reader_screen.dart`, `file_import_screen.dart`, `book_provider.dart` | Web: bytes không được lưu, đọc sai khoá, import gọi `File(path)` | Import web đọc bytes từ `PlatformFile` và lưu theo id sách (`addBookFromBytes`); reader đọc theo id (có fallback khoá cũ) |
| 22 | `book_reader_screen.dart`, `file_import_screen.dart` | `setState` sau khi widget đã dispose | Kiểm tra `mounted` sau mỗi `await` |
| 23, 24 | `book_reader_screen.dart` | `PdfDocument` không được dispose; trích text toàn bộ PDF trước khi hiển thị; khối fallback trùng lặp | Chỉ trích text khi bắt đầu nghe, `dispose()` trong `finally`, bỏ khối trùng |
| 37 | `book_reader_screen.dart` | Text EPUB nối bằng dấu cách nên tìm kiếm trả về cả cuốn sách | Mỗi paragraph một dòng |
| 32 | `lib/screens/home_screen.dart` | Hai slider tốc độ đọc trùng nhau | Bỏ slider thừa |

### Google Drive và import

| # | File | Lỗi | Cách sửa |
|---|------|-----|----------|
| 8 | `drive_service.dart`, `main.dart`, `file_import_screen.dart` | Ba instance `DriveService` khác nhau; `Consumer<DriveService>` không rebuild | `DriveService` thành singleton `ChangeNotifier`, cung cấp bằng `ChangeNotifierProvider.value`; bỏ `dispose()` làm mất phiên đăng nhập |
| 19 | `lib/providers/book_provider.dart` | Kết quả `copyWith` bị bỏ nên sách Drive lưu tên file thay vì đường dẫn | Gán lại kết quả; sách đã có cũng được tải lại khi import từ Drive |
| 20 | `lib/services/drive_service.dart` | Token hết hạn sau 1 giờ, lỗi bị nuốt | Tự lấy token mới không cần UI (`authorizationForScopes`); lỗi danh sách hiển thị lên màn hình |
| 21 | `book_provider.dart`, `storage_service.dart` | Lưu đường dẫn file trong cache của file_picker | Copy file vào `Documents/books/` khi import |
| 25 | `lib/screens/file_import_screen.dart` | `_isConnecting` không reset khi đăng nhập thành công | Reset trong mọi nhánh |
| 26 | `lib/services/drive_service.dart` | File trùng tên ghi đè nhau; không phân trang; liệt kê cả file trong thùng rác | Lưu theo thư mục `books/drive_<id>/`; phân trang; lọc `trashed = false` |
| – | `lib/screens/file_import_screen.dart` | Màn Google Drive gọi lại API mỗi lần rebuild | Giữ `Future` trong state |

### Đợt 2 (cùng ngày): các bug còn lại và hỗ trợ MOBI

| # | File | Lỗi | Cách sửa |
|---|------|-----|----------|
| 31 | `lib/services/tts_audio_handler.dart` (mới), `main.dart`, `tts_service.dart`, `AndroidManifest.xml`, `MainActivity.kt` | TTS không phát nền; manifest khai báo service `.AudioService` không tồn tại | Dùng audio_service: foreground service + thông báo có Play/Pause/Trước/Sau, nút tai nghe và màn hình khoá chuyển chương/trang. Android: service/receiver đúng tên, quyền `FOREGROUND_SERVICE_MEDIA_PLAYBACK`, `MainActivity` kế thừa `AudioServiceActivity` (bỏ đăng ký plugin thủ công bị lặp). iOS: audio session category `playback` qua flutter_tts |
| 34 | `lib/services/tts_service.dart` | Tốc độ sai trên cả hai nền tảng: flutter_tts nhân đôi rate trên Android (1.0 của app = gấp đôi), iOS coi 0.5 là bình thường và 1.0 là tối đa | Quy đổi hệ số của app sang `rate * 0.5` (web giữ nguyên) |
| 35 | `lib/providers/theme_provider.dart`, `storage_service.dart`, `home_screen.dart` | Không theo chế độ sáng/tối của hệ thống | Lưu `theme_mode` (system/light/dark, mặc định system, đọc được giá trị `dark_mode` cũ); thêm công tắc "Theo hệ thống" |
| 36 | `lib/services/audio_player_service.dart`, `pubspec.yaml` | Code just_audio không dùng, `play()` khi chưa có nguồn, rebuild liên tục | Xoá service và dependency `just_audio`, `audio_session` |
| 38 | `main.dart`, `playlist_provider.dart`, `highlight_provider.dart` | Provider chưa đăng ký, không load từ storage | Đăng ký trong `MultiProvider`, load playlist/highlight từ Hive |
| MOBI | `lib/services/mobi_parser.dart` (mới), `book_reader_screen.dart`, `drive_service.dart`, `file_import_screen.dart` | Import cho chọn `.mobi` nhưng mở ra báo "không hỗ trợ" | Tự viết bộ đọc MOBI/AZW: PalmDB, nén PalmDOC, bỏ trailing bytes, tiêu đề/tác giả từ EXTH, tách chương theo `<mbp:pagebreak/>`. Màn đọc MOBI theo từng chương, tìm kiếm, nghe bằng TTS như EPUB. Cho chọn thêm `.azw`, `.azw3` |

Giới hạn MOBI: chưa hỗ trợ file có DRM và file nén HUFF/CDIC (báo lỗi rõ ràng); AZW3 (KF8) đọc được text nhưng thường chỉ thành một chương; chưa hiển thị ảnh. (Ảnh và HUFF/CDIC đã thêm ở đợt 2026-10-31, xem cuối file.)

Chưa kiểm tra trên thiết bị: phát nền Android/iOS (không có Android SDK trong môi trường build) và file MOBI thật (chỉ test bằng file MOBI tạo trong test).

### Dọn test

- Xoá `test/widget_test.dart` theo yêu cầu: không dùng, và luôn lỗi vì không mock `path_provider`.
- Xoá `test/features_test.dart` và `test/e2e_test.dart` theo yêu cầu: không biên dịch được do xung đột phiên bản `image`/`archive`. Cập nhật README, `run_tests.sh` và docs tương ứng.

### Test mới

- `test/tts_split_test.dart`: kiểm tra `TtsService.splitText` (đoạn ngắn, text rỗng, đoạn dài, câu rất dài). Chạy: `flutter test test/tts_split_test.dart test/models_test.dart` → 17/17 pass.

### Đợt 3 (2026-10-30): Google Drive import

| # | File | Lỗi | Cách sửa |
|---|------|-----|----------|
| 39 | `lib/services/drive_service.dart`, `book_provider.dart` | File `.azw/.azw3` trên Drive không hiện ra (Drive gán octet-stream hoặc MIME Amazon), và nếu tải về thì màn đọc không nhận ra loại file | Gộp thành một truy vấn nhiều MIME (kèm octet-stream, MIME Amazon), lọc lại theo đuôi file; loại sách lấy theo đuôi file trước (`resolveBookMimeType`) |
| 40 | `lib/screens/file_import_screen.dart` | Thẻ "Import from Google Drive" mở màn Drive khi chưa đăng nhập nhưng không có nút kết nối | Màn Drive hiện nút "Connect Google Drive" và lỗi kết nối; thêm nút làm mới danh sách |
| 41 | `lib/services/drive_service.dart`, `file_import_screen.dart` | Token bị thu hồi (401) hiện lỗi thô; phiên hết hạn để lại danh sách cũ | Lỗi 401 xoá phiên và chuyển về màn kết nối; kết nối lại thì tải lại danh sách |

Test mới: `test/drive_mime_test.dart` (5 case). `flutter test` → 27/27 pass.

Chưa chạy được trên thiết bị: `google-services.json` và `GoogleService-Info.plist` vẫn là giá trị mẫu, cần OAuth client thật (Android + SHA-1, Web) thì mới đăng nhập Drive được.

### Đợt 4 (2026-10-30): Chạy trên web

| # | File | Lỗi | Cách sửa |
|---|------|-----|----------|
| 42 | `pubspec.yaml` | Repo không có `pubspec.lock`, `pub get` chọn `image 4.11.0` đi với `archive 4.0.9` (gói `pdf` giới hạn archive <4.1.0) → lỗi `decodeLazy isn't defined`, build hỏng trên mọi nền tảng | `dependency_overrides: image: 4.10.2` |
| 43 | `assets/fonts/` | 4 file `.ttf` thực ra là trang HTML của GitHub, font NotoSans không dùng được | Thay `NotoSans-Regular.ttf`, `NotoSansThai-Regular.ttf` bằng font thật (kèm `OFL.txt`); bỏ `NotoSansVietnamese` (không có font này, NotoSans đã có tiếng Việt) và `NotoSansDevanagari` (không khai báo, không dùng) |
| 44 | `lib/services/tts_service.dart` | Trên web, trình duyệt tải danh sách giọng chậm nên lúc khởi tạo `setLanguage('vi-VN')` không chọn được giọng, trình duyệt đọc bằng giọng mặc định (thường là tiếng Anh) | Trước lần đọc đầu tiên trên web, tải lại giọng và áp dụng lại giọng đã lưu hoặc ngôn ngữ |

Kiểm tra: `flutter build web` thành công; chạy bản build trong Chromium (Playwright): nhập và đọc EPUB/PDF, nút đọc to dùng giọng `vi-VN`, sách còn sau khi tải lại trang. `flutter test` → 27/27 pass.
Trên web: Google Drive bị tắt (chưa hỗ trợ đăng nhập), không phát nền / điều khiển màn hình khoá.

### Đợt 5 (2026-10-31): Chọn file trên Safari iOS

| # | File | Lỗi | Cách sửa |
|---|------|-----|----------|
| 45 | `lib/screens/file_import_screen.dart`, `lib/utils/file_picker_web_options_*.dart` | Trên Safari iOS, chọn file báo "No file selected": file_picker coi sự kiện `focus` của cửa sổ (Safari gửi trước khi file từ ứng dụng Tệp sao chép xong) là huỷ; bộ lọc `accept` theo đuôi còn làm mờ file .mobi/.azw | Trên web: `cancelUploadOnWindowBlur: false` (chỉ coi là huỷ khi có sự kiện `cancel`), bỏ bộ lọc đuôi, tự kiểm tra đuôi sau khi chọn và báo lỗi nếu không hỗ trợ. Tuỳ chọn web dùng import có điều kiện để bản mobile vẫn biên dịch |

Kiểm tra: Playwright giả lập Safari (gửi `focus` trước khi chọn file 1,5 giây): nhập EPUB thành công, file `.txt` hiện lỗi "Unsupported file". `flutter test` → 27/27 pass. Chưa thử trên iPhone thật.

### Đợt 6 (2026-10-31): "Không thể đọc file EPUB"

| # | File | Lỗi | Cách sửa |
|---|------|-----|----------|
| 46 | `lib/services/epub_repair.dart`, `lib/screens/book_reader_screen.dart` | epubx (trong katbook_epub_reader) từ chối nhiều EPUB 3 thực tế: mục `nav` có `properties="nav scripted"`/`"cover-image nav"`, hoặc EPUB 3 chỉ có NCX → "TOC item, not found in EPUB manifest". Màn đọc chỉ báo "Không thể đọc file EPUB", không rõ lý do | Khi mở lỗi: sửa OPF (`properties="nav"`, hoặc đánh dấu EPUB 2 để dùng NCX), nén lại rồi mở lại. Thông báo lỗi kèm lý do từ thư viện |
| 47 | `lib/services/epub_repair.dart` | EPUB của Lam: manifest khai báo `OEBPS/notes.html` nhưng zip không có → "file ... not found in archive" | Khi sửa: file trùng tên khác hoa/thường hoặc mã hoá URL thì chép sang đúng tên; thiếu hẳn thì thêm file rỗng |

Kiểm tra: 34 EPUB mẫu của epubx: trước 31/34 mở được, sau 33/34 (còn `svg-in-spine.epub`: trang SVG trong spine). Test mới `test/epub_repair_test.dart` (4 case). `flutter test` → 31/31 pass. Bản web trên Chromium mở được `trees.epub` nhờ sửa.

### Đợt 7 (2026-10-31): MOBI có ảnh và nén HUFF/CDIC

| # | File | Lỗi | Cách sửa |
|---|------|-----|----------|
| 48 | `lib/services/mobi_parser.dart` | File MOBI nén HUFF/CDIC (sách Kindle cũ) báo "chưa được hỗ trợ" | Thêm `HuffCdicReader` (theo cách giải của Calibre): bảng mã HUFF + từ điển CDIC, giải đệ quy các cụm còn nén. Chỉ dùng số nguyên dưới 2^53 để chạy đúng trên web |
| 49 | `lib/services/mobi_parser.dart`, `lib/screens/book_reader_screen.dart` | Sách MOBI không hiện ảnh (thẻ `<img>` bị bỏ) | Chương gồm các khối chữ/ảnh (`MobiBlock`); ảnh lấy từ record theo `recindex`/`hirecindex` hoặc `kindle:embed`, chỉ giữ JPEG/PNG/GIF/BMP; màn đọc hiện ảnh bằng `Image.memory`. TTS và vị trí đọc vẫn dùng danh sách đoạn chữ như cũ |
| 50 | `lib/services/mobi_parser.dart` | File có DRM chỉ báo "có DRM, không thể đọc" | Thông báo nói rõ là khoá bản quyền Amazon/Kindle và cần file không DRM. Không giải mã DRM |

Kiểm tra: test mới dựng file HUFF/CDIC (mã 8 bit và 9 bit, cụm nén đệ quy) và file có ảnh; dữ liệu HUFF cũng được giải bằng bản Python theo Calibre cho cùng kết quả. `test/mobi_parser_test.dart` pass trên Dart VM và trên Chromium (`flutter test --platform chrome`). `flutter test` → 43 pass (1 skip cần model Piper). Chưa thử với file MOBI thật.
