---
name: debug-playbook
description: Diagnostic playbook for debugging FFmpeg return codes, extracting session execution logs, and resolving permission/storage errors on Android 10-15.
---

# ShortsSplitter Debugging Playbook

This playbook outlines systematic steps to diagnose and fix failures in FFmpeg execution, storage writes, and Android permissions.

---

## 1. Diagnosing FFmpeg Failures

When an FFmpeg command fails, `FFmpegSession.getReturnCode()` returns a non-zero code.

### Step 1: Extract All Session Logs
In `FFmpegVideoProcessor.dart`, full logs are extracted upon failure:
```dart
final returnCode = await session.getReturnCode();
final logs = await session.getAllLogsAsString();
AppLogger.error('FFmpeg failed with code: $returnCode, logs: $logs');
```

### Step 2: Match Against Common FFmpeg Error Patterns

| Error Log Signature | Root Cause | Solution |
| :--- | :--- | :--- |
| `width not divisible by 2` | H.264 encoder requires even dimensions | Use `-vf "scale=trunc(iw/2)*2:trunc(ih/2)*2"` |
| `Cannot find a matching stream` | Corrupted container or audio track missing | Add `-c:a aac` or verify input stream with `FFprobeKit.getMediaInformation()` |
| `Invalid data found when processing input` | Unsupported video codec or partial download | Check video format, prompt user with `UnsupportedVideoFormatException` |
| `Output file is empty` | Missing keyframe in stream copy or write timeout | Switch from Fast to Precise mode or verify output directory write permissions |
| `Session state: FAILED (rc: 255)` | Process killed by OS or user cancellation | Handled by `OperationCancelledException` |

---

## 2. Diagnosing Android Permission Failures

### Inspecting Live Permission State
```bash
adb shell dumpsys package com.shortssplitter.shorts_splitter | grep -A 10 "runtime permissions:"
```

### Manifest vs Runtime Mismatch
- **On Android 13+ (API 33+):** If `image_picker` fails or throws `PermissionDeniedException`, ensure `READ_MEDIA_VIDEO` is declared in `AndroidManifest.xml` (NOT just `READ_EXTERNAL_STORAGE`).
- **On Android 12 and below (API $\le 32$):** Ensure `READ_EXTERNAL_STORAGE` has `android:maxSdkVersion="32"`.
- **Permanent Denial Handling:** If `isPermanentlyDenied` is true, the OS dialog will no longer display. Prompt the user to tap "Settings" using `openAppSettings()` from `permission_handler`.

---

## 3. Diagnosing Scoped Storage Write Failures (Android 10 - 15+)

### Symptom: `PathNotFoundException` or `EACCES (Permission denied)`
1. Check the target path format:
   - If path starts with `/storage/emulated/0/` (outside `/Android/data/com.shortssplitter.shorts_splitter/files/`), direct file writing by native libraries is blocked on Android 11+ unless granted via special SAF DocumentFile URIs.
2. Verify probe result:
   - Check `AppLogger` logs for `Directory <path> is not directly writable`.
3. Quick Reset:
   - Have the app call `outputController.resetToDefault()`, which returns to the always-writable app-specific folder.

---

## 4. Capturing Full Android Device Logs via ADB

```bash
# Filter for ShortsSplitter, FFmpeg, and Flutter logs
adb logcat -c # Clear buffer
adb logcat -v time | grep -E "(ShortsSplitter|flutter|ffmpeg-kit)"
```

