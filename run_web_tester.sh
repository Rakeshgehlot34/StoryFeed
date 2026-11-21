#!/usr/bin/env bash
# ==============================================================================
# ShortsSplitter — Local Web Tester Launcher
# ==============================================================================
# Runs a lightweight, standalone local web server on your computer to test
# 9:16 Shorts cropping, video splitting, blurred backgrounds, and in-browser
# playback before exporting to mobile.
# ==============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WEB_TESTER_DIR="$SCRIPT_DIR/tools/web_tester"
SERVER_PY="$WEB_TESTER_DIR/server.py"
PORT="${1:-8080}"

echo "================================================================="
echo " 🚀 Starting ShortsSplitter Local Web Tester..."
echo "================================================================="

# Check Python 3
if ! command -v python3 &> /dev/null; then
    echo "❌ Error: python3 is not installed or not in PATH."
    exit 1
fi

# Check FFmpeg
if ! command -v ffmpeg &> /dev/null && [ ! -f "$HOME/.local/bin/ffmpeg" ]; then
    echo "❌ Error: FFmpeg is not installed or not in PATH."
    exit 1
fi

chmod +x "$SERVER_PY"

echo "✅ Environment verified."
echo "🌐 Starting server on http://localhost:$PORT"
echo "-----------------------------------------------------------------"
echo "👉 Open this link in your browser: http://localhost:$PORT"
echo "👉 Press Ctrl+C to stop the server anytime."
echo "================================================================="

exec python3 "$SERVER_PY" "$PORT"

