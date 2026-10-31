# Changelog

Các thay đổi quan trọng của LibriAudio. Chi tiết từng lỗi đã sửa xem [docs/BUGFIX_LOG.md](docs/BUGFIX_LOG.md).

## [1.3.0] - 2026-10-31
### ✨ Thêm mới
- MOBI/AZW: hiện ảnh trong sách (JPEG, PNG, GIF, BMP) đúng vị trí trong chương
- MOBI/AZW: đọc được file nén HUFF/CDIC (thường gặp ở sách Kindle cũ)
- File có DRM báo rõ lý do không mở được

## [1.2.0] - 2026-10-31
### ✨ Thêm mới
- Giọng đọc tiếng Việt ngoài giọng của máy (Cài đặt > Giọng đọc):
  - Giọng offline Piper VAIS1000 chạy bằng sherpa-onnx, tải 64 MB một lần, không cần mạng (Android/iOS)
  - Giọng cloud Microsoft Azure (Hoài My, Nam Minh) và Google Cloud (Chirp3 HD, Neural2, WaveNet), người dùng nhập key của mình
  - Nghe thử; nếu giọng offline/cloud lỗi thì tự đọc tiếp bằng giọng máy và báo lý do

## [1.1.2] - 2026-10-31
### ✨ Thêm mới
- Chạy được trên web, tự deploy lên GitHub Pages: https://lamnguyenvan1986.github.io/EPub/
- Tự sửa EPUB lỗi mục lục (`nav`, NCX) và manifest thiếu file; thông báo lỗi kèm lý do

### 🐛 Bug fixes
- Google Drive: hiện file AZW/AZW3, có nút kết nối, xử lý phiên hết hạn (401)
- Build: ghim `image 4.10.2`, thay font hỏng; web chọn đúng giọng tiếng Việt
- Safari iOS: chọn file không còn báo "No file selected"

## [1.1.1] - 2026-10-30
### ✨ Thêm mới
- Đọc và nghe sách MOBI/AZW (bộ đọc MOBI tự viết, hỗ trợ nén PalmDOC)
- Phát TTS nền với thông báo điều khiển, nút tai nghe và màn hình khoá
- Theme theo chế độ sáng/tối của hệ thống

### 🐛 Bug fixes
- Tốc độ đọc đúng trên Android và iOS
- Playlist/Highlight được đăng ký và load từ bộ nhớ; bỏ AudioPlayerService không dùng
- Sửa lỗi biên dịch (BookProvider, GoogleSignIn 7.x, assets không tồn tại)
- Sửa crash khi lưu tiến độ đọc, khi chia sẻ sách và ở dropdown chọn giọng
- TTS đọc theo từng đoạn (vượt giới hạn độ dài của Android), đọc tiếp đúng vị trí, chuyển chương, dừng khi thoát màn hình, nghe được PDF
- Google Drive dùng chung một phiên đăng nhập, tự lấy lại token, không ghi đè file trùng tên
- Chi tiết: xem [docs/BUGFIX_LOG.md](docs/BUGFIX_LOG.md)

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

