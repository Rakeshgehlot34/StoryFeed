# /new-feature <name>

Scaffolds a new feature module following ShortsSplitter's feature-first architecture.

## Execution Workflow:
1. Parse the `<name>` argument (convert to snake_case for directories/files, PascalCase for classes).
2. Follow the `flutter-feature-scaffold` skill to generate:
   - `lib/features/<name>/domain/models/<name>_model.dart`
   - `lib/features/<name>/data/<name>_repository.dart`
   - `lib/features/<name>/presentation/controllers/<name>_controller.dart`
   - `lib/features/<name>/presentation/screens/<name>_screen.dart`
3. Register the new route in `lib/app/constants.dart` (`AppRoutes`) and `lib/app/router.dart`.
4. Generate a unit test file in `test/features/<name>/<name>_test.dart`.
5. Run `flutter analyze` and `flutter test` to ensure zero compilation or lint errors.

