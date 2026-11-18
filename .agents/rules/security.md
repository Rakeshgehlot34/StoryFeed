# Security, Privacy & Secret Management

Strict operational security rules for the `shorts_splitter` repository.

## 1. Zero Secrets in Version Control
- **Strictly Prohibited:** Never stage, commit, or push any of the following to Git:
  - Android release keystores: `*.jks`, `*.keystore`
  - Key credentials: `key.properties`, `android/key.properties`
  - SDK / local machine configuration: `local.properties`, `android/local.properties`
  - Environment files: `.env*`
  - Cloud credentials or service account JSON keys.
- **Verification:** Pre-commit hooks and `.gitignore` must actively reject these files.

## 2. Release Signing Configuration
- Release keystores must be loaded dynamically from environment variables or non-tracked local files:
  ```kotlin
  // android/app/build.gradle.kts
  val keystorePropertiesFile = rootProject.file("key.properties")
  // Only configure release signing if file exists
  ```
- In CI/CD pipelines (GitHub Actions), signing secrets must be injected via repository secrets (`KEYSTORE_BASE64`, `KEY_ALIAS`, `KEY_PASSWORD`, `STORE_PASSWORD`).

## 3. Privacy & User Data Protection
- **No Path PII Logging:** Never log full filesystem paths that include user personal identifiers (e.g. `/data/user/0/.../personal_name_videos/...`) to external crash loggers or unprotected consoles in production release builds.
- **Sanitized Log Output:** Log video metadata (duration, resolution, bitrate, clip count) without logging user-identifying file paths.
- **Temp Storage Erasure:** Incomplete video chunks or discarded splits must be securely erased immediately upon processing failure or cancellation.

## 4. Native Binary & ProGuard / R8 Hardening
- Maintain `android/app/proguard-rules.pro` to keep necessary FFmpeg JNI bindings while stripping unused platform symbols.
- Ensure minification does not break `com.arthenica.ffmpegkit` reflection or JNI native registrations.

