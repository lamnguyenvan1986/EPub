# LibriAudio - AI Documentation (For Claude Code)

## 📱 **Project Overview**

**LibriAudio** is a comprehensive Flutter application for reading and listening to e-books (EPUB, PDF, MOBI) with text-to-speech (TTS) support, background audio playback, bookmarking, notes, and cloud synchronization.

### ✅ **Core Features Implemented**

| Feature | Status | Description |
|---------|--------|-------------|
| Import from Google Drive | ✅ | EPUB, PDF, MOBI files |
| Text-to-Speech (TTS) | ✅ | Multi-voice support, Vietnamese support |
| Background Audio | ✅ | Play while screen is off |
| Save Reading Position | ✅ | Resume from last position |
| Select Voice | ✅ | Multiple voices, languages |
| Bookmarks & Notes | ✅ | Highlight text, add notes |
| Dark Mode | ✅ | Theme switching |
| Search in Book | ✅ | Text search functionality |
| Playlists | ✅ | Organize reading list |
| Export/Share | ✅ | Share books, export to text |
| Battery Saving | ✅ | WakeLock for background playback |
| Auto-Sync from Drive | ✅ | Update book list from Google Drive |

---

## 🏗️ **Architecture & Code Structure**

```
libri_audio/
├── lib/
│   ├── main.dart                           # App entry point
│   ├── models/
│   │   ├── book_model.dart                 # Book, ReadingState
│   │   ├── highlight_model.dart           # Highlight, Note
│   │   └── playlist_model.dart            # Playlist, PlayQueue
│   ├── services/
│   │   ├── storage_service.dart           # Hive, SharedPreferences
│   │   ├── tts_service.dart               # Text-to-Speech
│   │   ├── audio_player_service.dart      # Audio playback
│   │   ├── drive_service.dart             # Google Drive integration
│   │   └── firebase_service.dart          # Firebase sync
│   ├── providers/
│   │   ├── book_provider.dart             # Book state management
│   │   ├── theme_provider.dart            # Theme state
│   │   ├── highlight_provider.dart        # Bookmark state
│   │   └── playlist_provider.dart         # Playlist state
│   ├── screens/
│   │   ├── home_screen.dart               # Main screen
│   │   ├── file_import_screen.dart        # Import from Drive
│   │   ├── book_reader_screen.dart        # Reader with TTS
│   │   ├── search_screen.dart             # Search functionality
│   │   └── settings_screen.dart           # App settings
│   ├── widgets/
│   │   ├── book_item.dart                 # Book list item
│   │   ├── voice_selector.dart            # Voice selection
│   │   ├── audio_visualizer.dart          # Audio visualization
│   │   ├── highlight_widget.dart          # Highlight display
│   │   └── audio_floating_controls.dart   # Floating audio controls
│   └── utils/
│       └── constants.dart                 # Themes, colors, strings
├── pubspec.yaml                           # Dependencies
└── README.md                              # Project documentation
```

---

## 🔧 **Key Technologies**

### **State Management**
- `Provider` (Riverpod) for dependency injection
- `ChangeNotifier` for business logic
- `Hive` for local database

### **Audio & TTS**
- `flutter_tts` - Free Vietnamese TTS support
- `just_audio` - Background audio playback
- `wakelock_plus` - Prevent device sleep

### **File Handling**
- `epub_kit` - EPUB parsing
- `flutter_pdfview` - PDF rendering
- `file_picker` - File selection

### **Cloud Integration**
- `google_sign_in` - Google authentication
- `googleapis` - Drive API access
- `firebase_core` - Firebase services

---

## 📝 **Code Examples**

### **1. Text-to-Speech Service (tts_service.dart)**

```dart
class TtsService extends ChangeNotifier {
  final FlutterTts _tts = FlutterTts();
  bool _isSpeaking = false;
  double _rate = 1.0;
  String _selectedVoice = '';
  String _language = 'vi-VN';
  
  Future<void> speak(String text) async {
    await _tts.speak(text);
    _isSpeaking = true;
    notifyListeners();
  }
  
  void pause() {
    _tts.pause();
    _isSpeaking = false;
    notifyListeners();
  }
  
  void stop() {
    _tts.stop();
    _isSpeaking = false;
    notifyListeners();
  }
  
  // Vietnamese voice selection
  List<Map<String, dynamic>> get vietnameseVoices {
    return _tts.voices.where((v) {
      final locale = v['locale'] ?? v['language'] ?? '';
      return locale.contains('vi') || locale.contains('Vietnamese');
    }).toList();
  }
}
```

