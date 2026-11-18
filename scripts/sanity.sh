#!/usr/bin/env bash
# scripts/sanity.sh — Complete Repository Health & Sanity Gate
# ShortsSplitter on-device video studio
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "=== ShortsSplitter Sanity & Quality Gate ==="
cd "$PROJECT_ROOT"

echo "1. Checking Flutter & Dart environment..."
flutter --version | head -n 2

echo "2. Resolving dependencies (flutter pub get)..."
flutter pub get >/dev/null

echo "3. Verifying code formatting..."
dart format --output=none --set-exit-if-changed .
echo "✓ Code formatting is clean."

echo "4. Executing static analysis (strict mode)..."
flutter analyze --fatal-infos --fatal-warnings
echo "✓ Static analysis passed with zero issues."

echo "5. Running automated test suite..."
flutter test
echo "✓ All automated tests passed."

echo "6. Checking documentation completeness and link integrity..."
"$SCRIPT_DIR/docs_check.sh"
echo "✓ Documentation integrity verified."

echo "=================================================="
echo "🎉 ALL SANITY CHECKS PASSED — REPO IS 100% HEALTHY"
echo "=================================================="

