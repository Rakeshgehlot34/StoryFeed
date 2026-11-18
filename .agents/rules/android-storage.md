# Android Scoped Storage & File System Rules

Governs directory access, file creation, and permission handling across Android versions (API 28 through 35+).

## 1. 4-Tier Storage Strategy by Android Version

```
┌────────────────────────────────────────────────────────┐
│ PRIMARY (API 28+): SAF Tree URI                        │
│ - User picks folder via getDirectoryPath() / SAF       │
│ - Persist URI via takePersistableUriPermission         │
│ - Validate permission & folder existence on launch     │
└───────────────────────────┬────────────────────────────┘
                            │ (fallback if no SAF / revoked)
                            ▼
      ┌─────────────────────┴─────────────────────┐
      ▼ (API == 28)                               ▼ (API >= 29)
┌──────────────────────────────┐    ┌──────────────────────────────────┐
│ FALLBACK: Direct Public Path │    │ FALLBACK: MediaStore Collection  │
│ - Movies/ShortsSplitter      │    │ - RELATIVE_PATH = Movies/...     │
│ - WRITE_EXTERNAL_STORAGE     │    │ - IS_PENDING handling            │
│   (maxSdkVersion="28")       │    │ - Never use RELATIVE_PATH on 28  │
└──────────────┬───────────────┘    └──────────────────┬───────────────┘
               │                                       │
               └───────────────────┬───────────────────┘
                                   │ (final fallback)
                                   ▼
┌────────────────────────────────────────────────────────┐
│ FINAL FALLBACK: App-Specific Storage                   │
│ - /Android/data/com.shortssplitter.shorts_splitter/... │
│ - Zero runtime permissions required                    │
└────────────────────────────────────────────────────────┘
```

## 2. Temp-First Write Discipline
FFmpeg must NEVER write directly into shared public folders or content URIs.
1. Transcode each clip into an app-private temp file (`<cacheDir>/temp_clip_NNN.mp4`).
2. Verify temp file exists and has size $> 0$.
3. Copy into target destination via the active `ClipWriter` strategy.
4. Verify destination copy and immediately delete the temp file.
5. On cancellation or error, clean up all tracked temp files.

## 3. Duplicate Filename Handling
- Settings allow `overwrite` or `autoSuffix`.
- `autoSuffix` must append sequential suffixes (e.g., `video_part_001_1.mp4`, `video_part_001_2.mp4`) without altering the canonical part sequence index.

## 4. Reading 1GB+ Source Videos (Content URIs)
- When source video is a `content://` URI: stream to a private temp file in 64KB chunks via `StorageBridge.copyContentUriToTempFile`.
- Never load the entire video into RAM (`Uint8List`).
- Perform pre-flight storage check ($\ge 250\text{MB}$ free space) before initiating export.
