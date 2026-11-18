# Dart & Flutter Style Rules

Apply these imperative conventions across all Dart code in `shorts_splitter`.

## 1. Type Safety & Sound Null-Safety
- **Never use `dynamic`:** Always use explicit types, generics, or `Object?` with type patterns / is-checks.
- **Avoid the Bang Operator (`!`):** Never force-unwrap optionals with `!` unless an invariant guarantees non-nullness, and document it with an immediate inline comment:
  ```dart
  // Safe: guarded by preceding check or constructor invariant
  final lastSegment = segments.last; // Invariant: segments is verified non-empty above
  ```
- **Type Annotations:** Always specify return types on functions, getters, and methods (`always_declare_return_types`).
- **Strict Casts:** Avoid implicit casts and raw types. Enable and obey `strict-casts`, `strict-inference`, and `strict-raw-types`.

## 2. Widget Structure & Decomposition
- **Line Limits:**
  - Dart files must not exceed 300 lines of code.
  - Widget `build()` methods must not exceed 100 lines.
- **Decompose Early:** Extract large UI trees into focused, standalone private widgets (`class _ClipSummaryCard extends StatelessWidget`) rather than bloated helper methods that defeat widget subtree rebuilding optimizations.
- **No Heavy Logic in `build()`:** Never compute video split ranges, file operations, or regex operations inside `build()`. Defer all state and heavy calculations to Riverpod `Notifier` or domain models.

## 3. Const Discipline & Memory Performance
- **Use `const` Everywhere Possible:**
  - Prefix widget instantiation with `const` (`prefer_const_constructors`).
  - Declare compile-time literals and constants as `const` (`prefer_const_declarations`, `prefer_const_literals_to_create_immutables`).
  - Declare immutable widget constructors with `const MyWidget({super.key})`.
- **Final Variables:** Declare local variables as `final` (`prefer_final_locals`). Declare private class fields as `final` (`prefer_final_fields`).

## 4. Trailing Commas & Formatting
- **Mandatory Trailing Commas:** Add a trailing comma `,` after the last argument or parameter of any multiline parameter list, argument list, or collection literal. This instructs `dart format` to break expressions onto readable lines.
- **Automated Check:** Run `dart format --output=none --set-exit-if-changed .` before committing.

## 5. UI Hygiene (No Hardcoded Values)
- **Strings:** Store shared user-facing labels, titles, and button labels in `AppConstants` (`lib/app/constants.dart`).
- **Colors:** Never instantiate `Color(0xFF...)` directly inside widget trees. Reference semantic colors through `Theme.of(context).colorScheme` or `AppTheme.youtubeRed`.
- **Durations & Spacings:** Use `AppConstants.defaultClipDurationSeconds`, `AppConstants.maxClipDurationSeconds`, and standard padding constants (`8.0`, `12.0`, `16.0`, `24.0`).

