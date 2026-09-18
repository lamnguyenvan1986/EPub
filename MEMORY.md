# Memory - LibriAudio Project

This file contains project-specific facts and context for Claude.

## Project Overview

LibriAudio is a Flutter application for reading and listening to e-books (EPUB, PDF, MOBI) with text-to-speech (TTS) support, background audio playback, bookmarking, notes, and cloud synchronization.

## Code Updates - 2026-09-18

- [book_reader_screen.dart refactoring](lib/screens/book_reader_screen.dart) — Refactored book_reader_screen.dart with improved documentation and code structure

## Project Structure

- Main framework: Flutter
- State management: Provider
- Database: Hive + SharedPreferences
- EPUB reader: katbook_epub_reader
- PDF reader: pdfrx
- TTS: flutter_tts

## Key Files

- `lib/screens/book_reader_screen.dart` - Main reader screen with EPUB/PDF/TTS support
- `lib/services/tts_service.dart` - Text-to-speech service
- `lib/services/storage_service.dart` - Local storage with Hive
- `lib/widgets/pdf_viewer.dart` - PDF viewer widget using pdfrx

## Documentation Files

| File | Purpose |
|------|---------|
| `CLAUDE.md` | Main documentation for Claude AI |
| `docs/APP_FOLDER_STRUCTURE.md` | Folder structure documentation |
| `docs/AI_CLAUDE_DOCUMENTATION.md` | Technical documentation for AI |
| `CHANGELOG.md` | Version history and changes |

## Code Conventions

- Classes: `PascalCase` (e.g., `BookReaderScreen`)
- Methods/Variables: `snake_case` (e.g., `_startAudioReading`)
- Constants: `UPPER_SNAKE_CASE`
- All UI strings are in Vietnamese

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

## Development Commands

```bash
flutter pub get    # Install dependencies
flutter run        # Run app
flutter test       # Run tests
flutter build apk --release  # Build Android
```
