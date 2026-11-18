# /ui-check Workflow

Automated procedure for validating that Flutter screens and widgets strictly adhere to the ShortsSplitter Design System tokens, 14 reusable widgets, and accessibility guidelines.

## Execution Steps

1. **Format & Analysis Verification:**
   Ensure formatting and static analysis are completely green:
   ```bash
   dart format --output=none --set-exit-if-changed .
   flutter analyze
   ```

2. **Design Tokens Compliance Check:**
   Search for raw numeric padding, margins, or radii in presentation files:
   ```bash
   grep -rn "EdgeInsets.all([0-9]" lib/features/
   grep -rn "BorderRadius.circular([0-9]" lib/features/
   ```
   *Expectation:* Zero occurrences. All values should use `AppTokens.space*` or `AppTokens.borderRadius*`.

3. **Shared Widgets Verification:**
   Verify that custom buttons, cards, skeletons, and dialogs are not reintroduced in feature folders:
   - Use `PrimaryButton` and `SecondaryButton` instead of raw `FilledButton` / `OutlinedButton`.
   - Use `LoadingSkeleton` instead of ad-hoc animated shimmers.
   - Use `ConfirmDialog` instead of raw `showDialog<AlertDialog>`.
   - Use `EmptyState` and `ErrorState` across all `AsyncValue.when(...)` blocks.

4. **Widget Test Suite Execution:**
   Run all UI widget tests verifying loading, empty, and populated states:
   ```bash
   flutter test test/features/home/
   flutter test test/features/history/
   flutter test test/features/settings/
   flutter test test/features/plan_review/
   ```

5. **Touch Target & Accessibility Verification:**
   Ensure all icon buttons and interactive controls meet minimum 48x48dp touch bounds.
   Verify text scaling up to 200% does not produce render overflow errors.

