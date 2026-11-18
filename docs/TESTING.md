# ShortsSplitter Testing Strategy & QA Plan

Testing methodology, automated test suites, test doubles, coverage targets, and physical device QA matrices for ShortsSplitter.

---

## Table of Contents
1. [Testing Pyramid](#1-testing-pyramid)
2. [Automated Test Execution](#2-automated-test-execution)
3. [Test Doubles: Fakes & Mocks](#3-test-doubles-fakes--mocks)
4. [Critical Test Coverage Matrix](#4-critical-test-coverage-matrix)
5. [Widget Test Conventions & State Coverage](#5-widget-test-conventions--state-coverage)
6. [Real-Device Physical QA Matrix](#6-real-device-physical-qa-matrix)

---

## 1. Testing Pyramid

ShortsSplitter enforces a multi-tiered testing strategy:

```
          ▲
         / \        Manual Real-Device QA (Large 4K files, backgrounding, reboot)
        /   \       
       /-----\      Widget Tests (Dashboard, PlanReview, History, Settings)
      /       \     
     /---------\    Unit Tests (PlanCalculator, FilterGraphBuilder, ClipWriters)
```

- **Unit Tests:** Verify pure mathematical functions, domain invariants, and filter string generators headlessly in milliseconds.
- **Widget Tests:** Verify UI state transitions (`loading`, `empty`, `error`, `content`), user interactions, and Riverpod provider state mutations.
- **Physical Device QA:** Verify Android OS storage interactions, SAF persistable URI permissions, foreground services, and native FFmpeg decoding.

---

## 2. Automated Test Execution

```bash
# Run all automated unit and widget tests
flutter test

# Run a specific test suite
flutter test test/features/split_config/plan_calculator_test.dart

# Run tests and output LCOV code coverage
flutter test --coverage
```

### Coverage Target
- **Domain Layer (`PlanCalculator`, `PlanValidator`):** **100%** line coverage.
- **Data Layer (`FilterGraphBuilder`, `ClipWriterFactory`):** **> 90%** coverage.
- **Presentation Layer (Controllers & Shared Widgets):** **> 80%** coverage.

---

## 3. Test Doubles: Fakes & Mocks

To run automated tests headlessly without invoking C/C++ native FFmpeg binaries or Android JNI calls:

### 1. `FakeVideoProcessor` (`test/fakes/fake_video_processor.dart`)
Simulates video inspection and slicing without spawning FFmpeg:
```dart
final container = ProviderContainer(
  overrides: [
    videoProcessorProvider.overrideWithValue(FakeVideoProcessor()),
  ],
);
```

### 2. `FakeClipWriter` (`test/fakes/fake_clip_writer.dart`)
Simulates disk operations and duplicate naming without touching native filesystems:
```dart
final writer = FakeClipWriter(strategyType: StorageStrategyType.saf);
```

### 3. SharedPreferences Mocking
Every test suite initializes mock preferences in `setUp()`:
```dart
setUp(() {
  SharedPreferences.setMockInitialValues({
    AppConstants.prefKeyOnboardingCompleted: true,
  });
});
```

---

## 4. Critical Test Coverage Matrix

Automated test files in `test/`:

| Test Suite | File Location | Key Verifications |
| :--- | :--- | :--- |
| **PlanCalculator & Validator** | `test/features/split_config/plan_calculator_test.dart` | Contiguous boundaries, 180s hard cap, remainder merge threshold, part split. |
| **OverlaySpec Hierarchy** | `test/features/split_config/overlay_spec_test.dart` | 4-tier precedence resolution, token replacement (`{n}`, `{total}`). |
| **FilterGraphBuilder** | `test/features/processing/filter_graph_builder_test.dart` | 9:16 crop filter, blur filter syntax, color padding, overlay coordinates. |
| **ClipWriter Strategies** | `test/features/output/clip_writer_test.dart` | Strategy resolution across API 28–35+, duplicate handling auto-suffix. |
| **Plan Review Screen** | `test/features/plan_review/plan_review_screen_test.dart` | Plan header summary, parts list rendering, boundary edit dialog. |
| **Dashboard Screen** | `test/features/home/dashboard_screen_test.dart` | Empty state placeholder, populated activity stats, recent project cards. |
| **History Screen** | `test/features/history/history_screen_test.dart` | Project list, swipe/button delete with undo SnackBar restoration. |
| **Settings Screen** | `test/features/settings/settings_screen_test.dart` | ThemeMode switching, accent color selection, duplicate mode persistence. |

---

## 5. Widget Test Conventions & State Coverage

- **Pumping Frames:** Avoid calling `pumpAndSettle()` if repeating pulsing animations (`LoadingSkeleton`) are visible. Use explicit durations:
  ```dart
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
  ```
- **State Validation:** Always write tests covering both empty state (`No projects yet`) and populated state.

---

## 6. Real-Device Physical QA Matrix

Execute this 8-point manual QA checklist on real Android hardware prior to any production release:

1. **Large Video Stress Test ($\ge 1\text{GB}$):**
   - Import a 4K 60fps video exceeding 1GB.
   - Verify RAM consumption remains flat under 80MB.
2. **Low Storage Mid-Flight Simulation:**
   - Run export on a device with $< 200\text{MB}$ storage remaining.
   - Verify graceful failure alert and complete temporary file deletion.
3. **Mid-Flight Cancellation:**
   - Tap "Cancel Export" while processing clip 2 of 5.
   - Verify FFmpeg halts immediately, partial file is deleted, and state resets.
4. **App Backgrounding Survival:**
   - Start 10-clip export. Minimize app or lock screen for 3 minutes.
   - Verify foreground notification shows active progress bar and export finishes.
5. **Permission Revocation in System Settings:**
   - Revoke storage or media permissions in Android Settings.
   - Relaunch app; verify prompt to restore permissions without crashing.
6. **Folder Deleted from Files App:**
   - Delete chosen output folder using the Files app.
   - Relaunch app; verify automatic fallback to app-specific external storage.
7. **Device Reboot Persistence:**
   - Pick custom SAF folder, export 1 clip, reboot phone (`adb reboot`).
   - Reopen app; verify SAF folder remains active and writable.
8. **Varied Video Sources:**
   - Test 16:9 landscape video (blurred background transform).
   - Test 9:16 vertical video (keep original format).
   - Test video with 90° / 270° rotation metadata.
   - Test silent video without audio track (verify AAC silent audio stream created).
9. **Background Export Survival & Screen Lock:**
   - Tap "Create Shorts". Leave export screen by tapping back or pressing Home. Lock the screen. Wait 3 minutes.
   - Unlock phone; observe notification tray progress. Reopen app; verify `AppScaffold` mini-progress banner and Dashboard live card tracking active export.
10. **Interrupted Export Recovery ("Resume / Discard"):**
   - Start 5-clip export. Force-kill app via Android Recents or `adb shell am force-stop com.shortssplitter.shorts_splitter` while processing clip 3.
   - Reopen app; verify "Interrupted Export Detected" card displays on Dashboard showing clip 2/5 completed.
   - Tap "Resume Export"; verify encoding resumes directly from clip 3 with previously completed clips preserved.
11. **Audio Leakage Prevention:**
   - On `TrimScreen`, play video.
   - Navigate away or tap Home button.
   - Verify video playback immediately pauses and zero audio leaks into background.
12. **Custom Prefix Continuity:**
   - Set custom prefix "MyVlog" on `SplitConfigScreen`.
   - On `PlanReviewScreen`, verify clips are named `MyVlog_part_001.mp4`.
   - Tap edit icon on `PlanReviewScreen` and update to "Vacation2026".
   - Verify all clip names in the list dynamically update immediately to `Vacation2026_part_001.mp4`.
