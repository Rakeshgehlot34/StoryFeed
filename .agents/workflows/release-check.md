# /release-check Workflow

Numbered execution steps for executing a production release check using the `release-checklist` skill and outputting a structured pass/fail report.

## Execution Steps

1. **Verify Working Tree & Git Hygiene:**
   - Confirm branch is clean with no uncommitted changes (`git status`).
   - Confirm no untracked secrets or keystores are present (`git status --ignored`).

2. **Verify Version & Changelog:**
   - Check `pubspec.yaml` has an updated version string (`version: X.Y.Z+build`).
   - Check `CHANGELOG.md` has an entry for the target version.

3. **Execute Pre-Commit Verification:**
   Run `./scripts/verify.sh` to ensure:
   - Code formatting is clean.
   - Strict static analyzer produces 0 warnings and 0 errors.
   - All unit and widget tests pass.

4. **Verify Release Build:**
   Build an architecture-split release APK:
   ```bash
   flutter build apk --release --split-per-abi
   ```
   Confirm output APKs exist under `build/app/outputs/flutter-apk/`.

5. **Generate Release Pass/Fail Report:**
   Output a markdown summary table:
   - **Git Hygiene & Secrets:** PASS / FAIL
   - **Version & Changelog:** PASS / FAIL
   - **Code Quality (`./scripts/verify.sh`):** PASS / FAIL
   - **Release Binary Build:** PASS / FAIL
   - **Real-Device QA Items:** Pending Manual Verification (Large Video, Low Storage, Cancel, Backgrounding)

