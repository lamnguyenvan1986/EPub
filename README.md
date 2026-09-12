# LibriAudio - Ứng dụng Đọc sách & Nghe Audio

Một ứng dụng Flutter đầy đủ tính năng để đọc sách điện tử (PDF, EPUB) và nghe audio với hỗ trợ text-to-speech, lưu vị trí, chọn giọng đọc, đánh dấu, ghi chú và đồng bộ với Firebase.

## 📚 **Tài liệu**

- [📖 AI Claude Documentation](./docs/AI_CLAUDE_DOCUMENTATION.md) - Tài liệu kỹ thuật cho AI/Code Interpreter
- [📁 Cấu trúc Thư mục](./docs/APP_FOLDER_STRUCTURE.md) - Cấu trúc thư mục chi tiết
- [📄 README](./docs/README.md) - README gốc

## 🚀 Tính năng chính

### 📖 Đọc sách
- Hỗ trợ PDF, EPUB, MOBI
- Giao diện đọc dễ đọc với điều chỉnh font, cỡ chữ
- Chuyển trang mượt mà

### 🔊 Audio & Text-to-Speech
- Phát audio từ nội dung sách (EPUB)
- Chọn giọng đọc (nhiều ngôn ngữ)
- Điều chỉnh tốc độ đọc (0.5x - 2.0x)
- Lưu vị trí đọc

### ☁️ Đồng bộ & Đa thiết bị
- Đồng bộ với Firebase
- Đánh dấu & ghi chú
- Truy cập từ nhiều thiết bị

### 🎨 Giao diện
- Light/Dark mode
- Tùy chỉnh chủ đề
- Hiệu ứng âm thanh trực quan

## 📦 Cài đặt

### 1. Yêu cầu
- Flutter SDK >= 3.0.0
- Dart SDK >= 3.0.0
- Firebase account (cho tính năng đồng bộ)

### 2. Cài đặt dependencies

```bash
flutter pub get
```

### 3. Cấu hình Android & iOS
Xem chi tiết tại [AI Claude Documentation](./docs/AI_CLAUDE_DOCUMENTATION.md)

### 4. Chạy ứng dụng

```bash
flutter run
```

## 📁 Cấu trúc project

Xem [Cấu trúc Thư mục](./docs/APP_FOLDER_STRUCTURE.md) để biết chi tiết.

## 🔌 Tính năng nâng cao

- Text-to-Speech với Google Cloud (tùy chọn)
- Đánh dấu & ghi chú
- Playlist đọc sách
- Tìm kiếm trong sách
- Export/Share sách

# 🧪 Tests

## Chạy Tests

```bash
# Chạy toàn bộ test suite
./run_tests.sh

# Hoặc chạy manual
flutter pub get
flutter test test/models_test.dart
flutter test test/features_test.dart
flutter test test/e2e_test.dart
```

## Loại Tests

| File | Mô tả | Mức độ |
|------|-------|--------|
| `test/models_test.dart` | Unit tests cho Models | ⭐⭐ |
| `test/features_test.dart` | Feature tests | ⭐⭐⭐ |
| `test/e2e_test.dart` | End-to-end tests | ⭐⭐⭐⭐ |

Xem chi tiết tại [test/README.md](test/README.md)

---

## 📝 License

MIT License

## 📝 License

MIT License

## 👥 Author

Created with ❤️ by LibriAudio Team
# EPub
