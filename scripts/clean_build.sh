#!/usr/bin/env bash
set -e

# ==============================================================================
# ShortsSplitter Clean Build Script
# Cleans build cache, resolves dependencies, triggers code-gen, and analyzes.
# ==============================================================================

echo "=================================================="
echo "🧹 ShortsSplitter: Clean Build & Dependency Sync"
echo "=================================================="

echo ""
echo "1. Cleaning previous build artifacts..."
flutter clean

echo ""
echo "2. Resolving project dependencies..."
flutter pub get

echo ""
echo "3. Running code generator (build_runner)..."
dart run build_runner build --delete-conflicting-outputs

echo ""
echo "4. Running static analyzer verification..."
flutter analyze

echo ""
echo "=================================================="
echo "✨ Clean build and code generation complete!"
echo "=================================================="

