# /build-apk Workflow

Interactive workflow for building production, debug, or profile Android APKs with automated pre-flight checks, static analysis, test execution, ABI splitting, and binary metadata verification.

## Execution Steps

1. **Detect Host Operating System & Tooling:**
   - Detect host platform: Linux/macOS vs Windows.
   - On Linux/macOS, execute `./scripts/build_apk.sh`.
   - On Windows, execute `.\scripts\build_apk.ps1`.
   - Verify Flutter SDK and JDK 17 are available on `PATH`.

2. **Prompt for Build Parameters (Interactive Clarification):**
   Confirm the desired build configuration with the user:
   - **Build Type:** `--release` (default / production) vs `--debug` (testing) vs `--profile` (performance profiling).
   - **Packaging Format:** Single universal APK (default) vs `--split-abi` (optimized per-architecture APKs: `arm64-v8a`, `armeabi-v7a`, `x86_64`).
   - **Version Bump:** Whether to increment the build number in `pubspec.yaml` (`--bump`). Note: do NOT bump unless explicitly requested.
   - **Clean Build:** Whether to run `flutter clean` prior to compilation (`--clean`).
   - **Obfuscation:** Whether to enable Dart code obfuscation for release builds (`--obfuscate`).
   - **Skip Tests:** Whether to bypass automated test execution (`--skip-tests`).

3. **Check Keystore & Signing Configuration:**
   - Verify whether `android/key.properties` exists.
   - If missing, advise that the generated APK will be debug-signed (suitable for local testing, but not Google Play production release).

4. **Execute Build Script:**
   Execute the appropriate build script with the resolved flags. Example:
   ```bash
   # Linux / macOS
   ./scripts/build_apk.sh --clean --release
   ```
   ```powershell
   # Windows PowerShell
   .\scripts\build_apk.ps1 -Clean -Release
   ```

5. **Verify Binary Metadata:**
   The script automatically verifies the binary metadata using `aapt2`:
   - Package name: `com.shortssplitter.shorts_splitter`
   - Target SDK: `35`
   - Min SDK: `28` (Android 9 Pie)
   - Version name & code matching `pubspec.yaml`

6. **Output Summary Block or Failure Diagnostics:**
   - **On Success:** Display the standardized summary block with real absolute paths:
     ```text
     ========== BUILD SUCCESS ==========
     App:        ShortsSplitter
     Version:    1.0.0+1
     Build type: release (signed / debug-signed)
     APK path:   <project-root>/dist/ShortsSplitter-1.0.0+1-release.apk
     Original:   <project-root>/build/app/outputs/flutter-apk/app-release.apk
     Size:       XX.X MB
     SHA-256:    <hash>
     Min SDK:    28
     Built at:   YYYY-MM-DD HH:MM:SS
     Install:    adb install -r "<project-root>/dist/ShortsSplitter-1.0.0+1-release.apk"
     ===================================
     ```
   - **On Failure:** Print the last 30 lines of `build/build_apk.log`, state the failed step, and provide actionable remediation guidance.

