# /sanity Workflow

Executable multi-step workflow verifying complete repository health, static analysis, unit/widget tests, deterministic media fixtures, output verifiers, and documentation integrity.

## Execution Steps

1. **Environment & Dependency Resolution:**
   Verify Flutter, Dart SDK, and resolve package dependencies:
   ```bash
   flutter --version
   flutter pub get
   ```

2. **Code Formatting Validation:**
   Check compliance with standard Dart formatting rules:
   ```bash
   dart format --output=none --set-exit-if-changed .
   ```
   If formatting errors occur, auto-format via `dart format .` and report changed files.

3. **Strict Static Analysis:**
   Run the static analyzer with zero permitted warnings or infos:
   ```bash
   flutter analyze --fatal-infos --fatal-warnings
   ```

4. **Automated Test Suite:**
   Run all automated tests across domain, presentation, data layers, and output verification:
   ```bash
   flutter test
   ```

5. **Documentation Integrity & Link Checking:**
   Verify all documentation files exist, contain no placeholders or broken relative links, and synchronize with code:
   ```bash
   ./scripts/docs_check.sh
   ```

6. **End-to-End Sanity Script:**
   Execute the unified sanity runner script:
   ```bash
   # Linux / macOS
   ./scripts/sanity.sh

   # Windows PowerShell
   .\scripts\sanity.ps1
   ```

7. **Report Summary:**
   Output a structured status table:
   - Formatting: Pass / Fail
   - Analyzer: Pass / Fail
   - Test Suite: Pass / Fail (count passed vs failed)
   - Docs Check: Pass / Fail

