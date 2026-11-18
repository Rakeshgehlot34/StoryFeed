---
name: release-checklist
description: Production release procedure covering versioning, secure signing without committed secrets, R8/ProGuard checks for FFmpeg, split APK/AAB generation, and real-device QA.
---

# Production Release Checklist & Verification

## Trigger Conditions
Use this skill when:
- Preparing a new production or staging release of `ShortsSplitter`.
- Updating app versions in `pubspec.yaml` and `CHANGELOG.md`.
- Building release artifacts (`apk`, `appbundle`) for deployment.

---

## 1. Version Bump & Changelog Update
1. Update `version: X.Y.Z+build` in `pubspec.yaml`:
   - Increment `X` for breaking architecture changes.
   - Increment `Y` for new user features (e.g. new aspect ratio filter).
   - Increment `Z` for bug fixes.
   - Always increment build number (`+build`).
2. Add a new release section to `CHANGELOG.md` following [Keep a Changelog](https://keepachangelog.com/) format.

---

## 2. Secure Signing Configuration (Zero Secrets Committed)
Never place passwords or keystores in source control:
1. Verify `key.properties` and `*.jks` are present in `.gitignore`:
   ```bash
   git status --ignored | grep -E "key\.properties|\.jks"
   ```
2. Configure `android/key.properties` on the build machine:
   ```properties
   storePassword=your_keystore_password
   keyPassword=your_key_password
   keyAlias=your_key_alias
   storeFile=/path/to/release.keystore
   ```

---

## 3. ProGuard & R8 Verification
Ensure `android/app/proguard-rules.pro` contains necessary keep rules for `ffmpeg_kit_flutter_new`:
```proguard
-keep class com.arthenica.ffmpegkit.** { *; }
-dontwarn com.arthenica.ffmpegkit.**
-dontwarn com.google.android.play.core.**
```
Verify that R8 minification does not strip FFmpeg JNI bridge methods during release builds.

---

## 4. Release Build Commands
Generate architecture-split APKs (keeps download sizes $\sim 60\text{MB}$ rather than a single bloated $200\text{MB}+$ fat APK):
```bash
# Split per ABI APKs
flutter build apk --release --split-per-abi

# Or Google Play App Bundle
flutter build appbundle --release
```

Generated outputs:
- `build/app/outputs/flutter-apk/app-arm64-v8a-release.apk`
- `build/app/outputs/flutter-apk/app-armeabi-v7a-release.apk`
- `build/app/outputs/flutter-apk/app-x86_64-release.apk`
- `build/app/outputs/bundle/release/app-release.aab`

---

## 5. Real-Device QA Protocol
Execute these 4 mandatory device checks before signing off on a release:
1. **Large Video Test ($\ge 1\text{GB}$, 4K 60fps):**
   - Verify splitting completes without Out-Of-Memory (OOM) crashes.
   - Verify system memory usage remains flat.
2. **Low Storage Resilience:**
   - Simulate low storage (<500MB free). Verify app halts with clean user error message rather than corrupted partial output.
3. **Mid-Process Cancellation:**
   - Start 10-clip split, hit "Cancel" during clip 4.
   - Verify processing stops immediately.
   - Verify partial clip 4 is deleted and previous clips 1-3 are kept or cleaned up per policy.
4. **App Backgrounding:**
   - Start split, press Home or switch to another app for 30 seconds.
   - Return to app: verify progress resumes/completes smoothly without thread termination.

