# ShortsSplitter Storage & Permissions Architecture

Complete technical reference for ShortsSplitter's 4-tier Android Scoped Storage architecture (API 28 through API 35+), runtime permission handling, and temporary file lifecycles.

---

## Table of Contents
1. [4-Tier Storage Strategy Matrix](#1-4-tier-storage-strategy-matrix)
2. [Runtime Permission Matrix](#2-runtime-permission-matrix)
3. [AndroidManifest.xml Configuration](#3-androidmanifestxml-configuration)
4. [SAF Tree URI Persistence & Lifecycle](#4-saf-tree-uri-persistence--lifecycle)
5. [Temporary File Lifecycle & Memory Safety](#5-temporary-file-lifecycle--memory-safety)
6. [Failure Modes & Recovery Procedures](#6-failure-modes--recovery-procedures)

---

## 1. 4-Tier Storage Strategy Matrix

To ensure compliance from Android 9 (API 28) through Android 15 (API 35+), ShortsSplitter uses a 4-tier runtime storage strategy resolved dynamically by `ClipWriterFactory`:

| Tier | Strategy | Target OS | Storage Mechanism | Permission Required |
| :--- | :--- | :--- | :--- | :--- |
| **Tier 1 (PRIMARY)** | `SafClipWriter` | **API 28+** (Universal) | User-selected folder via `ACTION_OPEN_DOCUMENT_TREE`. | Persisted Tree URI via `takePersistableUriPermission`. |
| **Tier 2 (FALLBACK)** | `DirectFileClipWriter` | **API 28 only** (Android 9) | Direct file I/O to public `/storage/emulated/0/Movies/ShortsSplitter`. | `WRITE_EXTERNAL_STORAGE` (`maxSdkVersion="28"`). |
| **Tier 3 (FALLBACK)** | `MediaStoreClipWriter` | **API 29–35+** (Android 10+) | `MediaStore.Video.Media` collection with `RELATIVE_PATH = "Movies/ShortsSplitter"`. | Zero broad storage permissions needed. Uses `IS_PENDING`. |
| **Tier 4 (SAFETY)** | `AppExternalClipWriter` | **All APIs** (Emergency) | App-specific external storage (`/Android/data/.../files/ShortsSplitter/`). | Zero permissions needed on any Android version. |

---

## 2. Runtime Permission Matrix

Permissions requested dynamically based on device `Build.VERSION.SDK_INT`:

| Permission | Android 9 (API 28) | Android 10–12 (API 29–32) | Android 13+ (API 33+) | Purpose |
| :--- | :--- | :--- | :--- | :--- |
| `READ_MEDIA_VIDEO` | ❌ Not applicable | ❌ Not applicable | ✅ Runtime requested | Allows picking source videos via system picker. |
| `READ_MEDIA_IMAGES` | ❌ Not applicable | ❌ Not applicable | ✅ Runtime requested | Allows picking custom background overlay images. |
| `READ_EXTERNAL_STORAGE` | ✅ Runtime requested | ✅ Runtime requested | ❌ Replaced by `READ_MEDIA_*` | Legacy media picking on Android 9–12. |
| `WRITE_EXTERNAL_STORAGE` | ✅ Runtime requested | ❌ Ignored by OS | ❌ Prohibited | Direct file writes to public Movies directory on API 28. |
| `POST_NOTIFICATIONS` | ❌ Auto-granted | ❌ Auto-granted | ✅ Runtime requested | Foreground service progress bar in notification tray. |
| `FOREGROUND_SERVICE` | ❌ Normal permission | ✅ Manifest only | ✅ Manifest only | Keeps export service alive during app backgrounding. |
| `WAKE_LOCK` | ✅ Normal permission | ✅ Normal permission | ✅ Normal permission | Prevents CPU sleep while FFmpeg encodes video. |

---

## 3. AndroidManifest.xml Configuration

```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android">

    <!-- Android 13+ (API 33+) Scoped Media Permissions -->
    <uses-permission android:name="android.permission.READ_MEDIA_VIDEO" />
    <uses-permission android:name="android.permission.READ_MEDIA_IMAGES" />

    <!-- Android 12 and below (API <= 32) Legacy Storage Permissions -->
    <uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" android:maxSdkVersion="32" />
    <uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE" android:maxSdkVersion="28" />

    <!-- Foreground Service permissions for background export survival -->
    <uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
    <!-- Android 15 (API 35+) dedicated media transcoding type -->
    <uses-permission android:name="android.permission.FOREGROUND_SERVICE_MEDIA_PROCESSING" />
    <!-- Android 14 (API 34) fallback data sync type -->
    <uses-permission android:name="android.permission.FOREGROUND_SERVICE_DATA_SYNC" />

    <!-- CPU awake lock during transcode jobs -->
    <uses-permission android:name="android.permission.WAKE_LOCK" />

    <!-- Notification progress updates (Android 13+) -->
    <uses-permission android:name="android.permission.POST_NOTIFICATIONS" />

    <application
        android:label="ShortsSplitter"
        android:requestLegacyExternalStorage="true">

        <!-- Foreground Service declaration with combined types for API 34 & 35 -->
        <service
            android:name=".ExportForegroundService"
            android:foregroundServiceType="mediaProcessing|dataSync"
            android:exported="false" />
    </application>
</manifest>
```

---

## 4. SAF Tree URI Persistence & Lifecycle

When a user picks an output folder through the system document picker:

1. **Permission Grant:** Native Android `StorageBridge` calls:
   ```kotlin
   contentResolver.takePersistableUriPermission(
       treeUri,
       Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION
   )
   ```
2. **Persistence:** The tree URI string (`content://com.android.externalstorage.documents/tree/...`) is saved in `SharedPreferences`.
3. **App Launch Validation:** On every app boot, `OutputRepository.getSavedOutputDirectoryPath()` verifies:
   - Persisted URI is still granted in `contentResolver.persistedUriPermissions`.
   - The directory still exists via `DocumentFile.fromTreeUri(context, uri).exists()`.
   - If the folder was deleted or permission revoked, the app falls back to Tier 4 without crashing.
4. **Reboot Survival:** Persisted URI grants survive device reboots automatically.

---

## 5. Temporary File Lifecycle & Memory Safety

FFmpeg Kit cannot write directly to Android `content://` tree URIs because C-level `fopen()` requires standard POSIX paths. ShortsSplitter solves this with a **2-stage staging pipeline**:

```
[FFmpeg Engine]
       │ writes directly
       ▼
[App-Private Temp File: cache/split_temp_001.mp4]
       │
       │ verify byte size > 0
       ▼
[ClipWriter: SafClipWriter / MediaStoreClipWriter]
       │ streams via 64KB buffer into contentResolver.openOutputStream()
       ▼
[Final Storage Destination: DocumentFile / MediaStore]
       │
       │ deletion on success, failure, or cancellation
       ▼
[Delete App-Private Temp File]
```

### Invariants
- **Zero RAM Bloat:** Files are never buffered into `Uint8List`. Streaming operates strictly in 64KB chunks.
- **Hermetic Cleanup:** The temporary file is deleted in a `finally` block on transcode success, failure, or user cancellation.

---

## 6. Failure Modes & Recovery Procedures

### 1. SAF Permission Revoked by User in OS Settings
- **Symptom:** Subsequent split attempts throw `SecurityException: Permission Denial`.
- **Handling:** `StorageBridge` catches exception, marks persisted URI invalid, and automatically routes writes to Tier 4 (`/Android/data/.../files/ShortsSplitter/`). The user is prompted to re-pick an output directory in Settings.

### 2. Destination Folder Deleted from Files App
- **Symptom:** `DocumentFile.createFile()` returns null.
- **Handling:** `SafClipWriter` detects null handle, re-probes folder existence, and falls back to Tier 3 MediaStore or Tier 4 App-External.

### 3. Device Storage Exhausted Mid-Export
- **Symptom:** `IOException: No space left on device` during transcode.
- **Handling:** `ProcessingController` halts export, removes partial `.mp4` file, stops foreground service, and presents a clear `ErrorState` dialog indicating free space required.

