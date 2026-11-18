#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# ShortsSplitter Production APK Build Script
# Linux / macOS (Bash)
# ==============================================================================

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_ROOT"

mkdir -p build dist
LOG_FILE="$PROJECT_ROOT/build/build_apk.log"
: > "$LOG_FILE"

CURRENT_STEP="Initialization"

on_error() {
  local exit_code=$?
  echo "" | tee -a "$LOG_FILE"
  echo "==================================================" | tee -a "$LOG_FILE"
  echo "❌ BUILD FAILED at step: $CURRENT_STEP" | tee -a "$LOG_FILE"
  echo "==================================================" | tee -a "$LOG_FILE"
  echo "--- Last 30 lines of build log ($LOG_FILE) ---"
  tail -n 30 "$LOG_FILE" 2>/dev/null || true
  echo "--------------------------------------------------"
  exit "$exit_code"
}
trap on_error ERR

log() {
  echo "$@" | tee -a "$LOG_FILE"
}

# ------------------------------------------------------------------------------
# 1. Parse Arguments & Set Defaults
# ------------------------------------------------------------------------------
BUILD_TYPE="release"
SPLIT_ABI=false
DO_BUMP=false
DO_CLEAN=false
DO_INSTALL=false
DO_OBFUSCATE=false
SKIP_TESTS=false
NO_OPEN=false

show_help() {
  cat << 'EOF'
ShortsSplitter APK Build Script

Usage:
  ./scripts/build_apk.sh [OPTIONS]

Options:
  --release         Build release APK (default)
  --debug           Build debug APK
  --profile         Build profile APK
  --split-abi       Build per-ABI APKs (arm64-v8a, armeabi-v7a, x86_64)
  --bump            Increment the build number in pubspec.yaml (+1)
  --clean           Run 'flutter clean' before compiling
  --install         Install APK on connected device via adb after build
  --obfuscate       Enable Dart code obfuscation (release mode only)
  --skip-tests      Skip running automated tests
  --no-open         Do not open the dist folder in file manager after build
  -h, --help        Show this help message
EOF
  exit 0
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --release)
      BUILD_TYPE="release"
      shift
      ;;
    --debug)
      BUILD_TYPE="debug"
      shift
      ;;
    --profile)
      BUILD_TYPE="profile"
      shift
      ;;
    --split-abi)
      SPLIT_ABI=true
      shift
      ;;
    --bump)
      DO_BUMP=true
      shift
      ;;
    --clean)
      DO_CLEAN=true
      shift
      ;;
    --install)
      DO_INSTALL=true
      shift
      ;;
    --obfuscate)
      DO_OBFUSCATE=true
      shift
      ;;
    --skip-tests)
      SKIP_TESTS=true
      shift
      ;;
    --no-open)
      NO_OPEN=true
      shift
      ;;
    -h|--help)
      show_help
      ;;
    *)
      echo "Unknown argument: $1"
      show_help
      ;;
  esac
done

log "=================================================="
log "🎬 ShortsSplitter: Starting APK Build ($BUILD_TYPE)"
log "=================================================="
log "Project Root: $PROJECT_ROOT"
log "Log File:     $LOG_FILE"
log ""

# ------------------------------------------------------------------------------
# 2. Pre-Flight Toolchain Checks
# ------------------------------------------------------------------------------
CURRENT_STEP="Pre-flight toolchain check"
log "1. Running pre-flight checks..."

if ! command -v flutter >/dev/null 2>&1; then
  log "❌ Error: 'flutter' is not on PATH. Please install Flutter SDK."
  exit 1
fi
log "  ✅ Flutter found: $(flutter --version | head -n 1)"

if ! command -v java >/dev/null 2>&1; then
  log "❌ Error: 'java' is not on PATH. JDK 17 is required."
  exit 1
fi
log "  ✅ Java found: $(java -version 2>&1 | head -n 1)"

