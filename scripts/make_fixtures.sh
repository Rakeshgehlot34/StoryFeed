#!/usr/bin/env bash
# scripts/make_fixtures.sh — Deterministic Test Fixture Generator
# ShortsSplitter on-device video studio test suite
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
FIXTURES_DIR="$PROJECT_ROOT/test/fixtures"

echo "=== ShortsSplitter Test Fixture Generator ==="

if ! command -v ffmpeg >/dev/null 2>&1; then
  echo "Error: 'ffmpeg' is required on PATH to generate test fixtures." >&2
  exit 1
fi

mkdir -p "$FIXTURES_DIR"

echo "1. Generating 16:9 test video (test_16_9.mp4: 1920x1080 30fps with 440Hz sine audio, 10s)..."
ffmpeg -y -f lavfi -i testsrc=size=1920x1080:rate=30:duration=10 \
  -f lavfi -i sine=frequency=440:duration=10 \
  -c:v libx264 -preset ultrafast -pix_fmt yuv420p -c:a aac \
  "$FIXTURES_DIR/test_16_9.mp4" >/dev/null 2>&1

echo "2. Generating 9:16 vertical test video (test_9_16.mp4: 1080x1920 30fps with audio, 10s)..."
ffmpeg -y -f lavfi -i testsrc=size=1080x1920:rate=30:duration=10 \
  -f lavfi -i sine=frequency=523.25:duration=10 \
  -c:v libx264 -preset ultrafast -pix_fmt yuv420p -c:a aac \
  "$FIXTURES_DIR/test_9_16.mp4" >/dev/null 2>&1

echo "3. Generating rotated video metadata (test_rotated.mp4: 1920x1080 rotate=90, 5s)..."
ffmpeg -y -noautorotate -display_rotation 90 -f lavfi -i testsrc=size=1920x1080:rate=30:duration=5 \
  -f lavfi -i sine=frequency=440:duration=5 \
  -c:v libx264 -preset ultrafast -pix_fmt yuv420p -c:a aac \
  "$FIXTURES_DIR/test_rotated.mp4" >/dev/null 2>&1

echo "4. Generating silent video (test_silent.mp4: 1920x1080 no audio, 5s)..."
ffmpeg -y -f lavfi -i testsrc=size=1920x1080:rate=30:duration=5 \
  -an -c:v libx264 -preset ultrafast -pix_fmt yuv420p \
  "$FIXTURES_DIR/test_silent.mp4" >/dev/null 2>&1

echo "5. Generating variable frame rate video (test_vfr.mp4: 720p VFR, 10s)..."
ffmpeg -y -f lavfi -i testsrc=size=1280x720:rate=30:duration=10 \
  -vf "select='not(mod(n\,3))',setpts=N/(10*TB)" -fps_mode vfr \
  -c:v libx264 -preset ultrafast -pix_fmt yuv420p -an \
  "$FIXTURES_DIR/test_vfr.mp4" >/dev/null 2>&1

echo "6. Generating 70-second video for split tests (test_70s.mp4: 720p 25fps, 70s)..."
ffmpeg -y -f lavfi -i testsrc=size=1280x720:rate=25:duration=70 \
  -f lavfi -i sine=frequency=330:duration=70 \
  -c:v libx264 -preset ultrafast -pix_fmt yuv420p -c:a aac \
  "$FIXTURES_DIR/test_70s.mp4" >/dev/null 2>&1

echo "7. Generating transparent overlay logo (test_logo.png: 200x200 RGBA)..."
ffmpeg -y -f lavfi -i "color=c=blue@0.75:s=200x200:d=1" -vframes 1 \
  "$FIXTURES_DIR/test_logo.png" >/dev/null 2>&1

echo "8. Generating audio test file (test_audio.mp3: stereo 44.1kHz 660Hz tone, 10s)..."
ffmpeg -y -f lavfi -i sine=frequency=660:duration=10 \
  -c:a libmp3lame -q:a 2 \
  "$FIXTURES_DIR/test_audio.mp3" >/dev/null 2>&1

echo "=== All fixtures generated successfully in $FIXTURES_DIR ==="
ls -lh "$FIXTURES_DIR"
