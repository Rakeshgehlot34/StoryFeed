#!/usr/bin/env bash
# ==============================================================================
# scripts/check_16kb.sh — Android 16 (API 36) 16 KB Page Size Alignment Checker
# Verifies that all 64-bit native libraries (.so) in the APK are aligned to
# 16 KB (0x4000) or 64 KB (0x10000) boundary.
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
APK_PATH="${1:-}"

if [ -z "$APK_PATH" ]; then
    # Look for release APK in dist/ or build/
    if [ -f "$PROJECT_ROOT/dist/ShortsSplitter-1.0.0+1-release.apk" ]; then
        APK_PATH="$PROJECT_ROOT/dist/ShortsSplitter-1.0.0+1-release.apk"
    else
        APK_PATH=$(find "$PROJECT_ROOT/build/app/outputs/flutter-apk" -name "*.apk" 2>/dev/null | head -n 1 || true)
    fi
fi

if [ -z "$APK_PATH" ] || [ ! -f "$APK_PATH" ]; then
    echo "❌ APK not found. Pass the APK path as argument or build first."
    exit 1
fi

echo "=================================================="
echo "🔍 Checking 16 KB Page Size Alignment for Android 16"
echo "Target APK: $APK_PATH"
echo "=================================================="

# Locate zipalign
ZIPALIGN_BIN=""
if command -v zipalign >/dev/null 2>&1; then
    ZIPALIGN_BIN="zipalign"
elif [ -n "${ANDROID_HOME:-}" ] && [ -d "$ANDROID_HOME/build-tools" ]; then
    ZIPALIGN_BIN=$(find "$ANDROID_HOME/build-tools" -name zipalign 2>/dev/null | sort -V | tail -n 1 || true)
elif [ -d "/home/user/Android/Sdk/build-tools" ]; then
    ZIPALIGN_BIN=$(find "/home/user/Android/Sdk/build-tools" -name zipalign 2>/dev/null | sort -V | tail -n 1 || true)
fi

TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT

unzip -q "$APK_PATH" "lib/*" -d "$TMP_DIR" 2>/dev/null || true

FAIL_COUNT=0
PASS_COUNT=0

echo ""
printf "%-20s | %-35s | %-12s | %-8s\n" "ABI" "Library" "Max Align" "Status"
echo "---------------------+-------------------------------------+--------------+--------"

for so_file in $(find "$TMP_DIR/lib" -name "*.so" | sort); do
    rel_path="${so_file#$TMP_DIR/lib/}"
    abi=$(echo "$rel_path" | cut -d'/' -f1)
    lib_name=$(basename "$so_file")

    # Readelf check for LOAD segments
    alignments=$(readelf -lW "$so_file" | awk '/LOAD/ {print $NF}')
    max_align="0x0"
    for a in $alignments; do
        if [ "$a" = "0x10000" ]; then
            max_align="0x10000"
            break
        elif [ "$a" = "0x4000" ]; then
            max_align="0x4000"
        elif [ "$max_align" = "0x0" ]; then
            max_align="$a"
        fi
    done

    # 16 KB enforcement applies strictly to 64-bit architectures on Android 15/16
    status="PASS"
    if [ "$abi" = "arm64-v8a" ] || [ "$abi" = "x86_64" ]; then
        if [ "$max_align" != "0x4000" ] && [ "$max_align" != "0x10000" ]; then
            status="FAIL"
            FAIL_COUNT=$((FAIL_COUNT + 1))
        else
            PASS_COUNT=$((PASS_COUNT + 1))
        fi
    else
        # 32-bit (armeabi-v7a) uses 4KB kernel pages
        status="PASS (32b)"
        PASS_COUNT=$((PASS_COUNT + 1))
    fi

    printf "%-20s | %-35s | %-12s | %-8s\n" "$abi" "$lib_name" "$max_align" "$status"
done

echo ""
if [ -n "$ZIPALIGN_BIN" ] && [ -x "$ZIPALIGN_BIN" ]; then
    echo "Running APK zipalign verification (-P 16 -v 4)..."
    if "$ZIPALIGN_BIN" -c -P 16 -v 4 "$APK_PATH" >/dev/null 2>&1; then
        echo "✅ zipalign 16 KB page alignment check: PASSED"
    else
        echo "❌ zipalign 16 KB page alignment check: FAILED"
        FAIL_COUNT=$((FAIL_COUNT + 1))
    fi
else
    echo "ℹ️  zipalign not found in path; readelf ELF checks completed."
fi

echo ""
echo "=================================================="
if [ "$FAIL_COUNT" -eq 0 ]; then
    echo "✅ 16 KB Alignment Check PASSED ($PASS_COUNT libraries verified)"
    exit 0
else
    echo "❌ 16 KB Alignment Check FAILED ($FAIL_COUNT libraries unaligned)"
    exit 1
fi

