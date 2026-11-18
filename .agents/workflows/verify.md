# /verify Workflow

Numbered execution steps for the agent to verify code quality, formatting, static analysis, and automated test suite.

## Execution Steps

1. **Format Check:**
   Execute Dart formatting check across the entire project:
   ```bash
   dart format --output=none --set-exit-if-changed .
   ```
   If unformatted files exist, list them clearly.

2. **Static Analysis Check:**
   Execute Flutter static analyzer in strict mode:
   ```bash
   flutter analyze
   ```
   Inspect results for any warnings, hints, or errors against `analysis_options.yaml`.

3. **Automated Test Suite:**
   Run the full unit and widget test suite:
   ```bash
   flutter test
   ```
   Capture test failures, stack traces, and assertions.

4. **Summarize Outcomes:**
   Provide a concise summary table:
   - Format: Pass / Fail (List offending files)
   - Analyzer: Pass / Fail (List error codes and line numbers)
   - Tests: Pass / Fail (Total passed vs failed)
   If all passed, confirm ready for commit/PR.

