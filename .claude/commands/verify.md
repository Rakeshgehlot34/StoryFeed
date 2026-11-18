# /verify

Run the complete ShortsSplitter quality verification suite.

## Steps to Execute:
1. Check Dart code formatting:
   ```bash
   dart format --output=none --set-exit-if-changed .
   ```
2. Run Flutter static analyzer:
   ```bash
   flutter analyze
   ```
3. Run all automated unit and widget tests:
   ```bash
   flutter test
   ```
4. Summarize results:
   - If all steps pass: Confirm code is clean and meets the Definition of Done.
   - If any step fails: Report specific lint violations or failing test cases with actionable remedies.

