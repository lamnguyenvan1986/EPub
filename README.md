# LibriAudio

Ứng dụng Flutter để đọc sách điện tử (EPUB, PDF, MOBI/AZW) và nghe sách bằng giọng đọc máy (text-to-speech), mặc định giọng tiếng Việt.

**Bản web:** https://lamnguyenvan1986.github.io/EPub/ (tự build và cập nhật mỗi khi có commit lên `main`).

## Tính năng

- Đọc EPUB (tự sửa các lỗi mục lục/manifest hay gặp), PDF và MOBI/AZW (không DRM, có ảnh, nén PalmDOC hoặc HUFF/CDIC).
- Nghe sách: chọn giọng, chỉnh tốc độ và cao độ, đọc tiếp từ vị trí đã dừng, tự chuyển chương.
- Phát nền trên Android/iOS: thông báo điều khiển, nút tai nghe, màn hình khoá.
- Nhập sách từ máy hoặc từ Google Drive.
- Tìm kiếm trong sách, chia sẻ file sách, giao diện sáng/tối theo hệ thống.

## Tình trạng

| Nền tảng | Trạng thái |
|----------|------------|
| Web | Chạy được (đọc EPUB/PDF/MOBI, nghe TTS, giọng offline Piper, Google Drive khi đã cấu hình Client ID). Không phát nền. |
| Android | Code biên dịch được (`flutter analyze` sạch), chưa thử trên máy thật. |
| iOS | Thiếu `ios/Runner.xcodeproj`, chưa build được. |

Google Drive cần cấu hình OAuth client thật mới đăng nhập được, xem [docs/SETUP.md](docs/SETUP.md#google-drive).

## Bắt đầu nhanh

```bash
flutter pub get
flutter run -d chrome   # hoặc flutter run cho Android
flutter test
```

## Tài liệu

| Tài liệu | Nội dung |
|----------|----------|
| [docs/SETUP.md](docs/SETUP.md) | Cài đặt, chạy, test, build, deploy web, cấu hình Google Drive |
| [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) | Cấu trúc thư mục, các lớp, lưu trữ, luồng đọc và TTS |
| [CHANGELOG.md](CHANGELOG.md) | Các phiên bản và thay đổi |
| [docs/BUGFIX_LOG.md](docs/BUGFIX_LOG.md) | Nhật ký sửa lỗi chi tiết |
| [CLAUDE.md](CLAUDE.md) | Hướng dẫn cho Claude Code khi làm việc với repo |

## License

MIT
