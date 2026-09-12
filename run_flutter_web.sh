#!/bin/bash

echo "========================================"
echo "LibriAudio - Chạy trên trình duyệt"
echo "========================================"
echo ""

# Kiểm tra Flutter
if ! command -v flutter &> /dev/null; then
    echo "Flutter chưa cài đặt. Cài đặt Flutter trước..."
    echo "Chạy: ./install_flutter.sh"
    exit 1
fi

# Cài đặt dependencies
echo "Cài đặt dependencies..."
flutter pub get
if [ $? -ne 0 ]; then
    echo "❌ Lỗi khi cài đặt dependencies"
    exit 1
fi
echo "✅ Dependencies đã cài đặt"

# Kiểm tra web
flutter config --enable-web
if [ $? -ne 0 ]; then
    echo "❌ Lỗi khi bật web support"
    exit 1
fi

# Chạy trên web
echo ""
echo "🚀 Đang chạy Flutter trên trình duyệt..."
echo "Mở http://localhost:8080 để xem ứng dụng"
echo ""
flutter run -d chrome
