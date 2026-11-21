#!/usr/bin/env bash
# ==============================================================================
# ShortsSplitter — Stop Local Web Tester
# ==============================================================================

PORT="${1:-8080}"

echo "🛑 Stopping ShortsSplitter Web Tester..."

# Find and terminate processes running server.py
pkill -f "tools/web_tester/server.py" 2>/dev/null || true

# Free port 8080 if still occupied
if command -v fuser &> /dev/null; then
    fuser -k "${PORT}/tcp" 2>/dev/null || true
fi

sleep 1

# Verify if port is freed
if command -v lsof &> /dev/null; then
    if lsof -i ":${PORT}" &> /dev/null; then
        echo "⚠️ Port $PORT is still in use by another process."
        exit 1
    fi
fi

echo "✅ Web tester stopped successfully."

