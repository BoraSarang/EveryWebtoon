#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
PLATFORM="${1:-macos}"
VERSION="0.1.0"

SCREENSHOT_DIR="$PROJECT_DIR/docs/screenshots/$PLATFORM"
mkdir -p "$SCREENSHOT_DIR"

case "$PLATFORM" in
    macos)
        OUTPUT="$SCREENSHOT_DIR/v${VERSION}_$(date +%Y%m%d_%H%M%S).png"
        screencapture -x "$OUTPUT"
        echo "📸 Screenshot saved: $OUTPUT"
        ;;
    *)
        echo "❌ Unknown platform: $PLATFORM"
        exit 1
        ;;
esac
