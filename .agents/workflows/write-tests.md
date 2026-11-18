# /write-tests Workflow

Numbered execution steps for authoring robust unit, widget, or controller tests using the `flutter-testing` skill.

## Execution Steps

1. **Identify Target & Test Scope:**
   Prompt the user (or inspect the current task) for:
   - Target file or feature under test (e.g. `split_config`, `clip_segment.dart`, `HomeScreen`).
   - Specific edge cases or scenarios to cover.

2. **Invoke Flutter Testing Skill:**
   Review `.agents/skills/flutter-testing/SKILL.md` for doubles, fakes, and mocking patterns:
   - Use `FakeVideoProcessor` for media execution.
   - Use `SharedPreferences.setMockInitialValues` for storage mocking.
   - Use `ProviderContainer` for Riverpod controller tests.

3. **Author Test Cases:**
   Create or expand tests under `test/`:
   - Cover happy paths, boundary edges, and failure branches (`AppException`).
   - For split planning: test durations shorter than target, exact multiples, and trailing remainder merge flags.

4. **Execute & Validate:**
   Run the newly authored test:
   ```bash
   flutter test test/<path_to_test_file>.dart
   ```
   Ensure tests pass deterministically without flakes.

5. **Run Full Verification:**
   Run `./scripts/verify.sh` to confirm overall project suite remains 100% green.

