# ShortsSplitter Troubleshooting & Diagnostic Guide

A curated catalog of symptoms, underlying root causes, and verified fixes for build, transcode, storage, and platform issues in ShortsSplitter.

---

## Table of Contents
1. [Build & Environment Issues](#1-build--environment-issues)
2. [Storage & Scoped Storage Issues](#2-storage--scoped-storage-issues)
3. [FFmpeg & Transcoding Issues](#3-ffmpeg--transcoding-issues)
4. [Testing & CI Pipeline Issues](#4-testing--ci-pipeline-issues)
5. [ADB & Physical Device Issues](#5-adb--physical-device-issues)

---

## 1. Build & Environment Issues

### Problem 1: Java / Gradle Version Incompatibility
- **Symptom:** Build fails with `Unsupported class file major version 65` or `Android Gradle plugin requires Java 17 to run`.
- **Cause:** Android Gradle Plugin 8.x requires OpenJDK 17, but system `PATH` is pointing to Java 11 or Java 21.
- **Fix:** Point `JAVA_HOME` to OpenJDK 17:
  ```bash
  export JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64
  ```
  In Android Studio: **Settings** > **Build Tools** > **Gradle** > set **Gradle JDK** to **Java 17**.

### Problem 2: Android SDK Licenses Not Accepted
- **Symptom:** `Android license status unknown` or `Failed to install the following Android SDK packages as some licences have not been accepted`.
- **Cause:** Android SDK component licenses have not been accepted on this machine.
- **Fix:** Execute:
  ```bash
  flutter doctor --android-licenses
  ```
  Press `y` to accept each license.

### Problem 3: Manifest Merger minSdk Conflict
- **Symptom:** `uses-sdk:minSdkVersion 21 cannot be smaller than version 28 declared in library [:ffmpeg_kit_flutter_new]`.
- **Cause:** `android/app/build.gradle.kts` had `minSdk` set lower than 28.
- **Fix:** ShortsSplitter pins `minSdk = 28`. Verify in `android/app/build.gradle.kts`:
  ```kotlin
  defaultConfig {
      minSdk = 28
      targetSdk = 35
  }
  ```

### Problem 4: Windows Long Path Failures
- **Symptom:** Gradle fails with `Filename too long` or `PathTooLongException` when resolving Gradle cache.
- **Cause:** Windows 260-character `MAX_PATH` file path limit.
- **Fix:** Enable long path support in Windows registry via Administrator PowerShell:
  ```powershell
  New-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem" -Name "LongPathsEnabled" -Value 1 -PropertyType DWORD -Force
  ```

### Problem 5: Missing Native Linux Build Dependencies
- **Symptom:** `clang++ is required for Linux development` or `ninja is required`.
- **Cause:** Developing on Linux workstation without C++ compilation tools installed.
- **Fix:** Execute:
  ```bash
  sudo apt install clang cmake ninja-build pkg-config libgtk-3-dev
  ```

---

## 2. Storage & Scoped Storage Issues

### Problem 6: SecurityException on SAF Document Creation
- **Symptom:** `java.lang.SecurityException: Permission Denial: opening provider com.android.externalstorage.documents`.
- **Cause:** User selected a folder, but `takePersistableUriPermission` was not called or access was revoked by the system.
- **Fix:** Ensure `StorageBridge` requests persistable permissions:
  ```kotlin
  contentResolver.takePersistableUriPermission(
      uri,
      Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION
  )
  ```
  If revoked, `OutputRepository` detects invalid status and falls back to Tier 4 app-specific storage.

### Problem 7: Folder Access Lost After Device Reboot
- **Symptom:** Relaunching app after reboot fails to write clips to previously selected SAF folder.
- **Cause:** Non-persisted URI permissions expire upon system reboot.
- **Fix:** `OutputRepository` validates `contentResolver.persistedUriPermissions` on launch. If missing, prompts the user to re-select folder in Settings.

### Problem 8: Exported Clips Missing from System Gallery
- **Symptom:** File exists on disk, but Google Photos or device Gallery app does not show the newly exported video.
- **Cause:** Android media scanner index was not refreshed for the new file.
- **Fix:** `MediaStoreClipWriter` handles insertion directly via `MediaStore.Video.Media`. For direct file writes on API 28, trigger media scan:
  ```kotlin
  MediaScannerConnection.scanFile(context, arrayOf(file.absolutePath), arrayOf("video/mp4"), null)
  ```

### Problem 9: DocumentFile.createFile() Returns Null
- **Symptom:** `DocumentFile.createFile("video/mp4", fileName)` returns null.
- **Cause:** Destination directory was deleted, moved, or disk is full.
- **Fix:** `SafClipWriter` catches null, re-tests directory existence, and falls back to Tier 3 MediaStore or Tier 4 App-External.

### Problem 10: Out of Disk Space During Video Transcode
- **Symptom:** `IOException: write failed: ENOSPC (No space left on device)`.
- **Cause:** Device physical storage exhausted while writing high-bitrate video.
- **Fix:** `ProcessingController` aborts immediately, cleans up temporary `.mp4` chunks, stops the foreground service, and presents a clear space warning dialog.

---

## 3. FFmpeg & Transcoding Issues

### Problem 11: Audio Out of Sync in Fast Stream-Copy Mode
- **Symptom:** Video and audio drift out of sync at clip boundaries after Fast Mode split.
- **Cause:** H.264 stream copy sliced on non-zero timestamp without PTS reset.
- **Fix:** Always include `-avoid_negative_ts make_zero` in stream copy commands:
  ```bash
  ffmpeg -ss <start> -to <end> -i input.mp4 -c copy -avoid_negative_ts make_zero output.mp4
  ```

### Problem 12: Black Frames at Start of Stream-Copied Clip
- **Symptom:** First 1–2 seconds of output clip display a black screen or frozen image before video starts.
- **Cause:** Fast Mode cut landed between I-frames. The video player must wait for the next keyframe.
- **Fix:** Switch the clip to **Precise Mode** (re-encode), which decodes the prior I-frame and generates an exact keyframe at the cut timestamp.

### Problem 13: Export Killed When App Is Minimized
- **Symptom:** Video export stops after 20–30 seconds when user switches to another app.
- **Cause:** Android system battery optimizer killed the background process.
- **Fix:** ShortsSplitter launches `ExportForegroundService` holding an ongoing notification and `WAKE_LOCK`. Ensure `POST_NOTIFICATIONS` is granted on Android 13+.

### Problem 14: Unsupported Video Container / Codec
- **Symptom:** Transcoder halts with error `Invalid data found when processing input`.
- **Cause:** Input file is zero bytes, corrupted, or uses an unsupported container (e.g. raw FLV or proprietary DVR stream).
- **Fix:** App catches `ProcessingException` and routes user to `/unsupported` with instructions to use MP4/H.264.

### Problem 15: Text Overlay Badges Display Corrupted Characters or Boxes
- **Symptom:** Emoji or non-Latin characters appear as squares ("tofu") in video badges.
- **Cause:** Native FFmpeg `drawtext` filter relies on system font files which may lack glyphs for modern emoji or international scripts.
- **Fix:** ShortsSplitter renders badges to transparent PNGs via `dart:ui` (`OverlayRenderer`) and passes the image to FFmpeg via `overlay` filter, guaranteeing 100% font and emoji support.

---

## 4. Testing & CI Pipeline Issues

### Problem 16: pumpAndSettle Timed Out in Widget Tests
- **Symptom:** Test fails with `pumpAndSettle timed out`.
- **Cause:** A widget with an infinite repeating animation (e.g. `LoadingSkeleton`) was visible during `pumpAndSettle()`.
- **Fix:** Use explicit pump duration instead:
  ```dart
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
  ```
  Ensure `LoadingSkeleton` stops controllers when `MediaQuery.maybeDisableAnimationsOf(context)` is true.

### Problem 17: MissingPluginException in Headless Unit Tests
- **Symptom:** `MissingPluginException: No implementation found for method getTemporaryDirectory on channel plugins.flutter.io/path_provider`.
- **Cause:** Code under test called platform plugin without mocking platform channel or running on a real device.
- **Fix:** In `settings_controller.dart`, check `Platform.environment.containsKey('FLUTTER_TEST')` to provide instantaneous headless fallbacks without invoking platform channels.

### Problem 18: Build Runner Code-Gen Out of Sync
- **Symptom:** Compile errors in `*.g.dart` files after modifying Riverpod annotations.
- **Cause:** Stale build cache or conflicting generated files.
- **Fix:** Execute:
  ```bash
  dart run build_runner build --delete-conflicting-outputs
  ```

---

## 5. ADB & Physical Device Issues

### Problem 19: ADB Device Unauthorized
- **Symptom:** `adb devices` shows `<device_id> unauthorized`.
- **Cause:** Host computer RSA key not accepted on device screen.
- **Fix:** Execute:
  ```bash
  adb kill-server
  adb start-server
  ```
  Unlock phone screen and tap "Allow" on the USB Debugging authorization prompt.

### Problem 20: Release APK Fails Cryptographic Verification
- **Symptom:** `Failure [INSTALL_PARSE_FAILED_NO_CERTIFICATES]`.
- **Cause:** APK built without signing configuration or using mismatched key aliases.
- **Fix:** Verify signing configuration in `android/app/build.gradle.kts` and test with:
  ```bash
  apksigner verify --verbose build/app/outputs/flutter-apk/app-arm64-v8a-release.apk
  ```

### Problem 21: Android 14/15 Foreground Service Crash on Launch
- **Symptom:** `SecurityException: Starting FGS without type dataSync or mediaProcessing`.
- **Cause:** Android 14+ requires explicit foreground service types declared in manifest and passed to `startForeground()`.
- **Fix:** Manifest declares `android:foregroundServiceType="mediaProcessing|dataSync"` and Kotlin service passes `ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PROCESSING`.

### Problem 22: Background Export Killed by Aggressive OEM Battery Managers
- **Symptom:** Long video exports terminate abruptly when locking the screen or leaving the app on Xiaomi (MIUI), Huawei, or Samsung devices.
- **Cause:** Aggressive OEM process killers terminate non-system foreground services after 1-2 minutes of screen-off time regardless of partial wake locks.
- **Fix:** Direct user to grant "Unrestricted Battery" to ShortsSplitter in Android System Settings (**Settings** > **Apps** > **ShortsSplitter** > **Battery** > **Unrestricted**). On launch or resume, `ExportJobController` detects incomplete jobs and offers one-tap checkpoint recovery ("Resume Export").

### Problem 23: Video Audio Playing in Background Without Video Surface
- **Symptom:** Audio leaks and continues playing after leaving the player/trim screen or backgrounding the app.
- **Cause:** Direct instantiation of unmanaged `VideoPlayerController` instances lacking route or app lifecycle awareness.
- **Fix:** All playback is centralized in `PlayerService`. It listens to `AppLifecycleListener` (pausing on `paused`, `inactive`, `hidden`) and route transitions via `appRouteObserver` (`didPushNext`, `didPop`), ensuring audio never plays without an active, visible surface.

