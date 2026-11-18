/// Storage strategy selected at runtime based on Android SDK level and user configuration.
enum StorageStrategyType {
  /// Primary strategy across all Android versions (API 28+):
  /// Uses Storage Access Framework (SAF) tree URIs with persistent read/write permissions.
  saf,

  /// Fallback strategy exclusively for Android 9 (API 28):
  /// Writes directly to public Movies/ShortsSplitter with WRITE_EXTERNAL_STORAGE permission.
  directPublic,

  /// Fallback strategy for Android 10+ (API 29+):
  /// Saves directly to MediaStore Video collection using RELATIVE_PATH and IS_PENDING.
  mediaStore,

  /// Final safe fallback across all versions:
  /// Uses app-specific external files directory without requiring any runtime permissions.
  appSpecific,
}

/// Setting governing how duplicate clip file names in the target directory are handled.
enum DuplicateHandling {
  /// Overwrites any existing file with the same name.
  overwrite,

  /// Appends an index suffix (e.g., video_part_001_1.mp4) while preserving strict sequence numbering.
  autoSuffix,
}