### **2. Background Audio Service**

```dart
class AudioPlayerService with ChangeNotifier {
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _wakelockEnabled = false;
  
  Future<void> play() async {
    await WakelockPlus.enable();  // Prevent sleep
    await _audioPlayer.play();
  }
  
  Future<void> stop() async {
    await _audioPlayer.stop();
    await WakelockPlus.disable();  // Release wake lock
    _wakelockEnabled = false;
  }
}
```

### **3. Google Drive Integration**

```dart
class DriveService {
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: [drive.DriveApi.driveFileScope],
  );
  
  Future<void> signIn() async {
    _currentUser = await _googleSignIn.signIn();
    final authentication = await _currentUser!.authentication;
    final credentials = GoogleOAuth2Credentials(
      authentication.accessToken,
      authentication.idToken,
    );
    _driveApi = drive.DriveApi(
      AuthClient(credentials, http.Client()),
    );
  }
  
  Future<List<drive.File>> listPdfAndEpubFiles() async {
    final pdfFiles = await listFiles(mimeType: 'application/pdf');
    final epubFiles = await listFiles(mimeType: 'application/epub+zip');
    return [...pdfFiles, ...epubFiles];
  }
}
```

### **4. Search Functionality**

```dart
class SearchScreen extends StatefulWidget {
  final String bookTitle;
  final String content;
  
  void _search() {
    final query = _searchController.text.toLowerCase();
    if (query.isEmpty) {
      _matches = [];
      return;
    }
    // Find matches in content
    final lines = widget.content.split('
');
    lines.asMap().forEach((index, line) {
      if (line.toLowerCase().contains(query)) {
        _matches.add(line);
      }
    });
  }
}
```

### **5. Book Reader Screen**

```dart
class _BookReaderScreenState extends State<BookReaderScreen> {
  late Book _book;
  int _currentChapterIndex = 0;
  bool _isAudioMode = false;
  
  @override
  void initState() {
    super.initState();
    _book = widget.book;
    
    // Auto-play from last position
    if (widget.autoPlay && _book.lastRead != null) {
      _startAudioReading();
    }
  }
  
  Future<void> _startAudioReading() async {
    if (_textContent != null && _textContent!.isNotEmpty) {
      context.read<TtsService>().speak(_textContent!);
    }
  }
  
  void _shareBook() {
    Share.share(
      'Tôi đang đọc: ${_book.title}

Tải app LibriAudio',
      subject: _book.title,
    );
  }
}
```

---

## 🗄️ **Data Models**

### **Book Model**

```dart
@HiveType(typeId: 0)
class Book {
  @HiveField(0) final String id;
  @HiveField(1) final String title;
  @HiveField(2) final String? author;
  @HiveField(3) final String? filePath;
  @HiveField(4) final String? coverPath;
  @HiveField(5) final String fileType; // 'epub', 'pdf', 'mobi'
  @HiveField(6) final DateTime createdAt;
  @HiveField(7) final DateTime? lastRead;
  @HiveField(8) final int? chapterIndex;
  @HiveField(9) final int? position;
}
```

### **Highlight Model**

```dart
@HiveType(typeId: 2)
class Highlight {
  @HiveField(0) final String id;
  @HiveField(1) final String bookId;
  @HiveField(2) final String text;
  @HiveField(3) final String? note;
  @HiveField(4) final int chapterIndex;
  @HiveField(5) final int positionStart;
  @HiveField(6) final int positionEnd;
  @HiveField(7) final DateTime createdAt;
}
```

---

## 🚀 **Setup & Deployment**

### **1. Install Dependencies**

```bash
flutter pub get
```

### **2. Configure Google Drive**

