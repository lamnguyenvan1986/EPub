# LibriAudio - hướng dẫn cho Claude

Flutter app đọc EPUB, PDF, MOBI/AZW và nghe sách bằng TTS (mặc định tiếng Việt). Bản web deploy tự động lên https://lamnguyenvan1986.github.io/EPub/ khi push lên `main`.

Đọc thêm khi cần:
- [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md): thư mục `lib/`, lưu trữ, luồng đọc sách và TTS, khác biệt web/mobile.
- [docs/SETUP.md](docs/SETUP.md): chạy, test, build, deploy, cấu hình Google Drive.
- [docs/BUGFIX_LOG.md](docs/BUGFIX_LOG.md): các lỗi đã sửa và lý do.

## Lệnh

```bash
flutter pub get
flutter analyze
flutter test
./tool/fetch_piper_web.sh            # thư viện giọng offline cho web (trước khi chạy/build web)
flutter build web --release
flutter pub run build_runner build   # sau khi sửa model Hive
```

## Quy ước

- Theo Dart style: class `PascalCase`, method/biến `lowerCamelCase` (ví dụ `_startAudioReading`), hằng trong `constants.dart` dùng `UPPER_SNAKE_CASE` (analyze báo 2 info về việc này, chấp nhận được).
- State: `ChangeNotifier` + `provider`; dùng `context.watch()`/`Consumer` trong UI. Gói `riverpod` có trong pubspec nhưng không dùng.
- Service là singleton (factory constructor), hàm async trả `Future<T>`, bắt lỗi bằng try-catch và hiện thông báo dễ hiểu.
- Chuỗi giao diện viết bằng tiếng Việt. Comment trong code viết tiếng Việt.
- Code chỉ chạy trên mobile phải kiểm tra `kIsWeb`; thư viện chỉ có trên web dùng import có điều kiện (xem `lib/utils/file_picker_web_options_*.dart`).

## Lưu ý

- Không bỏ `dependency_overrides: image: 4.10.2` trong `pubspec.yaml` (build hỏng nếu bỏ).
- Repo không commit `pubspec.lock`.
- Google Drive cần OAuth client thật; file cấu hình hiện tại là mẫu. `ios/Runner.xcodeproj` chưa có.
- `firebase_service.dart`, `HighlightProvider`, `PlaylistProvider` có code nhưng chưa có UI dùng.

## Khi thay đổi

- Sửa lỗi: thêm dòng vào `docs/BUGFIX_LOG.md` và tóm tắt vào `CHANGELOG.md`.
- Thêm/đổi file trong `lib/`: cập nhật `docs/ARCHITECTURE.md`.
- Đổi cách cài đặt/build/deploy: cập nhật `docs/SETUP.md`.
