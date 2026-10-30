# 📝 Change Log - LibriAudio

Tất cả các thay đổi quan trọng cho ứng dụng LibriAudio được ghi lại ở đây.

## [1.1.1] - 2026-10-30
### 🐛 Bug fixes
- Sửa lỗi biên dịch (BookProvider, GoogleSignIn 7.x, assets không tồn tại)
- Sửa crash khi lưu tiến độ đọc, khi chia sẻ sách và ở dropdown chọn giọng
- TTS đọc theo từng đoạn (vượt giới hạn độ dài của Android), đọc tiếp đúng vị trí, chuyển chương, dừng khi thoát màn hình, nghe được PDF
- Google Drive dùng chung một phiên đăng nhập, tự lấy lại token, không ghi đè file trùng tên
- Chi tiết: xem [BUGFIX_LOG.md](BUGFIX_LOG.md)

## [1.1.0] - 2026-09-18
### ✨ Thêm mới
- Cải thiện xử lý lỗi khi đọc file EPUB và PDF
- Thêm text extraction cho PDF bằng pdfrx
- Tự động play từ vị trí đã đọc trước đó

### 🔧 Cải tiến
- **book_reader_screen.dart**: Refactor code structure
  - Tách riêng methods `_loadEpub()` và `_loadPdf()`
  - Tách riêng methods `_extractTextFromEpub()` và `_extractTextFromPdf()`
  - Cải thiện error handling với try-catch chi tiết hơn
  - Xóa code comment không cần thiết
- **PDF Viewer**: Sử dụng pdfrx package thay vì web iframe trên mobile/desktop
- **Text extraction**: Cải thiện method extraction cho cả EPUB và PDF

### 🐛 Bug fixes
- Sửa lỗi null pointer khi `_book.filePath == null`
- Sửa lỗi duplicate code trong PDF text extraction
- Sửa lỗi không hiển thị error message khi load file thất bại

## [1.0.0] - 2026-09-07
### ✨ Thêm mới
- Đọc sách EPUB, PDF, MOBI
- Text-to-Speech với giọng tiếng Việt
- Phát audio in background ( WakeLock )
- Đánh dấu & ghi chú ( Highlights )
- Tìm kiếm trong sách
- Dark mode / Light mode
- Playlist / Danh sách nghe
- Chia sẻ sách
- Export sách
- Auto-sync từ Google Drive
- Đồng bộ với Firebase

### 🔧 Cải tiến
- UI/UX hiện đại với Material 3
- Hiệu ứng âm thanh trực quan
- Tối ưu hóa pin khi nghe audio
- Xử lý lỗi khi đọc file

### 🐛 Bug fixes
- Sửa lỗi đọc file EPUB bị lỗi
- Sửa lỗi phát audio khi tắt màn hình

## [0.9.0] - 2026-09-01
### ✨ alpha release
- Initial alpha version
- Basic EPUB reader
- Basic TTS functionality

---

## Cách đọc changelog

- **[Added]** - Tính năng mới
- **[Changed]** - Thay đổi hiện có
- **[Fixed]** - Bug fix
- **[Removed]** - Tính năng bị xóa

---

## Versioning

Sử dụng Semantic Versioning:
- `MAJOR.MINOR.PATCH`
- `1.0.0` - Stable release
- `0.9.0` - Pre-release

---

**Happy Reading! 📚**
