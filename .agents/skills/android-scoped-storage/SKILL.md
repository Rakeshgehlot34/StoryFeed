---
name: android-scoped-storage
description: Handles Android Scoped Storage compliance (API 28 to 35+), 4-tier ClipWriter strategies, SAF tree URI permissions, write probing, and MediaStore fallbacks.
---

# Android Scoped Storage & ClipWriter Strategies

## Trigger Conditions
Use this skill when:
- Implementing or modifying directory selection or clip writing in `lib/features/output/`.
- Resolving `EACCES (Permission Denied)` or `FileSystemException` on Android 9 through Android 15+.
- Integrating `ClipWriter` strategies across API 28, 29, 30, 33, 34, and 35.

---

## 1. 4-Tier Strategy Implementation Details

### Strategy 1: PRIMARY — Storage Access Framework (API 28+)
- User picks folder via `FilePicker.platform.getDirectoryPath()`.
- Persist tree URI and take read/write grants:
  ```kotlin
  val flags = Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION
  context.contentResolver.takePersistableUriPermission(uri, flags)
  ```
- On launch, validate `isPersistedUriValid(uri)` and prompt user to re-pick if revoked.
- Document creation via `DocumentFile.fromTreeUri(context, uri).createFile("video/mp4", fileName)`.

### Strategy 2: FALLBACK — Direct Public File Writing (API 28 only)
- Destination: `/storage/emulated/0/Movies/ShortsSplitter/`.
- Guarded in manifest: `<uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE" android:maxSdkVersion="28" />`.
- Guarded at runtime: `if (Build.VERSION.SDK_INT == 28)`. Never use direct public writes on API 29+.

### Strategy 3: FALLBACK — MediaStore Video Collection (API 29+)
- Inserts record into `MediaStore.Video.Media.EXTERNAL_CONTENT_URI` with:
  - `RELATIVE_PATH = "Movies/ShortsSplitter"`
  - `IS_PENDING = 1`
- Streams temp file into `openOutputStream(itemUri)`.
- Updates `IS_PENDING = 0` to index in gallery.
- Guarded at runtime: `if (Build.VERSION.SDK_INT >= 29)`. Never use `RELATIVE_PATH` on API 28.

### Strategy 4: FINAL FALLBACK — App-Specific External Storage
- Destination: `getExternalStorageDirectory()/ShortsSplitter/`.
- Accessible across all Android versions without runtime permissions.

---

## 2. Temp-First Write Flow
```dart
// 1. Transcode to app-private temp file
final tempFile = File(tempPath);

// 2. Copy to active strategy destination
final destinationUri = await clipWriter.writeClip(
  sourceTempFile: tempFile,
  fileName: segment.formattedName,
  duplicateHandling: duplicateHandling,
);

// 3. Verify destination and delete private temp file
if (await tempFile.exists()) {
  await tempFile.delete();
}
```

---

## 3. Handling 1GB+ Source Content URIs
Stream using 64KB buffers from ContentResolver to avoid OOM crashes:
```kotlin
val buffer = ByteArray(64 * 1024)
var bytesRead: Int
while (inputStream.read(buffer).also { bytesRead = it } != -1) {
    outputStream.write(buffer, 0, bytesRead)
}
```
