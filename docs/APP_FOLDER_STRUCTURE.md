# 📁 Cấu trúc Thư mục Ứng dụng LibriAudio

## Tổng quan cấu trúc

```
libri_audio/
├── lib/                                    # Source code Flutter
│   ├── main.dart                           # Entry point ứng dụng
│   │
│   ├── models/                             # Data Models
│   │   ├── book_model.dart                 # Model cho sách (Book, ReadingState)
│   │   ├── highlight_model.dart           # Model cho đánh dấu (Highlight)
│   │   └── playlist_model.dart            # Model cho playlist (Playlist)
│   │
│   ├── providers/                          # State Management (Provider)
│   │   ├── book_provider.dart             # Quản lý danh sách sách
│   │   ├── theme_provider.dart            # Quản lý Theme (Dark/Light)
│   │   ├── highlight_provider.dart        # Quản lý đánh dấu & ghi chú
│   │   └── playlist_provider.dart         # Quản lý Playlist
│   │
│   ├── services/                           # Business Logic Services
│   │   ├── storage_service.dart           # Lưu trữ dữ liệu (Hive, SharedPreferences)
│   │   ├── tts_service.dart               # Text-to-Speech service
│   │   ├── audio_player_service.dart      # Audio playback service
│   │   ├── drive_service.dart             # Google Drive integration
│   │   └── firebase_service.dart          # Firebase sync service
│   │
│   ├── screens/                            # App Screens (Pages)
│   │   ├── home_screen.dart               # Màn hình chính (Danh sách sách)
│   │   ├── file_import_screen.dart        # Import sách từ Drive/Device
│   │   ├── book_reader_screen.dart        # Màn hình đọc sách
│   │   ├── search_screen.dart             # Tìm kiếm trong sách
│   │   └── settings_screen.dart           # Cài đặt ứng dụng
│   │
│   ├── widgets/                            # Reusable UI Widgets
│   │   ├── book_item.dart                 # Item hiển thị sách trong danh sách
│   │   ├── voice_selector.dart            # Dropdown chọn giọng đọc
│   │   ├── audio_visualizer.dart          # Hiệu ứng âm thanh trực quan
│   │   ├── highlight_widget.dart          # Widget hiển thị đánh dấu
│   │   └── audio_floating_controls.dart   # Điều khiển nổi khi phát audio
│   │
│   └── utils/                              # Utilities & Constants
│       └── constants.dart                 # Themes, colors, strings
│
├── assets/                                 # Static assets
│   ├── icons/                             # Icons SVG/PNG
│   ├── images/                            # Images ứng dụng
│   └── fonts/                             # Custom fonts (NotoSans...)
│
├── test/                                   # Test files
│   ├── models_test.dart                   # Model unit tests
│   └── tts_split_test.dart                # TTS text splitting tests
│
├── docs/                                   # Documentation
│   ├── README.md                          # Tài liệu tổng quan
│   ├── ARCHITECTURE.md                    # Kiến trúc hệ thống
│   ├── AI_CLAUDE_DOCUMENTATION.md         # Tài liệu kỹ thuật cho AI
│   └── APP_FOLDER_STRUCTURE.md            # Cấu trúc thư mục (file này)
│
├── android/                                # Android-specific code
├── ios/                                    # iOS-specific code
├── web/                                    # Web-specific code
├── test/                                   # Test files
├── pubspec.yaml                            # Dependencies & config
├── README.md                               # Project overview
└── CHANGELOG.md                            # Thay đổi phiên bản
```

---

## Chi tiết các thư mục

### `/lib/models`
Chứa các data models dùng Hive để persist:
- **Book**: thông tin sách (id, title, author, filePath, fileType...)
- **ReadingState**: vị trí đọc cuối cùng
- **Highlight**: đánh dấu & ghi chú
- **Playlist**: danh sách播放

### `/lib/providers`
State management với Provider/ChangeNotifier:
- **BookProvider**: thêm/xóa/sửa sách, loading states
- **ThemeProvider**: quản lý dark/light mode
- **HighlightProvider**: quản lý highlights
- **PlaylistProvider**: quản lý playlists

### `/lib/services`
Business logic services:
- **StorageService**: Hive database operations
- **TtsService**: Text-to-Speech với flutter_tts
- **AudioPlayerService**: Audio playback với just_audio
- **DriveService**: Google Drive API integration
- **FirebaseService**: Cloud sync (tùy chọn)

### `/lib/screens`
Các màn hình ứng dụng:
- **HomeScreen**: Danh sách sách đã import
- **FileImportScreen**: Import từ Device hoặc Google Drive
- **BookReaderScreen**: Đọc EPUB/PDF với TTS support
- **SearchScreen**: Tìm kiếm trong sách
- **SettingsScreen**: Cài đặt tốc độ, giọng đọc, theme

### `/lib/widgets`
Reusable components:
- **BookItem**: Card hiển thị mỗi cuốn sách
- **VoiceSelector**: Dropdown chọn giọng đọc
- **AudioVisualizer**: Animated audio wave
- **HighlightWidget**: Hiển thị highlight với note
- **AudioFloatingControls**: Controls nổi khi phát audio

---

## Flow dữ liệu

```
User Interaction
       ↓
  Screen/Widget
       ↓
  Provider (notifyListeners())
       ↓
  Service (Business Logic)
       ↓
  Data Source (Hive/Firebase/API)
       ↓
Update UI (Consumer rebuilds)
```

---

## Dependencies quan trọng

| Package | Mục đích |
|---------|----------|
| `provider` | State management |
| `hive` / `hive_flutter` | Local database |
| `flutter_tts` | Text-to-Speech |
| `just_audio` | Audio playback |
| `googleapis` | Google Drive API |
| `katbook_epub_reader` | EPUB reader |

---

**Last Updated**: 2026-09-18
**Version**: 1.1.0

---

## Cấu trúc Claude Code

Để Claude Code hiểu rõ cấu trúc project, file này được sử dụng:

### 1. `.claude/settings.json`
Cấu hình cho Claude Code (nếu tồn tại):
```json
{
  "projectName": "LibriAudio",
  "filePatterns": ["lib/**/*.dart"]
}
```

### 2. `CLAUDE.md`
Tài liệu tổng hợp cho Claude AI:
- Mô tả project
- Hướng dẫn phát triển
- Quy ước code
- Common tasks

### 3. `MEMORY.md`
Lưu trữ các facts ngắn gọn về project:
- Code patterns đã sử dụng
- Quyết định kiến trúc
- Notes quan trọng
