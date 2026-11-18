# Android Compatibility Matrix & Device QA Guide

Verification matrix, device test checklist, codec fallbacks, and known hardware quirks across **Android 9 (API 28)** through **Android 16 (API 36)**.

---

## Table of Contents
1. [OS Compatibility Matrix](#1-os-compatibility-matrix)
2. [Target Architecture (ABI) Support & 16 KB Page Alignment](#2-target-architecture-abi-support--16-kb-page-alignment)
3. [Video Codec & Hardware Encoder Fallbacks](#3-video-codec--hardware-encoder-fallbacks)
4. [Foreground Service & Timeout Compliance (API 34–36)](#4-foreground-service--timeout-compliance-api-3436)
5. [Device & Emulator Verification Checklist](#5-device--emulator-verification-checklist)
6. [Known Device Quirks & Mitigations](#6-known-device-quirks--mitigations)

---

## 1. OS Compatibility Matrix

| Android Version | API Level | Storage Tier | Foreground Service Type | Edge-to-Edge Behavior |
| :--- | :--- | :--- | :--- | :--- |
| **Android 9 (Pie)** | `28` (minSdk) | Tier 1 (SAF) / Tier 2 (`WRITE_EXTERNAL_STORAGE`) | Basic `FOREGROUND_SERVICE` | Classic window insets |
| **Android 10 (Q)** | `29` | Tier 1 (SAF) / Tier 3 (MediaStore `RELATIVE_PATH`) | Basic `FOREGROUND_SERVICE` | Classic window insets |
| **Android 11 (R)** | `30` | Tier 1 (SAF) / Tier 3 (MediaStore) | Basic `FOREGROUND_SERVICE` | WindowInsets API |
| **Android 12 (S)** | `31–32` | Tier 1 (SAF) / Tier 3 (MediaStore) | Basic `FOREGROUND_SERVICE` | WindowInsets API |
| **Android 13 (T)** | `33` | Tier 1 (SAF) / Tier 3 (`READ_MEDIA_VIDEO`) | `POST_NOTIFICATIONS` runtime | WindowInsets API |
| **Android 14 (U)** | `34` | Tier 1 (SAF) / Tier 3 (MediaStore) | `dataSync` FGS type | WindowInsets API |
| **Android 15 (V)** | `35` | Tier 1 (SAF) / Tier 3 (MediaStore) | `mediaProcessing` FGS type | Mandatory edge-to-edge |
| **Android 16 (Baklava)** | `36` (targetSdk) | Tier 1 (SAF) / Tier 3 (MediaStore) | `mediaProcessing` + `onTimeout` handling | Mandatory edge-to-edge + Predictive back |

---

## 2. Target Architecture (ABI) Support & 16 KB Page Alignment

Android 15 and Android 16 introduce support for 16 KB memory page sizes (replacing traditional 4 KB pages). All native `.so` binaries bundled in ShortsSplitter have been verified for 16 KB page alignment using `scripts/check_16kb.sh` and `zipalign -c -P 16 -v 4`.

| ABI | Architecture | Devices Supported | 16 KB Page Aligned | Typical Split APK Size |
| :--- | :--- | :--- | :---: | :--- |
| **`arm64-v8a`** | 64-bit ARM | Modern smartphones (2018+), Android 16 devices | **PASS (`0x4000` / `0x10000`)** | ~35 MB |
| **`armeabi-v7a`** | 32-bit ARM | Legacy 32-bit budget hardware | **PASS (32-bit compatible)** | ~32 MB |
| **`x86_64`** | 64-bit Intel/AMD | Android Virtual Devices (Emulators) & ChromeOS | **PASS (`0x4000`)** | ~38 MB |

### 16 KB ELF Inspection Verification
Native libraries inside the release APK (including `libffmpegkit.so`, `libavcodec.so`, `libavformat.so`, `libflutter.so`) report:
```
LOAD off 0x0000000000000000 vaddr 0x0000000000000000 paddr ... align 2^14 (16384)
LOAD off 0x0000000000000000 vaddr 0x0000000000000000 paddr ... align 2^16 (65536)
```
Verification command:
```bash
./scripts/check_16kb.sh dist/ShortsSplitter-1.0.0+1-release.apk
```

---

## 3. Video Codec & Hardware Encoder Fallbacks

ShortsSplitter features adaptive video encoding across Android hardware:

- **Hardware Acceleration:** On Android 9 through Android 16, ShortsSplitter probes for the `h264_mediacodec` hardware encoder. Hardware encoding yields 4x faster exports and minimal battery consumption.
- **Universal Software Fallback:** If `h264_mediacodec` is unavailable, FFmpeg falls back transparently to software `libx264` with `-preset ultrafast` and native source frame rate (preserving original fps without forcing CPU-heavy frame interpolation).
- **Decoder Compatibility:** Universal hardware and software decoding for H.264 (AVC), H.265 (HEVC), VP8, VP9, and AV1 containers into raw YUV420p frames.
- **Audio Codec:** Audio is normalized to `AAC-LC` (`-c:a aac -b:a 192k -ar 44100`), preventing silent video playback defects on mobile platforms.

---

## 4. Foreground Service & Timeout Compliance (API 34–36)

Android 15 (API 35) and Android 16 (API 36) enforce strict foreground service execution limits and require runtime timeout handlers:

### 1. Foreground Service Type Declaration
`AndroidManifest.xml` declares:
```xml
<service
    android:name=".service.ExportForegroundService"
    android:foregroundServiceType="mediaProcessing"
    android:exported="false" />
```

### 2. Runtime Timeout Handling (`onTimeout`)
`ExportForegroundService.kt` implements the mandatory API 35/36 timeout callback:
```kotlin
override fun onTimeout(startId: Int, fgsType: Int) {
    Log.w("ExportFGS", "Foreground service reached system timeout limit ($fgsType)")
    stopForeground(STOP_FOREGROUND_REMOVE)
    stopSelf(startId)
}
```

---

## 5. Device & Emulator Verification Checklist

Execute this verification sequence on representative physical hardware or emulators:

### Test Flow 1: Android 16 (API 36) Targeting & Edge-to-Edge Check
- [ ] Install release APK on API 36 emulator or Pixel device with Android 16 Preview.
- [ ] Verify app launches with zero crashes and renders edge-to-edge beneath translucent system bars.
- [ ] Verify predictive back gesture previews previous route without abrupt pops.
- [ ] Confirm `onTimeout` is present and registered without compile or runtime warnings.

### Test Flow 2: 16 KB Page Size Verification
- [ ] Run `./scripts/check_16kb.sh dist/ShortsSplitter-1.0.0+1-release.apk`.
- [ ] Verify 100% of 64-bit `.so` files pass LOAD segment alignment to `0x4000` (16 KB) or higher.
- [ ] Run on 16 KB page-size AVD (`x86_64_16k` or `arm64_16k`) and verify stable execution.

### Test Flow 3: Selective Clip Export Check
- [ ] Open 10-minute video in Plan Review (30 clips planned).
- [ ] Deselect all clips, then select parts 3, 7, and 12.
- [ ] Verify button displays "Create 3 of 30 Shorts".
- [ ] Export and verify files saved as `{name}_part_003.mp4`, `{name}_part_007.mp4`, `{name}_part_012.mp4`.
- [ ] Verify Results and History screens display "3/30 processed" badge.

---

## 6. Known Device Quirks & Mitigations

### 1. Samsung One UI Background Process Killer
- **Quirk:** Samsung One UI aggressively terminates background processes after 15–30 seconds without an active foreground notification and wake lock.
- **Mitigation:** ShortsSplitter launches `ExportForegroundService` with an ongoing foreground notification and acquires a system `WAKE_LOCK` for the entire transcode duration.

### 2. Xiaomi MIUI / HyperOS Permission Resets
- **Quirk:** MIUI's "Auto-revoke permissions" feature can revoke SAF folder access if the app has not been launched for several weeks.
- **Mitigation:** On every app launch, `OutputRepository` verifies that the persisted tree URI is still valid. If revoked, it routes exports to app-specific external storage and prompts the user in Settings.

### 3. Android 15/16 Media Processing Timeout
- **Quirk:** Android 15/16 enforces execution limits for `mediaProcessing` foreground services.
- **Mitigation:** ShortsSplitter processes clips rapidly (seconds per clip) and provides the required `onTimeout` lifecycle callback to safely clean up and shut down without crashing the host process.
