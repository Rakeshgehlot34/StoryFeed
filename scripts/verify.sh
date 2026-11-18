#!/usr/bin/env bash
set -e

# ==============================================================================
# ShortsSplitter Verification Script
# Executes code format check, static analysis, and automated tests.
# ==============================================================================

echo "=================================================="
echo "🎬 ShortsSplitter: Pre-Commit Quality Verification"
echo "=================================================="

echo ""
echo "1. Checking Dart code formatting..."
if ! dart format --output=none --set-exit-if-changed .; then
  echo "❌ Dart code formatting check failed! Run 'dart format .' to fix."
  exit 1
fi
echo "✅ Code formatting is clean."

echo ""
echo "2. Running Flutter static analysis (strict mode)..."
if ! flutter analyze; then
  echo "❌ Static analysis failed! Please fix all analyzer warnings/errors above."
  exit 1
fi
echo "✅ Static analysis passed with zero issues."

echo ""
echo "3. Running automated test suite..."
if ! flutter test; then
  echo "❌ Automated tests failed!"
  exit 1
fi
echo "✅ All tests passed successfully."

echo ""
echo "4. Checking documentation integrity..."
if ! ./scripts/docs_check.sh; then
  echo "❌ Documentation integrity check failed!"
  exit 1
fi
echo "✅ Documentation is complete and valid."

echo ""
echo "5. Checking 16 KB page-size alignment for Android 16..."
if [ -f "dist/ShortsSplitter-1.0.0+1-release.apk" ]; then
  ./scripts/check_16kb.sh "dist/ShortsSplitter-1.0.0+1-release.apk"
else
  echo "ℹ️  No APK in dist/. Skipping 16 KB alignment check."
fi

echo ""
echo "=================================================="
echo "🎉 ALL CHECKS PASSED: Ready for commit and PR!"
echo "=================================================="

