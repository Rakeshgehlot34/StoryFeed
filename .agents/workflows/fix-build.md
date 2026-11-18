# /fix-build Workflow

Numbered execution steps for diagnosing and fixing static analysis, compilation, or runtime errors using the `debug-playbook` skill.

## Execution Steps

1. **Reproduce the Error:**
   Run the appropriate reproduction command to capture the exact error message:
   - For analysis issues: `flutter analyze`
   - For build issues: `flutter build apk --debug`
   - For test issues: `flutter test`

2. **Diagnose Root Cause:**
   Invoke `.agents/skills/debug-playbook/SKILL.md`:
   - Identify if the failure is type-safety, ProGuard/R8, platform channel, FFmpeg command syntax, or storage permission.
   - Trace origin file and line number.

3. **Propose Minimal Fix:**
   Formulate the smallest contiguous fix:
   - Do NOT rewrite unrelated architecture or refactor working code.
   - Ensure the fix preserves all domain invariants and strict typing rules.

4. **Apply Fix & Re-Verify:**
   - Apply edits to the affected file(s).
   - Run `/verify` (`./scripts/verify.sh`): check formatting, run `flutter analyze`, and run `flutter test`.
   - Confirm all errors are resolved with zero residual warnings.

