# /docs-sync Workflow

Automated procedure for verifying that repository documentation remains completely synchronized with application code, routes, domain invariants, storage strategies, scripts, and Antigravity agent configuration.

## Execution Steps

1. **Code & Route Drift Audit:**
   Compare the current codebase state against `/docs`:
   - Inspect `lib/app/constants.dart` for new or modified route definitions in `AppRoutes`.
   - Inspect `lib/app/theme/` and `lib/shared/widgets/` for design tokens and component inventory.
   - Inspect `android/app/build.gradle.kts` and `AndroidManifest.xml` for SDK versions, permissions, and foreground services.
   - Inspect `pubspec.yaml` for dependency version bumps.
   - Inspect `scripts/` and `.agents/workflows/` to ensure all automation files are indexed.

2. **Synchronize Changed Documentation:**
   Update affected files under `/docs`, `README.md`, or `CHANGELOG.md` with zero placeholders:
   - Route changes -> Update `docs/ARCHITECTURE.md`, `docs/UI_GUIDE.md`, and `docs/COMMANDS.md`.
   - Storage or permission changes -> Update `docs/STORAGE_AND_PERMISSIONS.md` and `docs/ANDROID_COMPAT.md`.
   - Script or tool additions -> Update `docs/COMMANDS.md` and `docs/BUILD_AND_RELEASE.md`.
   - Feature changes -> Update `docs/FEATURES.md`, `CHANGELOG.md`, and `README.md`.

3. **Run Documentation Integrity Verifier:**
   Execute the automated verification script:
   ```bash
   ./scripts/docs_check.sh
   ```
   *Windows (PowerShell):*
   ```powershell
   .\scripts\docs_check.ps1
   ```
   Ensure 100% of required files exist, relative links resolve, no placeholder tokens remain, and all scripts/workflows are indexed.

4. **Verify Quality Gate Integration:**
   Confirm that pre-commit quality check passes:
   ```bash
   ./scripts/verify.sh
   ```

5. **Print Synchronization Summary:**
   Output a list of modified documentation files, verified cross-references, and any remaining manual verification tasks.

