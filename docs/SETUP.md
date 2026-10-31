# Cài đặt, chạy và triển khai

## Yêu cầu

- Flutter stable (Dart >= 3.0). Repo đã được kiểm tra với Flutter 3.47.
- Android SDK nếu build Android; Chrome nếu chạy web.

Cài Flutter trên Linux có thể dùng `./install_flutter.sh` (tải bản 3.24, nên cập nhật bằng `flutter upgrade` sau khi cài), hoặc làm theo https://docs.flutter.dev/get-started/install.

## Chạy app

```bash
flutter pub get
flutter run -d chrome        # web
flutter run                  # Android (máy thật hoặc emulator)
```

`./run_flutter_web.sh` làm sẵn các bước trên cho web.

Repo không commit `pubspec.lock`. `pubspec.yaml` ghim `image: 4.10.2` trong `dependency_overrides` vì bản 4.11 không tương thích với `archive` mà gói `pdf` yêu cầu; đừng bỏ dòng này.

## Test

```bash
flutter test                 # toàn bộ test
flutter analyze
```

| File | Kiểm tra |
|------|----------|
| `test/models_test.dart` | Model Book, Highlight, Playlist (tạo, toMap/fromMap, copyWith) |
| `test/tts_split_test.dart` | `TtsService.splitText` chia đoạn văn cho TTS |
| `test/mobi_parser_test.dart` | Đọc file MOBI/AZW, giải nén PalmDOC và HUFF/CDIC, ảnh, DRM |
| `test/drive_mime_test.dart` | Nhận loại sách từ MIME và đuôi file trên Drive |
| `test/epub_repair_test.dart` | Sửa EPUB lỗi mục lục và manifest |
| `test/neural_tts_test.dart` | Azure/Google TTS (HTTP giả lập), danh sách giọng offline; tạo WAV bằng sherpa-onnx nếu có model |

Test sherpa-onnx cần file model và thư viện native, nên mặc định bị bỏ qua. Để chạy trên Linux:

```bash
# Tải và giải nén giọng (64 MB)
curl -L -O https://github.com/k2-fsa/sherpa-onnx/releases/download/tts-models/vits-piper-vi_VN-vais1000-medium.tar.bz2
tar xjf vits-piper-vi_VN-vais1000-medium.tar.bz2
LD_LIBRARY_PATH=~/.pub-cache/hosted/pub.dev/sherpa_onnx_linux-1.13.8/linux/x64 \
PIPER_VI_MODEL_DIR=$PWD/vits-piper-vi_VN-vais1000-medium flutter test test/neural_tts_test.dart
```

`./run_tests.sh` chạy thêm analyze, build APK/iOS debug và kiểm tra format.

## Build

```bash
flutter build web --release
flutter build apk --release          # hoặc appbundle
```

iOS chưa build được vì repo thiếu `ios/Runner.xcodeproj`. Có thể tạo lại bằng `flutter create --platforms=ios .` rồi kiểm tra lại `Info.plist`.

## Deploy web (GitHub Pages)

Workflow `.github/workflows/deploy_web.yml` build web và đưa lên https://lamnguyenvan1986.github.io/EPub/ mỗi khi có push lên `main` (có thể chạy tay qua *Run workflow*). Build dùng `--base-href /EPub/` và `--no-web-resources-cdn` để CanvasKit đi kèm app.

Yêu cầu: *Settings > Pages > Source* đặt là **GitHub Actions**.

## Google Drive

Drive chỉ dùng trên Android/iOS; trên web nút Drive bị tắt.

`android/app/google-services.json` và `ios/Runner/GoogleService-Info.plist` hiện là giá trị mẫu, nên chưa đăng nhập được. Để bật:

1. Trên Google Cloud Console, tạo project và bật **Google Drive API**.
2. Tạo OAuth client **Android** với package name của app và SHA-1 của keystore (`cd android && ./gradlew signingReport`).
3. Tạo OAuth client **Web** (dùng làm server client ID cho `google_sign_in`).
4. Tải `google-services.json` mới thay file mẫu; với iOS thì thêm `GoogleService-Info.plist` và URL scheme tương ứng.
5. Thêm tài khoản thử vào *OAuth consent screen > Test users* khi app còn ở chế độ Testing.

## Xử lý sự cố

| Hiện tượng | Cách xử lý |
|------------|------------|
| `decodeLazy isn't defined` khi build | Kiểm tra `dependency_overrides: image: 4.10.2` còn trong `pubspec.yaml` |
| Web đọc bằng giọng tiếng Anh | Trình duyệt chưa có giọng `vi-VN`; chọn giọng trong Cài đặt hoặc cài giọng tiếng Việt cho hệ điều hành |
| "Không thể đọc file EPUB" kèm lý do | App đã thử tự sửa; nếu vẫn lỗi, ghi lại lý do và file để thêm vào `epub_repair.dart` |
| MOBI không mở được | File có DRM (không hỗ trợ, app báo lỗi rõ ràng) |
| `No devices detected` | `flutter doctor`, `flutter doctor --android-licenses` |
| Lỗi khi `pub get` | `flutter pub cache repair && flutter pub get` |
