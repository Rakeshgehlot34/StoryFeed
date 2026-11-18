# /new-feature Workflow

Numbered execution steps for generating a production-ready feature using the `flutter-feature-scaffold` skill.

## Execution Steps

1. **Prompt for Requirements:**
   Ask the user for:
   - Feature name (e.g. `watermark`, `audio_extractor`, `presets`).
   - Intended business responsibility and UI screens.
   - Any external domain interactions.

2. **Invoke Feature Scaffold Skill:**
   Refer to `.agents/skills/flutter-feature-scaffold/SKILL.md` to establish:
   - `lib/features/<name>/domain/` (entities, interfaces).
   - `lib/features/<name>/data/` (repository implementation).
   - `lib/features/<name>/presentation/` (screen, widgets, Riverpod controller).

3. **Register Routing & Theme Constants:**
   - Add route constant to `lib/app/constants.dart`.
   - Register route builder in `lib/app/router.dart`.
   - Add necessary labels/strings to constants.

4. **Generate Unit & Widget Tests:**
   Create initial test suite under `test/features/<name>/<name>_test.dart` validating domain logic and controller state.

5. **Execute Verification:**
   Run `/verify` (or `./scripts/verify.sh`) to confirm zero analyzer warnings and 100% passing tests.

