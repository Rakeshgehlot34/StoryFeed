# ShortsSplitter Commands Reference

A categorized, copy-paste ready reference of all commands used in ShortsSplitter development, maintenance, testing, and deployment.

---

## Table of Contents
1. [Flutter SDK Commands](#1-flutter-sdk-commands)
2. [Code Generation (build_runner)](#2-code-generation-build_runner)
3. [Packaging & Build Commands](#3-packaging--build-commands)
4. [Project Automation Scripts](#4-project-automation-scripts)
5. [Android Debug Bridge (adb) Reference](#5-android-debug-bridge-adb-reference)
6. [Android SDK & APK Inspection Tools](#6-android-sdk--apk-inspection-tools)
7. [Git & Conventional Commits](#7-git--conventional-commits)
8. [Antigravity Agent Slash Workflows](#8-antigravity-agent-slash-workflows)
9. [Daily Workflow & Pre-Commit Cheat Sheet](#9-daily-workflow--pre-commit-cheat-sheet)

---

## 1. Flutter SDK Commands

### Environment Diagnostics
```bash
# Check installed toolchains, licenses, connected devices, and SDK status
flutter doctor -v
# Expected: All checkmarks green for Flutter, Android toolchain, and connected device
```

### Dependency Management
```bash
# Download and link all pinned dependencies from pubspec.yaml
flutter pub get
# Expected: "Got dependencies!" with zero conflicts

# List packages that have newer versions available upstream
flutter pub outdated
# Expected: Report of current vs upgradable package versions

# Upgrade packages within semantic constraints
flutter pub upgrade
```

### Static Analysis & Formatting
```bash
# Run strict Dart static analysis against analysis_options.yaml
flutter analyze
# Expected: "No issues found!"

# Verify formatting without modifying files (fails CI if unformatted)
dart format --output=none --set-exit-if-changed .
# Expected: Formatted N files (0 changed)

# Automatically format all Dart code in the project
dart format .
# Expected: Formats any misaligned lines to standard 80-character Dart style
```

### Testing & Code Coverage
```bash
# Run the complete test suite
flutter test
# Expected: "All tests passed!"

# Run a single test file
flutter test test/features/split_config/plan_calculator_test.dart
# Expected: Executes only specified file's tests

# Run tests and generate LCOV coverage report
flutter test --coverage
# Expected: Generates coverage/lcov.info for code coverage reporting
```

### Running & Debugging
```bash
# List available hardware devices and running emulators
flutter devices

# Launch app in debug mode with hot reload
flutter run

# Launch on a specific device by ID
flutter run -d emulator-5554

# Launch in release mode with AOT compilation
flutter run --release -d emulator-5554

# Clean local build caches and intermediate artifacts
flutter clean
# Expected: Deletes build/ and .dart_tool/
```

---

## 2. Code Generation (build_runner)

```bash
# Run Drift database schema and model generator once, overwriting conflicting outputs
dart run build_runner build --delete-conflicting-outputs
# Expected: Generates lib/core/database/app_database.g.dart with zero warnings

# Run code generator in continuous watch mode during development
dart run build_runner watch --delete-conflicting-outputs
# Expected: Rebuilds generated database files automatically upon file save
```

---

## 3. Packaging & Build Commands

### Android APK Builds
```bash
# Build architecture-split release APKs (reduces download size to ~35MB per ABI)
flutter build apk --release --split-per-abi
# Expected: Outputs arm64-v8a, armeabi-v7a, and x86_64 APKs in build/app/outputs/flutter-apk/

# Build a single universal release APK containing all ABIs
flutter build apk --release
# Expected: Outputs build/app/outputs/flutter-apk/app-release.apk

# Build debug APK for rapid emulator testing
flutter build apk --debug
# Expected: Outputs build/app/outputs/flutter-apk/app-debug.apk
```

### Android App Bundle (AAB for Google Play)
```bash
# Build production App Bundle for Google Play Store upload
flutter build appbundle --release
# Expected: Outputs build/app/outputs/bundle/release/app-release.aab
```

### Obfuscation & Symbol Stripping
```bash
# Build release AAB with Dart code obfuscation and debug symbol export
flutter build appbundle --release --obfuscate --split-debug-info=build/app/outputs/symbols
# Expected: Generates obfuscated AAB and writes symbol mapping files into build/app/outputs/symbols
```

---

## 4. Project Automation Scripts

All scripts are located in `scripts/` and must be executable.

### `scripts/verify.sh`
Executes code format check, strict static analysis, unit/widget tests, and documentation integrity verification.
```bash
./scripts/verify.sh
```

### `scripts/clean_build.sh`
Cleans build cache, resolves dependencies, executes code-generation, and runs static analysis.
```bash
./scripts/clean_build.sh
```

### `scripts/build_apk.sh` (Linux / macOS)
Builds release or debug APKs with configurable architecture splitting.
```bash
# Standard release build with split ABIs
./scripts/build_apk.sh

# Debug APK build
./scripts/build_apk.sh --debug

# Universal fat APK build
./scripts/build_apk.sh --no-split-per-abi

# Target specific architecture
./scripts/build_apk.sh --target-platform android-arm64

# Display help
./scripts/build_apk.sh --help
```

### `scripts/build_apk.ps1` (Windows PowerShell)
Windows PowerShell equivalent of `build_apk.sh`.
```powershell
# Standard release build
.\scripts\build_apk.ps1

# Debug build
.\scripts\build_apk.ps1 -Debug

# Universal fat APK build
.\scripts\build_apk.ps1 -NoSplitPerAbi

# Target specific architecture
.\scripts\build_apk.ps1 -TargetPlatform android-arm64
```

### `scripts/docs_check.sh` (Linux / macOS)
Verifies all 17 documentation files exist, checks for broken relative links, scans for prohibited placeholder markers, and confirms scripts and workflows are documented.
```bash
./scripts/docs_check.sh
```

### `scripts/docs_check.ps1` (Windows PowerShell)
Windows PowerShell equivalent of `docs_check.sh`.
```powershell
.\scripts\docs_check.ps1
```

### `scripts/gen_icons.sh` / `scripts/gen_icons.ps1`
Generates adaptive app launcher icons (mipmap-mdpi through xxxhdpi), monochrome icon, notification icon, and Play Store graphics from vector SVG source.
```bash
# Linux / macOS
./scripts/gen_icons.sh

# Windows PowerShell
.\scripts\gen_icons.ps1
```

### `scripts/make_fixtures.sh` / `scripts/make_fixtures.ps1`
Generates deterministic FFmpeg test fixtures (16:9, 9:16, rotated, silent, VFR, 70s, transparent logo, MP3 audio) in `test/fixtures/`.
```bash
# Linux / macOS
./scripts/make_fixtures.sh

# Windows PowerShell
.\scripts\make_fixtures.ps1
```

### `scripts/sanity.sh` / `scripts/sanity.ps1`
Runs end-to-end repository health checks (Flutter doctor, pub get, format check, strict static analysis, complete test suite, docs verification).
```bash
# Linux / macOS
./scripts/sanity.sh

# Windows PowerShell
.\scripts\sanity.ps1
```

### `scripts/check_16kb.sh` / `scripts/check_16kb.ps1`
Verifies that all 64-bit native libraries (.so) in the APK are aligned to 16 KB (0x4000) or 64 KB (0x10000) boundaries for Android 16 (API 36) compliance.
```bash
# Linux / macOS
./scripts/check_16kb.sh [dist/ShortsSplitter-1.0.0+1-release.apk]

# Windows PowerShell
.\scripts\check_16kb.ps1 -ApkPath dist\ShortsSplitter-1.0.0+1-release.apk
```

### `scripts/make_benchmarks.sh`
Generates deterministic 1080p and 4K benchmark video fixtures using FFmpeg lavfi in `test/fixtures/`.
```bash
./scripts/make_benchmarks.sh
```

### `scripts/run_benchmarks.sh`
Executes baseline performance benchmarks across stream-copy, precise re-encode, 9:16 fit, and full-resolution blur background.
```bash
./scripts/run_benchmarks.sh
```

### `scripts/run_post_benchmarks.sh`
Executes post-optimization benchmarks measuring single-pass segment muxing, libx264 ultrafast transcode, and downscaled background blur.
```bash
./scripts/run_post_benchmarks.sh
```

### `scripts/audit_layout.py`
Executes automated layout and text overlay audit across 84 permutation combinations, saving extracted frames and geometry reports into `test/artifacts/layout_audit/`.
```bash
python3 scripts/audit_layout.py
```

### `scripts/verify_layout_and_labels.py`
Validates `FitLayout` horizontal/vertical centering symmetry, vertical positions (Center, Top, Bottom), and optional Part Label behavior against test fixtures.
```bash
python3 scripts/verify_layout_and_labels.py
```

### `scripts/verify_long_video_split.py`
Verifies end-to-end splitting of long video files (e.g. 10-minute 1080p fixtures) against planned clip segments, checking physical output files, contiguity, stream copy vs transcoding, and hard 180s cap invariants.
```bash
python3 scripts/verify_long_video_split.py
```

---

## 5. Android Debug Bridge (adb) Reference

### Device Management
```bash
# List all connected physical devices and running emulators
adb devices

# Target a specific device when multiple devices are connected
adb -s <device-id> <command>
```

### App Installation & Removal
```bash
# Install release APK, replacing existing version
adb install -r build/app/outputs/flutter-apk/app-arm64-v8a-release.apk

# Uninstall ShortsSplitter completely
adb uninstall com.shortssplitter.shorts_splitter

# Clear all local app storage, caches, and SharedPreferences
adb shell pm clear com.shortssplitter.shorts_splitter
```

### Logging & Diagnostics
```bash
# Stream logcat output filtered strictly to ShortsSplitter process and FFmpeg
adb logcat -v time | grep -E "ShortsSplitter|flutter|ffmpeg-kit"

# Clear device logcat buffer
adb logcat -c
```

### Storage & File Transfer
```bash
# Inspect files saved into the public Movies directory
adb shell ls -la /storage/emulated/0/Movies/ShortsSplitter/

# Pull exported clips from device to your computer
adb pull /storage/emulated/0/Movies/ShortsSplitter/ ./exported_clips/

# Push a test video file from computer to device gallery
adb push ./sample_video.mp4 /storage/emulated/0/Movies/
```

### Screenshots & Screen Recording
```bash
# Capture screen screenshot to device and pull to computer
adb shell screencap -p /sdcard/screen.png
adb pull /sdcard/screen.png ./screenshot.png

# Record screen video (Ctrl+C to stop)
adb shell screenrecord /sdcard/demo.mp4
adb pull /sdcard/demo.mp4 ./demo.mp4
```

### Testing Permission Grant / Revoke
```bash
# Grant notification permission (Android 13+)
adb shell pm grant com.shortssplitter.shorts_splitter android.permission.POST_NOTIFICATIONS

# Revoke notification permission
adb shell pm revoke com.shortssplitter.shorts_splitter android.permission.POST_NOTIFICATIONS

# Grant media video permission (Android 13+)
adb shell pm grant com.shortssplitter.shorts_splitter android.permission.READ_MEDIA_VIDEO

# Revoke media video permission
adb shell pm revoke com.shortssplitter.shorts_splitter android.permission.READ_MEDIA_VIDEO
```

### Foreground Service & Background Execution Diagnostics
```bash
# Verify ExportForegroundService is running in background with wake lock
adb shell dumpsys activity services com.shortssplitter.shorts_splitter

# Inspect active wake locks to verify CPU stays awake during transcode
adb shell dumpsys power | grep -A 5 "PARTIAL_WAKE_LOCK"

# Force-kill app to simulate crash and test "Resume / Discard" export recovery
adb shell am force-stop com.shortssplitter.shorts_splitter
```

---

## 6. Android SDK & APK Inspection Tools

### Emulator Management
```bash
# List installed Android Virtual Devices
emulator -list-avds

# Start an emulator instance directly from CLI
emulator -avd Pixel_8_API_35 -no-snapshot-load
```

### Inspecting Generated APK
```bash
# Inspect APK package name, version, and min/target SDK using aapt2
aapt2 dump badging build/app/outputs/flutter-apk/app-arm64-v8a-release.apk | grep -E "package|sdkVersion"

# Analyze APK size and file breakdown
apkanalyzer apk summary build/app/outputs/flutter-apk/app-arm64-v8a-release.apk
```

### Verifying Release Signature
```bash
# Verify release APK cryptographic signature
apksigner verify --verbose build/app/outputs/flutter-apk/app-arm64-v8a-release.apk
```

---

## 7. Git & Conventional Commits

ShortsSplitter strictly adheres to [Conventional Commits](https://www.conventionalcommits.org/):

```bash
# Feature addition
git commit -m "feat(trim): add precise millisecond time inputs and quick trim chips"

# Bug fix
git commit -m "fix(storage): guard against revoked SAF tree permission on Android 14"

# Performance optimization
git commit -m "perf(ffmpeg): stream content URI to temp pipe via 64KB chunks"

# Testing
git commit -m "test(plan): add unit tests for trailing remainder merge threshold"

# Documentation
git commit -m "docs(commands): index all automation scripts and agent workflows"

# Refactor
git commit -m "refactor(theme): extract AppTokens design constants"

# Tag a release
git tag -a v1.0.0 -m "Release v1.0.0: Initial production release"
git push origin v1.0.0
```

---

## 8. Antigravity Agent Slash Workflows

Automated agent procedures located in `.agents/workflows/`:

| Slash Command | Workflow File | When to Use It |
| :--- | :--- | :--- |
| `/verify` | `.agents/workflows/verify.md` | Run pre-commit checks: format, strict static analysis, and automated tests. |
| `/ui-check` | `.agents/workflows/ui-check.md` | Audit UI for design tokens compliance, 14 shared widgets, and 4 states. |
| `/compat-check` | `.agents/workflows/compat-check.md` | Verify Android API 28–35+ version guards and storage strategy compliance. |
| `/plan-check` | `.agents/workflows/plan-check.md` | Validate contiguous slice boundary math and the hard 180s cap invariant. |
| `/docs-sync` | `.agents/workflows/docs-sync.md` | Check codebase drift against `/docs`, update docs, and run integrity checks. |
| `/new-feature` | `.agents/workflows/new-feature.md` | Scaffold a new feature directory with data, domain, and presentation layers. |
| `/write-tests` | `.agents/workflows/write-tests.md` | Generate unit, widget, and provider tests using `FakeVideoProcessor`. |
| `/fix-build` | `.agents/workflows/fix-build.md` | Diagnose and resolve compiler errors, Gradle mismatches, or missing SDKs. |
| `/release-check` | `.agents/workflows/release-check.md` | Execute pre-release checklist: signing, ProGuard rules, and split APKs. |
| `/build-apk` | `.agents/workflows/build-apk.md` | Interactive workflow for compiling production, debug, or profile APKs. |
| `/lifecycle-check` | `.agents/workflows/lifecycle-check.md` | Audit single-player invariants, audio leakage prevention, and export job decoupling. |
| `/review` | `.agents/workflows/review.md` | Perform comprehensive code review against AGENTS.md rules before merging. |

---

## 9. Daily Workflow & Pre-Commit Cheat Sheet

### Daily Workflow
```bash
# 1. Pull latest changes
git pull origin main

# 2. Sync dependencies
flutter pub get

# 3. Launch emulator or connect device
emulator -avd Pixel_8_API_35 &

# 4. Start local debug session
flutter run
```

### Before Every Commit
Execute these three commands in order:
```bash
# 1. Format all code
dart format .

# 2. Complete verification suite (format + analyze + test + docs_check)
./scripts/verify.sh

# 3. Commit changes with conventional commit prefix
git add .
git commit -m "feat(scope): concise imperative description"
```