# Check flutter doctor for Android toolchain issues
DOCTOR_OUTPUT=$(flutter doctor -v 2>&1 || true)
if echo "$DOCTOR_OUTPUT" | grep -q "\[✗\] Android toolchain"; then
  log "❌ Error: Android toolchain error detected in 'flutter doctor':"
  log "$DOCTOR_OUTPUT"
  exit 1
fi
log "  ✅ Android toolchain is valid."

# Non-blocking warnings check (warn only)
if echo "$DOCTOR_OUTPUT" | grep -q "\[!\] Android toolchain"; then
  log "  ⚠️ Warning: Non-blocking Android toolchain warning present."
fi

# ------------------------------------------------------------------------------
# 3. Optional Version Bump (--bump)
# ------------------------------------------------------------------------------
if [ "$DO_BUMP" = true ]; then
  CURRENT_STEP="Version bump in pubspec.yaml"
  OLD_VER_LINE=$(grep -E '^version:' pubspec.yaml | head -n 1)
  if [[ "$OLD_VER_LINE" =~ ^version:[[:space:]]*([0-9]+\.[0-9]+\.[0-9]+)\+([0-9]+)$ ]]; then
    VER_NAME="${BASH_REMATCH[1]}"
    BUILD_NUM="${BASH_REMATCH[2]}"
    NEW_BUILD_NUM=$((BUILD_NUM + 1))
    NEW_VER="${VER_NAME}+${NEW_BUILD_NUM}"
    sed -i -E "s/^version:[[:space:]]*.*/version: ${NEW_VER}/" pubspec.yaml
    log "  ✅ Version bumped: ${VER_NAME}+${BUILD_NUM} -> ${NEW_VER}"
  else
    log "❌ Error: Could not parse version line in pubspec.yaml: '$OLD_VER_LINE'"
    exit 1
  fi
fi

# Read current version from pubspec.yaml
VER_LINE=$(grep -E '^version:' pubspec.yaml | head -n 1)
if [[ "$VER_LINE" =~ ^version:[[:space:]]*([0-9]+\.[0-9]+\.[0-9]+)\+([0-9]+)$ ]]; then
  VERSION_NAME="${BASH_REMATCH[1]}"
  BUILD_NUMBER="${BASH_REMATCH[2]}"
else
  VERSION_NAME="1.0.0"
  BUILD_NUMBER="1"
fi
FULL_VERSION="${VERSION_NAME}+${BUILD_NUMBER}"
log "  Target Version: $FULL_VERSION"

# ------------------------------------------------------------------------------
# 4. Check Signing Configuration
# ------------------------------------------------------------------------------
CURRENT_STEP="Signing configuration check"
IS_SIGNED="debug-signed"
if [ -f "android/key.properties" ]; then
  IS_SIGNED="signed"
  log "  ✅ Release signing key found in android/key.properties (signed build)."
else
  log ""
  log "  ⚠️ WARNING: android/key.properties was NOT found!"
  log "     The APK will be signed using Android's default debug key."
  log "     This APK is NOT valid for Google Play Store production release."
  log ""
  log "     To configure release signing:"
  log "       1. keytool -genkey -v -keystore android/release-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias shortssplitter"
  log "       2. Create android/key.properties with storeFile, storePassword, keyAlias, and keyPassword."
  log ""
fi

# ------------------------------------------------------------------------------
# 5. Build Steps: Clean, Pub Get, Build Runner, Analyze, Test
# ------------------------------------------------------------------------------
if [ "$DO_CLEAN" = true ]; then
  CURRENT_STEP="Cleaning project"
  log "2. Cleaning project (flutter clean)..."
  flutter clean >/dev/null 2>&1 || true
  mkdir -p "$PROJECT_ROOT/build" "$PROJECT_ROOT/dist"
  touch "$LOG_FILE"
  log "  ✅ Clean complete."
fi

CURRENT_STEP="Fetching dependencies"
log "3. Resolving dependencies (flutter pub get)..."
flutter pub get >> "$LOG_FILE" 2>&1
log "  ✅ Dependencies resolved."

