# 🧪 Tests - LibriAudio

Thư mục này chứa các test cho ứng dụng LibriAudio.

## 📁 Cấu trúc Test

```
test/
├── models_test.dart      # Unit tests cho Models
├── tts_split_test.dart   # Unit tests chia đoạn văn bản cho TTS
└── README.md             # Tài liệu này
```

## 🚀 Chạy Tests

### Cách 1: Sử dụng script
```bash
./run_tests.sh
```

### Cách 2: Manual
```bash
# Install dependencies
flutter pub get

# Run all tests
flutter test

# Run specific test file
flutter test test/models_test.dart
flutter test test/tts_split_test.dart

# Run with coverage
flutter test --coverage
```

## 📊 Test Types

### 1. Unit Tests (`models_test.dart`)
Kiểm tra logic của các Model classes:
- ✅ Book model (create, toMap, fromMap, copyWith)
- ✅ Highlight model
- ✅ Playlist model
- ✅ Validation tests

### 2. TTS Tests (`tts_split_test.dart`)
Kiểm tra `TtsService.splitText`:
- ✅ Đoạn ngắn giữ nguyên
- ✅ Bỏ text rỗng
- ✅ Chia đoạn dài không vượt độ dài tối đa

## 📈 Code Coverage

Để xem code coverage:
```bash
flutter test --coverage
genhtml coverage/lcov.info -o coverage/html
open coverage/html/index.html
```

## 🔧 Continuous Integration

Test được chạy tự động trên:
- 🔄 GitHub Actions
- 🔄 GitLab CI
- 🔄 CircleCI

## 🐛 Debugging Tests

```bash
# Run test với verbose output
flutter test --verbose test/models_test.dart

# Run test với hot reload
flutter test --start-paused test/tts_split_test.dart

# Debug test
flutter test --pause-isolates-on-start test/models_test.dart
```

## ✅ Best Practices

1. **Mỗi test nên độc lập** - Không phụ thuộc vào thứ tự
2. **Test nên nhanh** - Dưới 1 giây
3. **Test nên có thể lặp lại** - Không dùng time-based logic
4. **Mock external services** - Dùng `mockito` cho Google Drive/Firebase

## 📝 Adding New Tests

```dart
// Ví dụ: Thêm test cho BookProvider
test('BookProvider - Save and load', () {
  final provider = BookProvider();
  
  final book = Book(title: 'Test', fileType: 'epub');
  provider.addBook(book);
  
  expect(provider.books.length, 1);
});
```

---

**Happy Testing! 🎉**
