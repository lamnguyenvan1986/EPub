#!/bin/bash

echo "Installing Flutter SDK..."
cd ~

# Download Flutter
wget https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_3.24.0-stable.tar.xz

# Extract
tar -xf flutter_linux_3.24.0-stable.tar.xz

# Add to PATH
echo 'export PATH="$PATH:$HOME/flutter/flutter/bin"' >> ~/.bashrc
export PATH="$PATH:$HOME/flutter/flutter/bin"

# Verify
flutter doctor

echo "Flutter installed successfully!"
