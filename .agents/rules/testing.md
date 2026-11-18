# Testing Guidelines & Quality Gates

Enforce these testing standards across all features and refactors in `shorts_splitter`.

## 1. Mandatory Test Coverage Matrix
Every feature must supply corresponding tests under `test/`:
- **Domain Segment Calculation:**
  Any change to `ClipSegment.calculateSegments()` or `SplitConfig` must pass the test matrix:
  1. Duration perfectly divisible by clip length (e.g. 180s video / 60s clips $\rightarrow$ exactly 3 clips).
  2. Duration shorter than clip length (e.g. 45s video / 60s clips $\rightarrow$ exactly 1 clip of 45s).
  3. Remainder $< 3.0$ seconds with `mergeShortTrailingClip = true` (e.g. 122s video / 60s clips $\rightarrow$ 2 clips: 60s and 62s).
  4. Remainder $< 3.0$ seconds with `mergeShortTrailingClip = false` (e.g. 122s video / 60s clips $\rightarrow$ 3 clips: 60s, 60s, 2s).
  5. Boundary contiguity verification: verify $S_{i}.\text{end} == S_{i+1}.\text{start}$ across all segments.
  6. Zero-padded naming verification across 1-digit, 2-digit, and 3-digit clip counts.
- **Error Mapping:** Ensure all `AppException` subclasses produce non-empty, actionable user messages.
- **Smoke & Widget Tests:** Ensure the widget tree pumps without overflow errors and navigation transitions work.

## 2. Test Doubles & Mocks
- **No Native Media Calls in Tests:** Never invoke native FFmpeg (`ffmpeg_kit_flutter_new`) inside unit or widget tests. Inject `FakeVideoProcessor` (`lib/features/processing/domain/video_processor.dart`).
- **Storage & Preferences:** Use `SharedPreferences.setMockInitialValues({...})` to isolate tests from real filesystem persistence.
- **File Picker:** Wrap or mock file picker responses with static fixture paths.

## 3. Test Structure & Naming
- Use descriptive test blocks:
  ```dart
  group('ClipSegment calculation tests', () {
    test('Calculates exact segments with contiguous timestamps and zero-padded names', () { ... });
    test('Merges trailing remainder under 3 seconds into previous clip when enabled', () { ... });
  });
  ```

## 4. Pre-Merge Verification Gate
No code may be merged without running:
```bash
./scripts/verify.sh
```
This runs `dart format`, `flutter analyze` (in strict mode), and `flutter test`. All three checks must pass with zero errors and zero warnings.

