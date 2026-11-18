# /release-check

Executes the release verification procedure using the `release-checklist` skill.

## Execution Workflow:
1. Validate `pubspec.yaml` versioning and build number format.
2. Confirm `.gitignore` protects `key.properties`, `local.properties`, and `*.jks`.
3. Check `android/app/build.gradle.kts` (compileSdk 36, minSdk 24, targetSdk 36).
4. Verify `android/app/proguard-rules.pro` contains rules for FFmpegKit and Play Core.
5. Run clean build test:
   ```bash
   flutter clean && flutter pub get
   flutter build apk --split-per-abi --release
   ```
6. Present the pre-release physical device manual QA checklist.

