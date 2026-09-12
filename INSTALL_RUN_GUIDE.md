# 🚀 Hướng dẫn Cài đặt và Chạy Flutter

## Bước 1: Cài đặt Flutter (một lần)

Chạy script cài đặt:
```bash
./install_flutter.sh
```

Hoặc cài thủ công:
```bash
cd ~
wget https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_3.24.0-stable.tar.xz
tar -xf flutter_linux_3.24.0-stable.tar.xz
echo 'export PATH="$PATH:$HOME/flutter/flutter/bin"' >> ~/.bashrc
source ~/.bashrc
flutter doctor
```

## Bước 2: Cài đặt dependencies

```bash
flutter pub get
```

## Bước 3: Bật hỗ trợ Web

```bash
flutter config --enable-web
flutter config --enable-linux-desktop
flutter config --enable-macos-desktop
```

## Bước 4: Chạy ứng dụng

### Chạy trên Web:
```bash
flutter run -d chrome
# Hoặc
flutter run -d web-server
```

### Chạy trên Android:
```bash
flutter run
```

### Chạy trên macOS:
```bash
flutter run -d macos
```

## Bước 5: Build Release

### Web:
```bash
flutter build web --release
# Deploy thư mục build/web/ lên hosting
```

### Android:
```bash
flutter build appbundle --release
```

### macOS:
```bash
flutter build macos --release
```

## Troubleshooting

### Lỗi: "No devices detected"
```bash
flutter doctor
flutter doctor --androidlicenses
```

### Lỗi: "Flutter: command not found"
```bash
# Thêm Flutter vào PATH
export PATH="$PATH:$HOME/flutter/flutter/bin"
```

### Lỗi khi cài dependencies:
```bash
flutter pub cache repair
flutter pub get
```

## Môi trường hỗ trợ

| Platform | Status | Command |
|----------|--------|---------|
| Web | ✅ | `flutter run -d chrome` |
| Android | ✅ | `flutter run` |
| macOS | ✅ | `flutter run -d macos` |
| Windows | ✅ | `flutter run -d windows` |
| Linux | ✅ | `flutter run -d linux` |

---

**Happy Coding! 🎉**