- Create project at [Google Cloud Console](https://console.cloud.google.com/)
- Enable Google Drive API
- Create OAuth 2.0 credentials
- Add to `android/app/src/main/res/values/strings.xml`

### **3. Configure Firebase**

- Create project at [Firebase Console](https://console.firebase.google.com/)
- Download `google-services.json` → `android/app/`
- Download `GoogleService-Info.plist` → `ios/Runner/`

### **4. Build Android**

```bash
flutter build apk --release
flutter build appbundle --release
```

### **5. Build iOS**

```bash
flutter build ios --release
```

---

## 📱 **Android Configuration**

### **AndroidManifest.xml**

```xml
<uses-permission android:name="android.permission.FOREGROUND_SERVICE"/>
<uses-permission android:name="android.permission.WAKE_LOCK"/>

<application
    android:foregroundServiceType="mediaPlayback">
    
    <service
        android:name=".AudioService"
        android:exported="false"
        android:foregroundServiceType="mediaPlayback" />
</application>
```

### **Info.plist (iOS)**

```xml
<key>UIBackgroundModes</key>
<array>
    <string>audio</string>
    <string>fetch</string>
    <string>remote-notification</string>
</array>
```

---

## 🔐 **Security Considerations**

1. **Google Drive API**: Store OAuth credentials securely
2. **Firebase Auth**: Enable authentication for sync
3. **File Storage**: Use encrypted storage for sensitive books
4. **Permissions**: Request only necessary permissions

---

## 🐛 **Common Issues & Solutions**

### **Issue: "Unsupported file type"**
- **Solution**: Ensure file has correct extension (.epub, .pdf, .mobi)

### **Issue: "No voices available"**
- **Solution**: 
  - Android: Install Google Text-to-Speech
  - iOS: Go to Settings > Accessibility > Spoken Content

### **Issue: Audio stops when screen off**
- **Solution**: 
  - Check `FOREGROUND_SERVICE` permission
  - Verify ` WakelockPlus.enable()` is called

### **Issue: Firebase sync not working**
- **Solution**: 
  - Check `google-services.json` is in correct location
  - Verify Firebase project ID matches

---

## 📊 **Performance Optimization**

1. **Hive Database**: Use `Box.put()` for fast local storage
2. **Lazy Loading**: Load EPUB chapters on-demand
3. **Audio Caching**: Pre-cache audio files for TTS
4. **Battery**: Use WakeLock only during playback

---

## 🔄 **Future Enhancements**

| Priority | Feature | Complexity |
|----------|---------|------------|
| 🔴 High | PDF OCR for text extraction | Medium |
| 🔴 High | Google Cloud TTS API (better Vietnamese) | Medium |
| 🟡 Medium | Real-time Firebase sync | Hard |
| 🟡 Medium | Podcast-style audio generation | Hard |
| 🟢 Low | Social sharing (reviews, recommendations) | Easy |
| 🟢 Low | Reading progress tracking | Easy |

---

## 📚 **References**

- [Flutter Documentation](https://flutter.dev/docs)
- [Hive Database](https://docs.hivedb.dev)
- [Google Drive API](https://developers.google.com/drive/api)
- [Text-to-Speech Guide](https://pub.dev/packages/flutter_tts)
- [Just Audio](https://pub.dev/packages/just_audio)
- [Katbook EPUB Reader](https://pub.dev/packages/katbook_epub_reader)
- [Pdfrx PDF Viewer](https://pub.dev/packages/pdfrx)

---

**Last Updated**: 2026-09-18
**Flutter Version**: >=3.0.0
**Dart Version**: >=3.0.0

## 📖 **Book Reader Screen (book_reader_screen.dart)**

### Overview
The `BookReaderScreen` provides a comprehensive reading experience for EPUB and PDF files with TTS support.

### Key Features
| Feature | Description |
|---------|-------------|
| EPUB Reader | Powered by `katbook_epub_reader` package |
| PDF Reader | Powered by `pdfrx` package |
| TTS Mode | Text-to-speech using `TtsService` |
| Chapter Navigation | Previous/Next chapter buttons |
| Search | Search within book content |
| Settings | Font size, voice selection, TTS rate |
| Share/Export | Share book info or export content |

### Main Methods
| Method | Description |
|--------|-------------|
| `_loadBook()` | Main entry point, loads EPUB or PDF based on file type |
| `_loadEpub()` | Loads EPUB file, extracts text for TTS |
| `_loadPdf()` | Loads PDF file, extracts text for TTS |
| `_extractTextFromEpub()` | Extracts text from EPUB paragraphs |
| `_extractTextFromPdf()` | Extracts text from PDF pages using pdfrx |
| `_startAudioReading()` | Starts TTS with extracted content |
| `_goToNextChapter()` / `_goToPreviousChapter()` | Navigate between chapters |

### State Management
| State Variable | Purpose |
|----------------|---------|
| `_book` | Current book object |
| `_currentChapterIndex` | Current chapter position |
| `_isAudioMode` | Audio vs reading mode toggle |
| `_textContent` | Extracted text for TTS |
| `_isLoading` | Loading state indicator |
| `_error` | Error message display |

### Dependencies
- `katbook_epub_reader` - EPUB rendering and parsing
- `pdfrx` - PDF rendering and text extraction
- `flutter_tts` - Text-to-speech engine
- `provider` - State management
- `share_plus` - Share functionality

---
