#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

MODE="${1:-debug}"
PLATFORM="${2:-macos}"

echo "🔨 Building ($MODE) for $PLATFORM..."

case "$PLATFORM" in
    macos)
        cd "$PROJECT_DIR"
        swift build -c "$MODE"
        echo "✅ Build complete"
        BIN="$PROJECT_DIR/.build/arm64-apple-macosx/$MODE/EveryWebtoon"
        DEPLOY_APP="$HOME/Applications/EveryWebtoon.app"
        RES="$PROJECT_DIR/scripts/resources"
        rm -rf "$DEPLOY_APP"
        mkdir -p "$DEPLOY_APP/Contents/MacOS" "$DEPLOY_APP/Contents/Resources"
        cp "$BIN" "$DEPLOY_APP/Contents/MacOS/EveryWebtoon"
        cp "$RES/Info.plist" "$DEPLOY_APP/Contents/Info.plist"
        printf 'APPL????' > "$DEPLOY_APP/Contents/PkgInfo"
        cp "$RES/EveryWebtoon.icns" "$DEPLOY_APP/Contents/Resources/EveryWebtoon.icns"
        for locale in ko en; do
            if [ -d "$RES/$locale.lproj" ]; then
                cp -R "$RES/$locale.lproj" "$DEPLOY_APP/Contents/Resources/"
            fi
        done
        pkill -f "$DEPLOY_APP/Contents/MacOS/EveryWebtoon" 2>/dev/null || true
        sleep 0.5
        open "$DEPLOY_APP"
        echo "🚀 Launched: $DEPLOY_APP"
        ;;
    *)
        echo "❌ Unknown platform: $PLATFORM"
        exit 1
        ;;
esac
