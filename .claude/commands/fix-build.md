# /fix-build

Delegates to the `flutter-debugger` subagent to automatically diagnose and fix build or analysis errors.

## Execution Workflow:
1. Capture the latest failure log from `flutter analyze` or `flutter build apk`.
2. Activate `flutter-debugger` to parse compiler diagnostics, missing R8 rules, or Android Gradle issues.
3. Apply surgical, minimal fixes.
4. Verify resolution with `flutter analyze && flutter test`.

