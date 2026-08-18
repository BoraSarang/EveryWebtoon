#!/bin/bash
# usage: ./scripts/a11y-dump.sh [macos] [version]
# output: docs/screenshots/{platform}/v{version}_{name}.a11y.txt + .perf.json
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
PLATFORM="${1:-macos}"
VERSION="${2:-v0.2}"
OUT="$PROJECT_DIR/docs/screenshots/$PLATFORM"
mkdir -p "$OUT"

case "$PLATFORM" in
    macos)
        APP="${3:-EveryWebtoon}"
        OUT_FILE="$OUT/${VERSION}_${APP}.a11y.txt"
        swift "$SCRIPT_DIR/axdump.swift" "$APP" > "$OUT_FILE" 2>&1
        echo "[A11Y] macOS dump: $OUT_FILE ($(wc -l < "$OUT_FILE" | tr -d ' ') lines)"
        echo "{\"platform\":\"macos\",\"version\":\"${VERSION}\",\"generated\":\"$(date -u +%Y-%m-%dT%H:%M:%SZ)\"}" > "$OUT/${VERSION}_perf.json"
        echo "[A11Y] perf.json: $OUT/${VERSION}_perf.json"
        ;;
    *)
        echo "❌ Unknown platform: $PLATFORM (only macos supported)"
        exit 1
        ;;
esac