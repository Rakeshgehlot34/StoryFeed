---
name: release-checklist
description: Step-by-step production release guide covering semantic versioning, secure Android signing without committing secrets, R8/ProGuard verification, APK/AAB builds, and real-device pre-flight QA.
---

# Release Checklist for ShortsSplitter

Follow this checklist before releasing an update to Google Play, TestFlight, or GitHub Releases.

---

## 1. Version Bump in `pubspec.yaml`
Update `version: x.y.z+build` according to SemVer:
```yaml
version: 1.1.0+2 # Increment versionName and versionCode
```
Sync project dependencies:
```bash
flutter pub get
```

---

## 2. Secure Android Keystore Configuration (Zero Secrets Committed)

1. Generate release keystore if not already created:
   ```bash
   keytool -genkey -v -keystore ~/upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
   ```
2. Create `android/key.properties` (strictly ignored by `.gitignore`):
   ```properties
   storePassword=<PASSWORD>
   keyPassword=<PASSWORD>
   keyAlias=upload
   storeFile=/home/user/upload-keystore.jks
   ```
3. Verify `android/app/build.gradle.kts` references `key.properties` dynamically without hardcoding keys:
   ```kotlin
   val keystorePropertiesFile = rootProject.file("key.properties")
   val keystoreProperties = java.util.Properties()
   if (keystorePropertiesFile.exists()) {
       keystoreProperties.load(java.io.FileInputStream(keystorePropertiesFile))
       signingConfigs {
           create("release") {
               keyAlias = keystoreProperties["keyAlias"] as String
               keyPassword = keystoreProperties["keyPassword"] as String
               storeFile = file(keystoreProperties["storeFile"] as String)
               storePassword = keystoreProperties["storePassword"] as String
           }
       }
   }
   ```

---

## 3. R8 / ProGuard Rule Inspection
Ensure [android/app/proguard-rules.pro](file:///home/user/Documents/RG/StoryFeed/android/app/proguard-rules.pro) preserves:
- FFmpegKit native JNI bindings (`com.arthenica.ffmpegkit.**`).
- Suppresses Play Store deferred components (`-dontwarn com.google.android.play.core.**`).
- Shared preferences and video player reflections.

---

## 4. Build Commands

```bash
# Clean artifact cache
flutter clean && flutter pub get

# Universal Release APK
flutter build apk --release

# Recommended: Architecture-Split Release APKs (arm64-v8a: 64MB)
flutter build apk --split-per-abi --release

# Google Play App Bundle (AAB)
flutter build appbundle --release
```

---

## 5. Pre-Release Physical Device QA Checklist

Execute this manual QA matrix on a physical Android device (API 30–35):

- [ ] **Large Video Stability (1GB+):** Pick a 4K 1.5GB video. Run a 60s split. Monitor memory usage with Android Studio Profiler (RAM must stay $< 80\text{ MB}$).
- [ ] **Fast vs Precise Modes:**
  - Fast Mode: verify export completes in $< 3$ seconds.
  - Precise Mode: verify frame-accurate start at 00:00.000 without audio glitch.
- [ ] **Aspect Ratio Transforms:**
  - 9:16 Crop: verify output is 1080x1920 full bleed.
  - 9:16 Blur Letterbox: verify background is blurred, foreground original video is sharp and centered.
- [ ] **Mid-Flight Cancellation:** Tap "Cancel Split" on clip 3 of 5. Verify FFmpeg halts immediately, partial `.mp4` file is deleted from disk, and app returns to settings.
- [ ] **App Lifecycle & Backgrounding:** Start a 5-clip encode. Press the Home button or lock the phone. Wait 2 minutes. Reopen app: verify encode completed in background via `WAKE_LOCK`.
- [ ] **Low Storage Guard:** Test with $< 500\text{ MB}$ free space; verify `InsufficientStorageException` is presented cleanly.
- [ ] **Output Directory SAF Persistence:** Change output folder, restart the app, and verify the chosen directory remains active.

