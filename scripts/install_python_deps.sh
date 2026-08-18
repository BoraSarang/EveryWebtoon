#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
VENV_DIR="$PROJECT_DIR/.venv"

echo "📦 Setting up Python virtual environment..."
python3 -m venv "$VENV_DIR"
source "$VENV_DIR/bin/activate"

echo "📦 Installing dependencies..."
pip install --quiet -r "$PROJECT_DIR/backend/requirements.txt"

echo "✅ Done — Virtual environment at: $VENV_DIR"
