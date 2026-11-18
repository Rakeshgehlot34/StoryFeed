---
name: android-scoped-storage
description: Comprehensive guide to Android Scoped Storage (API 29-35+), SAF directory picking, MediaStore fallback, and POSIX write verification in ShortsSplitter.
---

# Android Scoped Storage & Directory Persistence

This skill outlines how `ShortsSplitter` writes video clips to storage without triggering permission crashes or Play Store rejections.

---

## 1. Permission Matrix per Android API Level

| Android Version | API Level | Read Permission Required | Write Permission Required | Scoped Storage Mode |
| :--- | :--- | :--- | :--- | :--- |
| **Android 9 & below** | $\le 28$ | `READ_EXTERNAL_STORAGE` | `WRITE_EXTERNAL_STORAGE` | Legacy POSIX filesystem |
| **Android 10** | 29 | `READ_EXTERNAL_STORAGE` | `WRITE_EXTERNAL_STORAGE` | Scoped Storage with `requestLegacyExternalStorage="true"` |
| **Android 11 - 12L** | 30 - 32 | `READ_EXTERNAL_STORAGE` | None (Forbidden) | Strict Scoped Storage |
| **Android 13 - 15+** | 33 - 35+ | `READ_MEDIA_VIDEO` | None (Forbidden) | Granular Media Permissions |

### App-Specific Storage Exemption
Files written inside the app's private external files directory:
```
/storage/emulated/0/Android/data/com.shortssplitter.shorts_splitter/files/ShortsSplitter/
```
**Require ZERO permissions on Android 4.4 through Android 15+.**
This is the default fallback directory resolved by `StorageUtils.getAppDefaultOutputDirectory()`.

---

## 2. Storage Access Framework (SAF) Workflow

When the user taps "Change Save Location", the app calls:
```dart
final selectedPath = await FilePicker.platform.getDirectoryPath(
  dialogTitle: 'Select folder to save YouTube Shorts clips',
);
```

### The Scoped Storage Dilemma
Native FFmpeg binaries execute C `fopen()` / POSIX write calls. On Android 11+ (API 30+), arbitrary directories selected via SAF return either:
1. A real file path (e.g. `/storage/emulated/0/Download`) which may deny raw POSIX write permissions to external apps.
2. A `content://tree/...` URI which native C code cannot write to without Java JNI DocumentFile wrappers.

### The ShortsSplitter Solution: Pre-Flight Write Probing
Before accepting any directory, `StorageUtils.testDirectoryWritable()` runs a probe:
```dart
static Future<bool> testDirectoryWritable(String directoryPath) async {
  try {
    final dir = Directory(directoryPath);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    final probeFile = File(p.join(dir.path, '.probe_${DateTime.now().millisecondsSinceEpoch}.tmp'));
    await probeFile.writeAsString('probe', flush: true);
    if (await probeFile.exists()) {
      await probeFile.delete();
      return true; // Directory is directly POSIX-writable!
    }
    return false;
  } catch (e) {
    AppLogger.warning('Directory $directoryPath rejected: $e');
    return false;
  }
}
```

If the test probe fails, the app informs the user with `StorageAccessException` and maintains the app-specific external storage folder.

---

## 3. MediaStore & Share Sheet Fallback

To allow users to export clips to their native Gallery, WhatsApp, or YouTube App:
1. Clips are saved to the persistent storage directory.
2. The user can tap **Share All** or **Share Clip**, triggering `share_plus`:
   ```dart
   Share.shareXFiles([XFile(clip.path)], text: clip.fileName);
   ```
3. The user can tap **Open in Player**, triggering `open_filex`:
   ```dart
   OpenFilex.open(clip.path);
   ```

---

## 4. Common Failure Modes & Diagnostics

1. **`EACCES (Permission denied)` on `File.create()`:**
   - Cause: Directory selected outside app sandbox on Android 11+ without MediaStore insertion.
   - Solution: Call `outputController.resetToDefault()` to return to `getExternalStorageDirectory()`.
2. **Video Picker Returns `content://` URI:**
   - Handled transparently by `image_picker` which copies cached media to app cache before returning a clean local path.
3. **App Killed During Background Slicing:**
   - Cause: Missing `WAKE_LOCK` permission or aggressive OEM battery saver killing FFmpeg native process.
   - Solution: Verified `android.permission.WAKE_LOCK` is active in `AndroidManifest.xml`.

