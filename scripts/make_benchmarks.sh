#!/usr/bin/env bash
# scripts/make_benchmarks.sh — Deterministic Benchmark Fixture Generator
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
FIXTURES_DIR="$PROJECT_ROOT/test/fixtures"

mkdir -p "$FIXTURES_DIR"

echo "=================================================="
echo "🎬 Generating Benchmark Fixtures for ShortsSplitter"
echo "=================================================="

if ! command -v ffmpeg >/dev/null 2>&1; then
  echo "Error: 'ffmpeg' is required on PATH to generate benchmark fixtures." >&2
  exit 1
fi

# 1. 10-min 1080p30 H.264 (600s)
if [ ! -f "$FIXTURES_DIR/bench_10m_1080p.mp4" ]; then
  echo "1. Generating 10-min 1080p30 H.264 video (bench_10m_1080p.mp4)..."
  ffmpeg -y -f lavfi -i testsrc=size=1920x1080:rate=30:duration=600 \
    -f lavfi -i sine=frequency=440:duration=600 \
    -c:v libx264 -preset ultrafast -g 60 -pix_fmt yuv420p -c:a aac -b:a 128k \
    "$FIXTURES_DIR/bench_10m_1080p.mp4" >/dev/null 2>&1
  echo "  ✅ bench_10m_1080p.mp4 generated."
else
  echo "  ℹ️  bench_10m_1080p.mp4 already exists."
fi

# 2. 10-min 4K (3840x2160 30fps, 600s)
if [ ! -f "$FIXTURES_DIR/bench_10m_4k.mp4" ]; then
  echo "2. Generating 10-min 4K H.264 video (bench_10m_4k.mp4)..."
  ffmpeg -y -f lavfi -i testsrc=size=3840x2160:rate=30:duration=600 \
    -f lavfi -i sine=frequency=440:duration=600 \
    -c:v libx264 -preset ultrafast -g 60 -pix_fmt yuv420p -c:a aac -b:a 128k \
    "$FIXTURES_DIR/bench_10m_4k.mp4" >/dev/null 2>&1
  echo "  ✅ bench_10m_4k.mp4 generated."
else
  echo "  ℹ️  bench_10m_4k.mp4 already exists."
fi

# 3. 30-min 1080p (1800s, 30fps)
if [ ! -f "$FIXTURES_DIR/bench_30m_1080p.mp4" ]; then
  echo "3. Generating 30-min 1080p H.264 video (bench_30m_1080p.mp4)..."
  ffmpeg -y -f lavfi -i testsrc=size=1920x1080:rate=30:duration=1800 \
    -f lavfi -i sine=frequency=440:duration=1800 \
    -c:v libx264 -preset ultrafast -g 60 -pix_fmt yuv420p -c:a aac -b:a 128k \
    "$FIXTURES_DIR/bench_30m_1080p.mp4" >/dev/null 2>&1
  echo "  ✅ bench_30m_1080p.mp4 generated."
else
  echo "  ℹ️  bench_30m_1080p.mp4 already exists."
fi

echo "=================================================="
echo "✅ All benchmark fixtures ready in $FIXTURES_DIR"
echo "=================================================="
ls -lh "$FIXTURES_DIR"/bench_*

