#!/usr/bin/env bash
# Tải thư viện cho giọng offline trên web (onnxruntime-web, piper_phonemize) vào
# web/piper/vendor/. Chạy trước `flutter build web` hoặc `flutter run -d chrome`.
# Thư mục vendor/ không commit (khoảng 40 MB).
set -euo pipefail

ORT_VERSION=1.18.0
PIPER_WASM_VERSION=1.0.0

root="$(cd "$(dirname "$0")/.." && pwd)"
dest="$root/web/piper/vendor"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

cd "$tmp"
npm pack --silent "onnxruntime-web@$ORT_VERSION" "@diffusionstudio/piper-wasm@$PIPER_WASM_VERSION" > /dev/null
mkdir ort piper
tar xzf "onnxruntime-web-$ORT_VERSION.tgz" -C ort
tar xzf "diffusionstudio-piper-wasm-$PIPER_WASM_VERSION.tgz" -C piper

rm -rf "$dest"
mkdir -p "$dest"
# Chỉ cần bản WASM một luồng: có SIMD và không SIMD (Safari cũ)
cp ort/package/dist/ort.wasm.min.js ort/package/dist/ort-wasm-simd.wasm ort/package/dist/ort-wasm.wasm "$dest/"
cp piper/package/build/piper_phonemize.js piper/package/build/piper_phonemize.wasm piper/package/build/piper_phonemize.data "$dest/"
echo "Đã tải thư viện giọng offline web vào $dest"