if grep -q "build_runner:" pubspec.yaml; then
  CURRENT_STEP="Running code generation (build_runner)"
  log "4. Running code generation (build_runner)..."
  dart run build_runner build --delete-conflicting-outputs >> "$LOG_FILE" 2>&1
  log "  ✅ Code generation complete."
fi

CURRENT_STEP="Static analysis"
log "5. Running static analysis (flutter analyze)..."
if ! flutter analyze >> "$LOG_FILE" 2>&1; then
  log "❌ Static analysis failed! Inspecting issues:"
  flutter analyze || true
  exit 1
fi
log "  ✅ Static analysis passed."

if [ "$SKIP_TESTS" = false ]; then
  CURRENT_STEP="Running automated tests"
  log "6. Running automated test suite (flutter test)..."
  if ! flutter test >> "$LOG_FILE" 2>&1; then
    log "❌ Automated tests failed!"
    tail -n 20 "$LOG_FILE"
    exit 1
  fi
  log "  ✅ Automated tests passed."
else
  log "6. Skipping automated tests (--skip-tests specified)."
fi

# ------------------------------------------------------------------------------
# 6. Flutter Build APK
# ------------------------------------------------------------------------------
CURRENT_STEP="Compiling APK (flutter build apk)"
log "7. Compiling APK..."

BUILD_CMD=("flutter" "build" "apk")
if [ "$BUILD_TYPE" = "release" ]; then
  BUILD_CMD+=("--release")
elif [ "$BUILD_TYPE" = "debug" ]; then
  BUILD_CMD+=("--debug")
elif [ "$BUILD_TYPE" = "profile" ]; then
  BUILD_CMD+=("--profile")
fi

if [ "$SPLIT_ABI" = true ]; then
  BUILD_CMD+=("--split-per-abi")
fi

if [ "$DO_OBFUSCATE" = true ] && [ "$BUILD_TYPE" = "release" ]; then
  mkdir -p build/symbols
  BUILD_CMD+=("--obfuscate" "--split-debug-info=build/symbols")
fi

log "  Executing: ${BUILD_CMD[*]}"
"${BUILD_CMD[@]}" >> "$LOG_FILE" 2>&1
log "  ✅ APK compilation succeeded."

# ------------------------------------------------------------------------------
# 7. Locate & Copy Output Artifacts to dist/
# ------------------------------------------------------------------------------
CURRENT_STEP="Packaging & archiving APK(s)"
OUTPUT_DIR="$PROJECT_ROOT/build/app/outputs/flutter-apk"
PRODUCED_APKS=()

if [ "$SPLIT_ABI" = true ]; then
  ABIS=("arm64-v8a" "armeabi-v7a" "x86_64")
  for abi in "${ABIS[@]}"; do
    ORIG_APK="$OUTPUT_DIR/app-${abi}-${BUILD_TYPE}.apk"
    if [ -f "$ORIG_APK" ]; then
      DEST_NAME="ShortsSplitter-${FULL_VERSION}-${BUILD_TYPE}-${abi}.apk"
      DEST_APK="$PROJECT_ROOT/dist/$DEST_NAME"
      cp -f "$ORIG_APK" "$DEST_APK"
      PRODUCED_APKS+=("$ORIG_APK|$DEST_APK|$abi")
    fi
  done
else
  ORIG_APK="$OUTPUT_DIR/app-${BUILD_TYPE}.apk"
  if [ -f "$ORIG_APK" ]; then
    DEST_NAME="ShortsSplitter-${FULL_VERSION}-${BUILD_TYPE}.apk"
    DEST_APK="$PROJECT_ROOT/dist/$DEST_NAME"
    cp -f "$ORIG_APK" "$DEST_APK"
    PRODUCED_APKS+=("$ORIG_APK|$DEST_APK|universal")
  fi
fi

