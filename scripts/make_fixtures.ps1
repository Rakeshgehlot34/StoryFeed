# scripts/make_fixtures.ps1 — Deterministic Test Fixture Generator (Windows PowerShell)
# ShortsSplitter on-device video studio test suite
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$projectRoot = Split-Path -Parent $scriptDir
$fixturesDir = Join-Path $projectRoot "test\fixtures"

Write-Host "=== ShortsSplitter Test Fixture Generator ===" -ForegroundColor Cyan

if (-not (Get-Command "ffmpeg" -ErrorAction SilentlyContinue)) {
    Write-Error "'ffmpeg' is required on PATH to generate test fixtures."
}

if (-not (Test-Path $fixturesDir)) {
    New-Item -ItemType Directory -Path $fixturesDir -Force | Out-Null
}

Write-Host "1. Generating 16:9 test video (test_16_9.mp4: 1920x1080 30fps with 440Hz sine audio, 10s)..."
& ffmpeg -y -f lavfi -i testsrc=size=1920x1080:rate=30:duration=10 `
  -f lavfi -i sine=frequency=440:duration=10 `
  -c:v libx264 -preset ultrafast -pix_fmt yuv420p -c:a aac `
  (Join-Path $fixturesDir "test_16_9.mp4") *>$null

Write-Host "2. Generating 9:16 vertical test video (test_9_16.mp4: 1080x1920 30fps with audio, 10s)..."
& ffmpeg -y -f lavfi -i testsrc=size=1080x1920:rate=30:duration=10 `
  -f lavfi -i sine=frequency=523.25:duration=10 `
  -c:v libx264 -preset ultrafast -pix_fmt yuv420p -c:a aac `
  (Join-Path $fixturesDir "test_9_16.mp4") *>$null

Write-Host "3. Generating rotated video metadata (test_rotated.mp4: 1920x1080 rotate=90, 5s)..."
& ffmpeg -y -noautorotate -display_rotation 90 -f lavfi -i testsrc=size=1920x1080:rate=30:duration=5 `
  -f lavfi -i sine=frequency=440:duration=5 `
  -c:v libx264 -preset ultrafast -pix_fmt yuv420p -c:a aac `
  (Join-Path $fixturesDir "test_rotated.mp4") *>$null

Write-Host "4. Generating silent video (test_silent.mp4: 1920x1080 no audio, 5s)..."
& ffmpeg -y -f lavfi -i testsrc=size=1920x1080:rate=30:duration=5 `
  -an -c:v libx264 -preset ultrafast -pix_fmt yuv420p `
  (Join-Path $fixturesDir "test_silent.mp4") *>$null

Write-Host "5. Generating variable frame rate video (test_vfr.mp4: 720p VFR, 10s)..."
& ffmpeg -y -f lavfi -i testsrc=size=1280x720:rate=30:duration=10 `
  -vf "select='not(mod(n\,3))',setpts=N/(10*TB)" -fps_mode vfr `
  -c:v libx264 -preset ultrafast -pix_fmt yuv420p -an `
  (Join-Path $fixturesDir "test_vfr.mp4") *>$null

Write-Host "6. Generating 70-second video for split tests (test_70s.mp4: 720p 25fps, 70s)..."
& ffmpeg -y -f lavfi -i testsrc=size=1280x720:rate=25:duration=70 `
  -f lavfi -i sine=frequency=330:duration=70 `
  -c:v libx264 -preset ultrafast -pix_fmt yuv420p -c:a aac `
  (Join-Path $fixturesDir "test_70s.mp4") *>$null

Write-Host "7. Generating transparent overlay logo (test_logo.png: 200x200 RGBA)..."
& ffmpeg -y -f lavfi -i "color=c=blue@0.75:s=200x200:d=1" -vframes 1 `
  (Join-Path $fixturesDir "test_logo.png") *>$null

Write-Host "8. Generating audio test file (test_audio.mp3: stereo 44.1kHz 660Hz tone, 10s)..."
& ffmpeg -y -f lavfi -i sine=frequency=660:duration=10 `
  -c:a libmp3lame -q:a 2 `
  (Join-Path $fixturesDir "test_audio.mp3") *>$null

Write-Host "=== All fixtures generated successfully in $fixturesDir ===" -ForegroundColor Green
Get-ChildItem -Path $fixturesDir | Format-Table Name, Length, LastWriteTime
