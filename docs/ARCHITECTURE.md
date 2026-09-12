# 🏗️ Kiến trúc Ứng dụng LibriAudio

## 📐 **Clean Architecture Overview**

```
┌─────────────────────────────────────────────────────────────┐
│                     PRESENTATION LAYER                       │
│  Screens (Views)  Widgets (UI Components)                   │
│  • HomeScreen  • BookReaderScreen  • FileImportScreen      │
│  • SearchScreen  • SettingsScreen                            │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│                     BUSINESS LOGIC LAYER                     │
│  Providers (State Management)  Use Cases                    │
│  • BookProvider  • ThemeProvider                            │
│  • HighlightProvider  • PlaylistProvider                    │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│                       DATA LAYER                            │
│  Repositories  Services  Data Sources                       │
│  • StorageService  • TtsService  • DriveService            │
└─────────────────────────────────────────────────────────────┘
```

---

## 📁 **Layer Chi tiết**

### **1. Presentation Layer (UI)**

#### **Screens** (Màn hình)
- `HomeScreen` - Danh sách sách, tìm kiếm
- `BookReaderScreen` - Đọc sách, phát audio
- `FileImportScreen` - Import từ Drive/Device
- `SearchScreen` - Tìm kiếm trong sách
- `SettingsScreen` - Cài đặt ứng dụng

#### **Widgets** (Thành phần UI)
- `BookItem` - Item trong danh sách sách
- `VoiceSelector` - Chọn giọng đọc
- `AudioVisualizer` - Hiệu ứng âm thanh
- `HighlightWidget` - Hiển thị đánh dấu
- `AudioFloatingControls` - Điều khiển nổi khi phát audio

### **2. Business Logic Layer**

#### **Providers** (State Management)
- `BookProvider` - Quản lý danh sách sách
- `ThemeProvider` - Quản lý theme (dark/light)
- `HighlightProvider` - Quản lý đánh dấu & ghi chú
- `PlaylistProvider` - Quản lý playlist

#### **Services** (Xử lý nghiệp vụ)
- `StorageService` - Lưu trữ dữ liệu (Hive, SharedPreferences)
- `TtsService` - Xử lý Text-to-Speech
- `AudioPlayerService` - Xử lý phát audio
- `DriveService` - Kết nối Google Drive
- `FirebaseService` - Đồng bộ Firebase

### **3. Data Layer**

#### **Models** (Data Models)
- `Book` - Thông tin sách
- `ReadingState` - Vị trí đọc cuối cùng
- `Highlight` - Đánh dấu & ghi chú
- `Playlist` - Danh sách nghe

#### **Storage**
- `Hive` - Local database
- `SharedPreferences` - Cấu hình đơn giản
- `Firebase` - Cloud sync (tùy chọn)

---

## 🔄 **Data Flow**

```
User Interaction
        ↓
   Screen/Widget
        ↓
   Provider (State)
        ↓
   Service (Business Logic)
        ↓
   Data Source (Hive/Firebase/API)
        ↓
   Update UI (Provider.notifyListeners())
```

---

## 🎯 **Design Patterns**

### **1. Provider Pattern**
- `ChangeNotifier` cho state management
- `Consumer` để rebuild UI khi state thay đổi

### **2. Service Pattern**
- `StorageService` - Singleton cho database
- `TtsService` - Singleton cho audio
- `DriveService` - Singleton cho Google Drive

### **3. Repository Pattern**
- `StorageService` đóng vai trò Repository
- Abstract data sources (Hive, SharedPreferences)

---

## 🔌 **Dependencies Injection**

```dart
MultiProvider(
  providers: [
    ChangeNotifierProvider(create: (_) => BookProvider()),
    ChangeNotifierProvider(create: (_) => ThemeProvider()),
    ChangeNotifierProvider(create: (_) => TtsService()),
    ChangeNotifierProvider(create: (_) => AudioPlayerService()),
    ChangeNotifierProvider(create: (_) => DriveService()),
  ],
  child: MyApp(),
)
```

---

## 🗄️ **Database Schema**

### **Hive Boxes**

| Box Name | Model | Description |
|----------|-------|-------------|
| `books` | `Book` | Danh sách sách đã import |
| `reading_states` | `ReadingState` | Vị trí đọc cuối cùng |
| `highlights` | `Highlight` | Đánh dấu & ghi chú |
| `playlists` | `Playlist` | Danh sách nghe |

### **SharedPreferences Keys**

| Key | Type | Default |
|-----|------|---------|
| `voice_id` | String | `''` |
| `reading_speed` | double | `1.0` |
| `dark_mode` | bool | `false` |
| `last_dir` | String | `''` |

---

## 🎨 **Theme System**

### **Light Theme**
```dart
ThemeData(
  colorScheme: ColorScheme.fromSeed(
    seedColor: AppColors.primary,  // #6750A4
    brightness: Brightness.light,
  ),
  scaffoldBackgroundColor: AppColors.background,
)
```

### **Dark Theme**
```dart
ThemeData(
  colorScheme: ColorScheme.fromSeed(
    seedColor: AppColors.primary,
    brightness: Brightness.dark,
  ),
  scaffoldBackgroundColor: const Color(0xFF1C1B1F),
)
```

---

## 🔊 **Audio Architecture**

```
┌─────────────────────────────────────────────────────────────┐
│                    Audio Player Layer                        │
│  just_audio (Playback Engine)                               │
│  • Play  • Pause  • Stop  • Seek                            │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│                  WakeLock Service                            │
│  wakelock_plus (Prevent sleep)                              │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│                    TTS Service                               │
│  flutter_tts (Text-to-Speech)                               │
│  • Speak  • Pause  • Resume  • Stop                         │
└─────────────────────────────────────────────────────────────┘
```

---

## 🔒 **Security Considerations**

### **1. Google Drive API**
- OAuth 2.0 authentication
- Store tokens securely (Flutter Secure Storage)
- Request only necessary scopes

### **2. Local Storage**
- Hive: Encrypt sensitive data
- SharedPreferences: No sensitive data

### **3. Firebase**
- Authentication required for sync
- Firestore security rules

---

## 🚀 **Performance Optimization**

### **1. Lazy Loading**
- EPUB chapters load on-demand
- Image lazy loading

### **2. Caching**
- Audio files cache
- Book metadata cache

### **3. Background Processing**
- Audio playback in foreground service
- WakeLock for screen off

---

## 📱 **Platform-Specific**

### **Android**
- Foreground service for audio
- FileProvider for file sharing
- Permissions: `FOREGROUND_SERVICE`, `WAKE_LOCK`

### **iOS**
- Background modes: `audio`, `fetch`
- AVAudioSession configuration
- Info.plist permissions

---

## 🧪 **Testing Strategy**

| Type | Files | Description |
|------|-------|-------------|
| Unit Test | `services/*.dart` | Test business logic |
| Widget Test | `widgets/*.dart` | Test UI components |
| Integration | - | Test full flow (TBD) |

---

## 🔄 **Future Architecture Improvements**

| Feature | Current | Target |
|---------|---------|--------|
| State Management | Provider | Riverpod + Freezed |
| Navigation | Navigator 1.0 | GoRouter |
| DI | Manual | GetIt + Inject |
| Data Layer | Hive | Floor (SQLite) |

---

**Last Updated**: 2026-09-07
**Version**: 1.0.0
