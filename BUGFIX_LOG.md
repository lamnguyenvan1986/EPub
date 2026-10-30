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

### Chưa sửa (để sau)

- #31 Phát audio nền thực sự (audio_service, foreground service, audio session cho TTS khi khoá màn hình).
- #34 Dải tốc độ 0.5–2.0 chưa chuẩn hoá theo từng nền tảng (iOS).
- #35 `ThemeProvider` chưa hỗ trợ `ThemeMode.system`.
- #36 `AudioPlayerService` (just_audio) vẫn là code chưa dùng.
- #38 `PlaylistProvider`/`HighlightProvider` chưa đăng ký và chưa load từ storage.
- Test có sẵn: `widget_test.dart` lỗi vì không mock `path_provider`; `features_test.dart`, `e2e_test.dart` không biên dịch do xung đột phiên bản `image`/`archive` (dependency gián tiếp). Các lỗi này đã có từ trước.

### Test mới

- `test/tts_split_test.dart`: kiểm tra `TtsService.splitText` (đoạn ngắn, text rỗng, đoạn dài, câu rất dài). Chạy: `flutter test test/tts_split_test.dart test/models_test.dart` → 17/17 pass.
