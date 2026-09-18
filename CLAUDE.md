# LibriAudio - Claude AI Documentation

## Overview

LibriAudio is a Flutter application for reading and listening to e-books (EPUB, PDF, MOBI) with text-to-speech (TTS) support, background audio playback, bookmarking, notes, and cloud synchronization.

## Project Structure

```
lib/
├── main.dart                           # App entry point
├── models/                             # Data Models (Hive)
│   ├── book_model.dart
│   ├── highlight_model.dart
│   └── playlist_model.dart
├── providers/                          # State Management (Provider)
│   ├── book_provider.dart
│   ├── theme_provider.dart
│   ├── highlight_provider.dart
│   └── playlist_provider.dart
├── services/                           # Business Logic
│   ├── storage_service.dart
│   ├── tts_service.dart
│   ├── audio_player_service.dart
│   ├── drive_service.dart
│   └── firebase_service.dart
├── screens/                            # App Screens
│   ├── home_screen.dart
│   ├── file_import_screen.dart
│   ├── book_reader_screen.dart
│   ├── search_screen.dart
│   └── settings_screen.dart
├── widgets/                            # Reusable UI
│   ├── book_item.dart
│   ├── voice_selector.dart
│   ├── audio_visualizer.dart
│   ├── highlight_widget.dart
│   └── audio_floating_controls.dart
└── utils/
    └── constants.dart
```

## Key Technologies

| Component | Technology |
|-----------|------------|
| Framework | Flutter |
| State Management | Provider + ChangeNotifier |
| Database | Hive + SharedPreferences |
| Audio | just_audio + flutter_tts |
| EPUB | katbook_epub_reader |
| PDF | pdfrx |
| Cloud | Google Drive + Firebase |

## Code Conventions

### Naming
- Classes: `PascalCase` (e.g., `BookReaderScreen`)
- Methods/Variables: `snake_case` (e.g., `_startAudioReading`)
- Constants: `UPPER_SNAKE_CASE`

### State Management
- Use `ChangeNotifier` for simple state
- Use `Provider` for dependency injection
- Use `Consumer` or `context.watch()` for UI updates

### Services
- Singletons via `StorageService()` factory
- Return `Future<T>` for async operations
- Handle errors with try-catch and user-friendly messages

## Common Tasks

### Add a new screen
1. Create `lib/screens/new_screen.dart`
2. Add to `main.dart` navigation
3. Update `AI_CLAUDE_DOCUMENTATION.md`

### Add a new model
1. Create `lib/models/model_name.dart`
2. Add `@HiveType` decorator
3. Run `flutter pub run build_runner build`

### Add a new service
1. Create `lib/services/service_name.dart`
2. Implement singleton pattern
3. Add to `pubspec.yaml` dependencies

## Dependencies

### Core
- `flutter` - Framework
- `provider` - State management
- `hive` / `hive_flutter` - Local database

### Audio & TTS
- `flutter_tts` - Text-to-speech
- `just_audio` - Audio playback
- `wakelock_plus` - Prevent sleep

### File Handling
- `katbook_epub_reader` - EPUB parsing
- `pdfrx` - PDF rendering
- `file_picker` - File selection

### Cloud
- `google_sign_in` - Google authentication
- `googleapis` - Drive API
- `firebase_core` - Firebase services

## Development

```bash
# Install dependencies
flutter pub get

# Run app
flutter run

# Run tests
flutter test

# Build Android
flutter build apk --release

# Build iOS
flutter build ios --release
```

## Notes

- All UI strings are in Vietnamese
- TTS supports Vietnamese voices by default
- PDF text extraction uses pdfrx package
- EPUB reader uses katbook_epub_reader package

---

**Last Updated**: 2026-09-18