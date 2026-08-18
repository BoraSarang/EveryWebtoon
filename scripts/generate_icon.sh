#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

echo "🎨 Generating app icon..."
swift "$SCRIPT_DIR/generate_icon.swift"

ICONSET=$(mktemp -d)
SRC="$PROJECT_DIR/images/EveryWebtoon.png"
OUT="$ICONSET"
sips -z 16 16 "$SRC" --out "$OUT/icon_16x16.png" >/dev/null 2>&1
sips -z 32 32 "$SRC" --out "$OUT/icon_16x16@2x.png" >/dev/null 2>&1
sips -z 32 32 "$SRC" --out "$OUT/icon_32x32.png" >/dev/null 2>&1
sips -z 64 64 "$SRC" --out "$OUT/icon_32x32@2x.png" >/dev/null 2>&1
sips -z 128 128 "$SRC" --out "$OUT/icon_128x128.png" >/dev/null 2>&1
sips -z 256 256 "$SRC" --out "$OUT/icon_128x128@2x.png" >/dev/null 2>&1
sips -z 256 256 "$SRC" --out "$OUT/icon_256x256.png" >/dev/null 2>&1
sips -z 512 512 "$SRC" --out "$OUT/icon_256x256@2x.png" >/dev/null 2>&1
sips -z 512 512 "$SRC" --out "$OUT/icon_512x512.png" >/dev/null 2>&1
sips -z 1024 1024 "$SRC" --out "$OUT/icon_512x512@2x.png" >/dev/null 2>&1
python3 "$SCRIPT_DIR/make_icns.py" "$ICONSET" "$SCRIPT_DIR/resources/EveryWebtoon.icns"
rm -rf "$ICONSET"

echo "✅ Icon updated: $SCRIPT_DIR/resources/EveryWebtoon.icns"