if [ ${#PRODUCED_APKS[@]} -eq 0 ]; then
  log "❌ Error: Could not locate built APK files under $OUTPUT_DIR"
  exit 1
fi

# Keep only the 5 most recent APKs in dist/
cd "$PROJECT_ROOT/dist"
# shellcheck disable=SC2012
OLD_APKS=$(ls -t *.apk 2>/dev/null | tail -n +6 || true)
if [ -n "$OLD_APKS" ]; then
  echo "$OLD_APKS" | xargs -r rm -f
fi
cd "$PROJECT_ROOT"

# ------------------------------------------------------------------------------
# 8. Toolchain Helpers for APK Verification & ADB
# ------------------------------------------------------------------------------
find_aapt2() {
  if command -v aapt2 >/dev/null 2>&1; then
    command -v aapt2
    return 0
  fi
  local sdk_dirs=()
  [ -n "${ANDROID_HOME:-}" ] && sdk_dirs+=("$ANDROID_HOME")
  [ -n "${ANDROID_SDK_ROOT:-}" ] && sdk_dirs+=("$ANDROID_SDK_ROOT")
  sdk_dirs+=("$HOME/Android/Sdk" "$HOME/Library/Android/sdk")
  for sdk in "${sdk_dirs[@]}"; do
    if [ -d "$sdk/build-tools" ]; then
      local candidate
      candidate=$(find "$sdk/build-tools" -name aapt2 2>/dev/null | sort -V | tail -n 1)
      if [ -n "$candidate" ] && [ -x "$candidate" ]; then
        echo "$candidate"
        return 0
      fi
    fi
  done
  return 1
}

find_adb() {
  if command -v adb >/dev/null 2>&1; then
    command -v adb
    return 0
  fi
  local sdk_dirs=()
  [ -n "${ANDROID_HOME:-}" ] && sdk_dirs+=("$ANDROID_HOME")
  [ -n "${ANDROID_SDK_ROOT:-}" ] && sdk_dirs+=("$ANDROID_SDK_ROOT")
  sdk_dirs+=("$HOME/Android/Sdk" "$HOME/Library/Android/sdk")
  for sdk in "${sdk_dirs[@]}"; do
    if [ -x "$sdk/platform-tools/adb" ]; then
      echo "$sdk/platform-tools/adb"
      return 0
    fi
  done
  return 1
}

# ------------------------------------------------------------------------------
# 9. Verify APK Badging (aapt2)
# ------------------------------------------------------------------------------
CURRENT_STEP="Verifying APK manifest badging"
log ""
log "8. Verifying APK binary metadata..."
AAPT2_BIN=$(find_aapt2 || true)
MIN_SDK_FOUND="28"

for item in "${PRODUCED_APKS[@]}"; do
  IFS="|" read -r orig dest abi <<< "$item"
  if [ -n "$AAPT2_BIN" ] && [ -x "$AAPT2_BIN" ]; then
    BADGING=$("$AAPT2_BIN" dump badging "$dest" 2>/dev/null || true)
    if [ -n "$BADGING" ]; then
      PKG_NAME=$(echo "$BADGING" | grep -oE "package: name='[^']+'" | head -n 1 | cut -d"'" -f2 || true)
      V_NAME=$(echo "$BADGING" | grep -oE "versionName='[^']+'" | head -n 1 | cut -d"'" -f2 || true)
      V_CODE=$(echo "$BADGING" | grep -oE "versionCode='[^']+'" | head -n 1 | cut -d"'" -f2 || true)
      MIN_SDK_FOUND=$(echo "$BADGING" | grep -oE "(minSdkVersion|sdkVersion):'[^']+'" | head -n 1 | cut -d"'" -f2 || echo "28")
      TARGET_SDK=$(echo "$BADGING" | grep -oE "targetSdkVersion:'[^']+'" | head -n 1 | cut -d"'" -f2 || true)

      log "  [$abi] Verified via aapt2:"
      log "     Package:    $PKG_NAME"
      log "     Version:    $V_NAME ($V_CODE)"
      log "     Min SDK:    $MIN_SDK_FOUND"
      log "     Target SDK: $TARGET_SDK"

      if [ "$MIN_SDK_FOUND" != "28" ]; then
        log "  ⚠️ WARNING: minSdkVersion is '$MIN_SDK_FOUND' (expected 28)!"
      fi
    else
      log "  [$abi] aapt2 could not parse badging."
    fi
  else
    log "  (aapt2 not found; skipping binary manifest verification)"
    break
  fi
done

# ------------------------------------------------------------------------------
# 9. Verify 16 KB Page Alignment (Android 16 / API 36)
# ------------------------------------------------------------------------------
CURRENT_STEP="16 KB page size verification"
log ""
log "9. Verifying 16 KB page-size alignment for Android 16..."
for item in "${PRODUCED_APKS[@]}"; do
  IFS="|" read -r orig dest abi <<< "$item"
  if [ -f "$PROJECT_ROOT/scripts/check_16kb.sh" ]; then
    bash "$PROJECT_ROOT/scripts/check_16kb.sh" "$dest"
  fi
done

# ------------------------------------------------------------------------------
# 10. Print Final Summary Block
# ------------------------------------------------------------------------------
CURRENT_STEP="Summary generation"
BUILD_TIME=$(date +"%Y-%m-%d %H:%M:%S")

calculate_sha256() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | awk '{print $1}'
  elif command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$1" | awk '{print $1}'
  else
    echo "N/A"
  fi
}

calculate_size() {
  if command -v numfmt >/dev/null 2>&1; then
    numfmt --to=iec --suffix=B "$(wc -c < "$1")"
  else
    ls -lh "$1" | awk '{print $5}'
  fi
}

echo ""
echo "========== BUILD SUCCESS =========="
echo "App:        ShortsSplitter"
echo "Version:    $FULL_VERSION"
echo "Build type: $BUILD_TYPE ($IS_SIGNED)"

for item in "${PRODUCED_APKS[@]}"; do
  IFS="|" read -r orig dest abi <<< "$item"
  SIZE_STR=$(calculate_size "$dest")
  SHA_STR=$(calculate_sha256 "$dest")
  
  if [ "$SPLIT_ABI" = true ]; then
    echo ""
    echo "[$abi]"
  fi
  echo "APK path:   $dest"
  echo "Original:   $orig"
  echo "Size:       $SIZE_STR"
  echo "SHA-256:    $SHA_STR"
  echo "Min SDK:    $MIN_SDK_FOUND"
  echo "Built at:   $BUILD_TIME"
  echo "Install:    adb install -r \"$dest\""
done
echo "==================================="
echo ""

# ------------------------------------------------------------------------------
# 11. Optional Install on Connected Device (--install)
# ------------------------------------------------------------------------------
if [ "$DO_INSTALL" = true ]; then
  CURRENT_STEP="Device installation"
  ADB_BIN=$(find_adb || true)
  if [ -n "$ADB_BIN" ] && [ -x "$ADB_BIN" ]; then
    CONNECTED_DEVICES=$("$ADB_BIN" devices | grep -v "List of devices" | grep "device$" || true)
    if [ -n "$CONNECTED_DEVICES" ]; then
      FIRST_APK=""
      for item in "${PRODUCED_APKS[@]}"; do
        IFS="|" read -r orig dest abi <<< "$item"
        FIRST_APK="$dest"
        break
      done
      log "Installing $FIRST_APK onto connected device..."
      "$ADB_BIN" install -r "$FIRST_APK" | tee -a "$LOG_FILE"
      log "✅ Installation complete."
    else
      log "ℹ️  Skipping install: no connected device detected via adb."
    fi
  else
    log "ℹ️  Skipping install: 'adb' tool not found on PATH or Android SDK."
  fi
fi

# ------------------------------------------------------------------------------
# 12. Open dist folder in file manager (unless --no-open)
# ------------------------------------------------------------------------------
if [ "$NO_OPEN" = false ]; then
  if [ -n "${DISPLAY:-}" ] || [ -n "${WAYLAND_DISPLAY:-}" ]; then
    if command -v xdg-open >/dev/null 2>&1; then
      xdg-open "$PROJECT_ROOT/dist" >/dev/null 2>&1 || true
    fi
  elif command -v open >/dev/null 2>&1; then
    open "$PROJECT_ROOT/dist" >/dev/null 2>&1 || true
  fi
fi

exit 0
