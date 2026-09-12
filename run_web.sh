#!/bin/bash

echo "========================================"
echo "LibriAudio Web - Chạy trình duyệt"
echo "========================================"
echo ""

# Kiểm tra nếu có python3 hoặc python
if command -v python3 &> /dev/null; then
    echo "Starting Python HTTP server on http://localhost:8080..."
    python3 -m http.server 8080
elif command -v python &> /dev/null; then
    echo "Starting Python HTTP server on http://localhost:8080..."
    python -m SimpleHTTPServer 8080
else
    echo "Error: Python not found. Please install Python to run the web demo."
    echo ""
    echo "Hoặc mở trực tiếp file: web/index.html trong trình duyệt"
fi
