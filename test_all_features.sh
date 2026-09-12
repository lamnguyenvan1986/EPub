#!/bin/bash

# LibriAudio - Test Script
# Thực hiện kiểm tra tất cả tính năng

echo "========================================"
echo "LibriAudio Test Suite"
echo "========================================"
echo ""

# Cài đặt dependencies
echo "[TEST 1] Installing dependencies..."
flutter pub get
if [ $? -eq 0 ]; then
    echo "✅ PASSED: Dependencies installed"
else
    echo "❌ FAILED: Dependencies installation failed"
    exit 1
fi
echo ""

# Kiểm tra syntax errors
echo "[TEST 2] Checking Dart analysis..."
flutter analyze
if [ $? -eq 0 ]; then
    echo "✅ PASSED: No syntax errors"
else
    echo "❌ FAILED: Syntax errors found"
    exit 1
fi
echo ""

# Build Android (debug)
echo "[TEST 3] Building Android APK (debug)..."
flutter build apk --debug
if [ $? -eq 0 ]; then
    echo "✅ PASSED: Android build successful"
else
    echo "❌ FAILED: Android build failed"
    exit 1
fi
echo ""

# Build iOS (debug)
echo "[TEST 4] Building iOS (debug)..."
flutter build ios --debug --no-codesign
if [ $? -eq 0 ]; then
    echo "✅ PASSED: iOS build successful"
else
    echo "❌ FAILED: iOS build failed"
    exit 1
fi
echo ""

# Kiểm tra các file quan trọng
echo "[TEST 5] Checking essential files..."
FILES=(
    "lib/main.dart"
    "lib/models/book_model.dart"
    "lib/services/storage_service.dart"
    "lib/services/tts_service.dart"
    "lib/providers/book_provider.dart"
    "lib/screens/home_screen.dart"
    "lib/screens/book_reader_screen.dart"
    "pubspec.yaml"
    "android/app/src/main/AndroidManifest.xml"
    "ios/Runner/Info.plist"
)

for file in "${FILES[@]}"; do
    if [ -f "$file" ]; then
        echo "✅ $file exists"
    else
        echo "❌ $file missing"
        exit 1
    fi
done
echo ""

# Kiểm tra tính năng code
echo "[TEST 6] Checking feature implementations..."

# Kiểm tra TTS service
if grep -q "FlutterTts" lib/services/tts_service.dart; then
    echo "✅ TTS service implemented"
else
    echo "❌ TTS service missing"
fi

# Kiểm tra Google Drive
if grep -q "GoogleSignIn" lib/services/drive_service.dart; then
    echo "✅ Google Drive integration implemented"
else
    echo "❌ Google Drive integration missing"
fi

# Kiểm tra Background audio
if grep -q "AudioPlayer" lib/services/audio_player_service.dart; then
    echo "✅ Background audio service implemented"
else
    echo "❌ Background audio service missing"
fi

# Kiểm tra Highlights
if grep -q "Highlight" lib/models/highlight_model.dart; then
    echo "✅ Highlights feature implemented"
else
    echo "❌ Highlights feature missing"
fi

# Kiểm tra Search
if grep -q "SearchScreen" lib/screens/search_screen.dart; then
    echo "✅ Search feature implemented"
else
    echo "❌ Search feature missing"
fi

# Kiểm tra Dark mode
if grep -q "darkTheme" lib/main.dart; then
    echo "✅ Dark mode implemented"
else
    echo "❌ Dark mode missing"
fi
echo ""

# Kiểm tra XML files
echo "[TEST 7] Checking Android/iOS config files..."
ANDROID_FILES=(
    "android/app/src/main/AndroidManifest.xml"
    "android/app/src/main/res/values/strings.xml"
    "android/app/src/main/res/xml/file_paths.xml"
)

for file in "${ANDROID_FILES[@]}"; do
    if [ -f "$file" ]; then
        echo "✅ $file exists"
    else
        echo "❌ $file missing"
    fi
done

# Kiểm tra iOS
if [ -f "ios/Runner/Info.plist" ]; then
    echo "✅ iOS Info.plist exists"
else
    echo "❌ iOS Info.plist missing"
fi

echo ""
echo "========================================"
echo "Test Suite Complete!"
echo "========================================"
