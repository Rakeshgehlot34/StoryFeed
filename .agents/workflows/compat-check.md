# /compat-check Workflow

Numbered execution steps for auditing code changes against Android API compatibility rules (API 28 through API 35+) and printing a structured pass/fail report.

## Execution Steps

1. **Inspect Working Tree & Diff:**
   Capture git status and all unstaged/staged changes:
   ```bash
   git status --short
   git diff HEAD
   ```

2. **Scan for Unguarded API Calls:**
   - Verify any Android-specific API call (e.g. `MediaStore.Video.Media.RELATIVE_PATH`, `IS_PENDING`, `NotificationChannel`, `FOREGROUND_SERVICE_MEDIA_PROCESSING`, `registerReceiver` with flags) is guarded by `Build.VERSION.SDK_INT` or version checks in Dart.
   - Confirm `RELATIVE_PATH` is never invoked on API 28.
   - Confirm direct public storage writes are only attempted on API 28.

3. **Audit Manifest Permissions:**
   - Verify `WRITE_EXTERNAL_STORAGE` has `android:maxSdkVersion="28"`.
   - Verify `READ_EXTERNAL_STORAGE` has `android:maxSdkVersion="32"`.
   - Verify foreground service types and permissions match Android 14 (`dataSync`) and Android 15 (`mediaProcessing`).

4. **Audit Storage & Memory Hygiene:**
   - Verify FFmpeg outputs to private temp files first before copying to destination.
   - Verify temporary files are deleted on success, failure, and cancel.
   - Verify `content://` URIs stream via buffers and never buffer whole 1GB+ files into RAM.

5. **Execute Compatibility Unit Tests:**
   Run the Android compatibility test suite:
   ```bash
   flutter test test/features/output/clip_writer_test.dart
   ```

6. **Generate Pass/Fail Compat Report:**
   Output summary table:
   - **Version Guards (`Build.VERSION.SDK_INT`):** PASS / FAIL
   - **Storage Strategy Selection (API 28-35):** PASS / FAIL
   - **Manifest Permissions (`maxSdkVersion`):** PASS / FAIL
   - **Foreground Service Types (API 34/35):** PASS / FAIL
   - **Temp File & Memory Hygiene:** PASS / FAIL

