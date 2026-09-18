# Memory - LibriAudio Project

This file contains project-specific facts and context for Claude.

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
