# Cài đặt, chạy và triển khai

## Yêu cầu

- Flutter stable (Dart >= 3.3). Repo đã được kiểm tra với Flutter 3.47.
- Node.js/npm nếu chạy hoặc build web (để tải thư viện giọng offline).
- Android SDK nếu build Android; Chrome nếu chạy web.

Cài Flutter trên Linux có thể dùng `./install_flutter.sh` (tải bản 3.24, nên cập nhật bằng `flutter upgrade` sau khi cài), hoặc làm theo https://docs.flutter.dev/get-started/install.

## Chạy app

```bash
flutter pub get
./tool/fetch_piper_web.sh    # chỉ cần cho web, chạy một lần
flutter run -d chrome        # web
flutter run                  # Android (máy thật hoặc emulator)
```

`tool/fetch_piper_web.sh` tải onnxruntime-web và piper_phonemize (khoảng 40 MB, từ npm) vào `web/piper/vendor/` cho giọng offline trên web. Thư mục này không commit; thiếu nó thì app web vẫn chạy nhưng giọng offline báo lỗi khi đọc.

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
./tool/fetch_piper_web.sh && flutter build web --release --dart-define=GOOGLE_WEB_CLIENT_ID=<client id web>
flutter build apk --release          # hoặc appbundle
```

iOS chưa build được vì repo thiếu `ios/Runner.xcodeproj`. Có thể tạo lại bằng `flutter create --platforms=ios .` rồi kiểm tra lại `Info.plist`.

## Deploy web (GitHub Pages)

Workflow `.github/workflows/deploy_web.yml` build web và đưa lên https://lamnguyenvan1986.github.io/EPub/ mỗi khi có push lên `main` (có thể chạy tay qua *Run workflow*). Build dùng `--base-href /EPub/` và `--no-web-resources-cdn` để CanvasKit đi kèm app.

Yêu cầu: *Settings > Pages > Source* đặt là **GitHub Actions**.

Workflow chạy `tool/fetch_piper_web.sh` trước khi build, và truyền biến repo `GOOGLE_WEB_CLIENT_ID` (*Settings > Secrets and variables > Actions > Variables*) vào `--dart-define` cho Google Drive.

## Google Drive

### Web

Bản web xin quyền Drive bằng Google Identity Services (cửa sổ popup của Google), không cần file cấu hình, chỉ cần một OAuth client loại **Web application**:

1. Google Cloud Console > chọn project > bật **Google Drive API** (*APIs & Services > Library*).
2. *OAuth consent screen*: loại External, điền tên app và email; thêm scope `drive.readonly` và `drive.file`; thêm tài khoản Gmail của mình vào *Test users*.
3. *Credentials > Create credentials > OAuth client ID > Web application*. Ở **Authorized JavaScript origins** thêm `https://lamnguyenvan1986.github.io` (không có `/EPub`), và `http://localhost:8080` nếu chạy thử bằng `flutter run -d chrome --web-port 8080`. Không cần Redirect URI.
4. Copy Client ID (dạng `xxxx.apps.googleusercontent.com`) vào biến repo `GOOGLE_WEB_CLIENT_ID` (*Settings > Secrets and variables > Actions > Variables > New repository variable*), rồi chạy lại workflow *Deploy web*.

Nếu không đặt biến này, app dùng Client ID trong thẻ `<meta name="google-signin-client_id">` của `web/index.html` (giá trị có từ đầu repo, không rõ có cho phép origin github.io không). Khi app còn ở chế độ Testing, Google hiện cảnh báo "app chưa xác minh"; bấm *Tiếp tục* là dùng được với tài khoản test.

### Android/iOS

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
| Web: giọng offline báo "Không chạy được giọng offline" | Thiếu `web/piper/vendor/`: chạy `./tool/fetch_piper_web.sh` rồi build lại |
| Web: bấm Connect Google Drive không có gì | Trình duyệt chặn popup, hoặc Client ID chưa có origin của trang trong *Authorized JavaScript origins* |
| MOBI không mở được | File có DRM (không hỗ trợ, app báo lỗi rõ ràng) |
| `No devices detected` | `flutter doctor`, `flutter doctor --android-licenses` |
| Lỗi khi `pub get` | `flutter pub cache repair && flutter pub get` |
