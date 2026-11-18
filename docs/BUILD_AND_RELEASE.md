# ShortsSplitter Build & Release Guide

Step-by-step procedures for versioning, cryptographic signing, ProGuard R8 optimization, split-ABI packaging, and Google Play Store deployment.

---

## Table of Contents
1. [Versioning Policy](#1-versioning-policy)
2. [Cryptographic Keystore Generation](#2-cryptographic-keystore-generation)
3. [Configuring key.properties (Never Commit Secrets)](#3-configuring-keyproperties-never-commit-secrets)
4. [R8 / ProGuard Configuration](#4-r8--proguard-configuration)
5. [Packaging Artifacts: Split APK vs AAB](#5-packaging-artifacts-split-apk-vs-aab)
6. [Pre-Release Production Checklist](#6-pre-release-production-checklist)
7. [Step-by-Step Release Procedure](#7-step-by-step-release-procedure)
8. [Rollback & Emergency Recovery](#8-rollback--emergency-recovery)

---

## 1. Versioning Policy

ShortsSplitter follows [Semantic Versioning 2.0.0](https://semver.org/):

```
version: major.minor.patch+buildNumber
```
- Defined in `pubspec.yaml` (e.g. `version: 1.0.0+1`).
- `major`: Incompatible architectural or breaking domain invariant changes.
- `minor`: New backward-compatible features (e.g. new canvas formats, additional presets).
- `patch`: Backward-compatible bug fixes and stability enhancements.
- `+buildNumber`: Monotonically increasing integer required by Google Play Console for each artifact upload.

---

## 2. Cryptographic Keystore Generation

Generate a release signing key using Java `keytool`:

```bash
keytool -genkey -v \
  -keystore shorts_splitter_release.jks \
  -keyalg RSA \
  -keysize 2048 \
  -validity 10000 \
  -alias shortssplitter
```

Store `shorts_splitter_release.jks` in a secure password manager. **Never commit the `.jks` file to source control.**

---

## 3. Configuring key.properties (Never Commit Secrets)

Create `android/key.properties` with credentials. Both `key.properties` and `*.jks` are ignored by `.gitignore`.

### Template with Fake Values (DO NOT USE REAL SECRETS HERE)
```properties
# android/key.properties
# FAKE CREDENTIALS TEMPLATE - Replace with real private credentials locally
storePassword=fake_store_password_12345
keyPassword=fake_key_password_12345
keyAlias=shortssplitter
storeFile=/absolute/path/to/shorts_splitter_release.jks
```

### Loading in `android/app/build.gradle.kts`
```kotlin
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    signingConfigs {
        create("release") {
            keyAlias = keystoreProperties["keyAlias"] as String?
            keyPassword = keystoreProperties["keyPassword"] as String?
            storeFile = keystoreProperties["storeFile"]?.let { file(it) }
            storePassword = keystoreProperties["storePassword"] as String?
        }
    }
    buildTypes {
        release {
            signingConfig = signingConfigs.getByName(
                if (keystorePropertiesFile.exists()) "release" else "debug"
            )
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }
}
```

---

## 4. R8 / ProGuard Configuration

ShortsSplitter enables code shrinking (`isMinifyEnabled = true`) and resource shrinking (`isShrinkResources = true`). To prevent R8 from stripping native C/C++ JNI methods used by FFmpeg Kit:

```proguard
# android/app/proguard-rules.pro

# Retain FFmpegKit JNI wrappers and native method signatures
-keep class com.arthenica.ffmpegkit.** { *; }
-keep interface com.arthenica.ffmpegkit.** { *; }
-keepclassmembers class * {
    native <methods>;
}

# Retain Flutter and documentfile classes
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class androidx.documentfile.provider.** { *; }
```

---

## 5. Packaging Artifacts: Split APK vs AAB

### 16 KB Page-Size Verification Check
For Android 15 and Android 16 compatibility, verify 16 KB page-size ELF alignment:
```bash
./scripts/check_16kb.sh dist/ShortsSplitter-1.0.0+1-release.apk
```
This checks that all 64-bit `.so` libraries have LOAD segment alignment of `0x4000` (16 KB) or `0x10000` (64 KB) and that the APK is 16 KB zip-aligned via `zipalign -c -P 16 -v 4`.

### Architecture-Split Release APKs (for Direct Distribution / QA)
```bash
./scripts/build_apk.sh
# or: flutter build apk --release --split-per-abi
```
Generates 3 optimized APKs in `build/app/outputs/flutter-apk/`:
- `app-arm64-v8a-release.apk` (~35 MB) — Modern smartphones.
- `app-armeabi-v7a-release.apk` (~32 MB) — Older 32-bit devices.
- `app-x86_64-release.apk` (~38 MB) — Emulators and Chromebooks.

### Google Play App Bundle (.aab)
```bash
flutter build appbundle --release --obfuscate --split-debug-info=build/app/outputs/symbols
```
Generates `build/app/outputs/bundle/release/app-release.aab`. Google Play automatically serves device-tailored split APKs (~28MB download) from this bundle.

---

## 6. Pre-Release Production Checklist

Before tagging and publishing a release:
- [ ] Version code and name bumped in `pubspec.yaml`.
- [ ] `CHANGELOG.md` updated with release notes under new version heading.
- [ ] Pre-commit quality verification passed: `./scripts/verify.sh`.
- [ ] Documentation integrity verified: `./scripts/docs_check.sh`.
- [ ] Cryptographic signature verified: `apksigner verify --verbose <apk>`.
- [ ] Real-device QA checklist completed across Android 9 and Android 15.

---

## 7. Step-by-Step Release Procedure

1. **Verify Clean Working Tree:**
   ```bash
   git status
   ```
2. **Execute Full Verification:**
   ```bash
   ./scripts/verify.sh
   ```
3. **Build Production App Bundle:**
   ```bash
   flutter build appbundle --release --obfuscate --split-debug-info=build/app/outputs/symbols
   ```
4. **Tag Release in Git:**
   ```bash
   git tag -a v1.0.0 -m "Release v1.0.0"
   git push origin main --tags
   ```
5. **Upload to Google Play Console:**
   - Navigate to Google Play Console > **Release** > **Production**.
   - Create new release and upload `build/app/outputs/bundle/release/app-release.aab`.
   - Upload de-obfuscation debug symbol mapping files from `build/app/outputs/symbols`.
   - Submit for review.

---

## 8. Rollback & Emergency Recovery

If a critical defect is identified post-release:
1. Revert offending commit on `main`.
2. Increment `version` build number (e.g. `1.0.0+2` -> `1.0.1+3`).
3. Re-run `./scripts/verify.sh`.
4. Build new AAB and deploy to Google Play Console as an expedited release.

