---
name: debug-playbook
description: Diagnostic procedures for debugging FFmpeg execution failures, Android 10-15 Scoped Storage issues, and media codec errors.
---

# ShortsSplitter Debug Playbook

## Trigger Conditions
Use this skill when:
- FFmpeg session fails with non-zero return codes (`ReturnCode.isSuccess() == false`).
- Video splitting hangs or aborts unexpectedly.
- Storage writes fail with permission or I/O exceptions on Android 10+.

---

## 1. Diagnosing FFmpeg Failures

### Extracting Full Session Logs
When FFmpeg fails, inspect the complete command output and session logs:
```dart
final returnCode = await session.getReturnCode();
if (!ReturnCode.isSuccess(returnCode)) {
  final logs = await session.getAllLogsAsString();
  final failStackTrace = await session.getFailStackTrace();
  AppLogger.error('FFmpeg execution failed (Code: $returnCode):\n$logs\nStack: $failStackTrace');
}
```

### Common FFmpeg Failure Signatures & Solutions

| Error Signature in Logs | Root Cause | Solution |
| :--- | :--- | :--- |
| `Invalid data found when processing input` | Corrupted source video or unsupported codec container | Run `probeVideo()` first. Confirm format via `ffprobe` / `MediaInformationSession`. |
| `Cannot allocate memory` / Signal 9 (SIGKILL) | System OOM killer terminated process due to heavy filter chain or 4K software encoding | Switch preset to `ultrafast` or use stream-copy mode (`-c copy`). |
| `Filter graph cannot find suitable format` | Video filter chain mismatch (e.g. RGB vs YUV) | Append `-pix_fmt yuv420p` to the output parameters. |
| `Could not write header for output file` | Read-only directory or invalid characters in output path | Verify path writeability using `.probe_` file check. |
| `Non-monotonous DTS in output stream` | Stream copy timestamp misalignment | Add `-avoid_negative_ts make_zero` to command. |

---

## 2. Diagnosing Android 10–15 Scoped Storage & Permission Errors

### Common Storage Errors & Solutions

| Symptom | Cause | Solution |
| :--- | :--- | :--- |
| `errno = 13 (Permission Denied)` on Android 11+ | Direct file write attempted in non-app directory without SAF tree grant | Switch to app-specific external directory (`getExternalStorageDirectory()`) or use SAF directory picker. |
| Permission dialog does not appear on Android 13+ | Asking for `READ_EXTERNAL_STORAGE` on API 33+ | Request `Permission.videos` (`READ_MEDIA_VIDEO`) instead of `Permission.storage`. |
| Directory disappears after device reboot | Transient content URI not persisted | Call `takePersistableUriPermission` on native SAF intent if using direct platform channel. |

---

## 3. Systematic 4-Step Triage Routine
When diagnosing any user-reported issue:
1. **Reproduce:** Reproduce with minimal sample video and inspect terminal logs (`flutter run -v`).
2. **Inspect Return Codes:** Verify whether failure occurred during probe, permission check, file creation, or FFmpeg encoding.
3. **Isolate Component:** Replace `FFmpegVideoProcessor` with `FakeVideoProcessor` to determine if issue is in UI/Riverpod controller or native transcode.
4. **Verify Fix:** Execute `./scripts/verify.sh` to ensure no regression.

