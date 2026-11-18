# ShortsSplitter Local Development Setup Guide

Complete instructions for configuring your workstation, installing required toolchains, cloning the repository, and running ShortsSplitter on emulators and physical Android devices.

---

## Table of Contents
1. [Prerequisites & Version Matrix](#1-prerequisites--version-matrix)
2. [Operating System Setup](#2-operating-system-setup)
   - [Linux (Ubuntu / Debian)](#linux-ubuntu--debian)
   - [macOS](#macos)
   - [Windows](#windows)
3. [Cloning & Repository Initialization](#3-cloning--repository-initialization)
4. [Running on an Android Emulator](#4-running-on-an-android-emulator)
5. [Running on a Physical Android Device](#5-running-on-a-physical-android-device)
6. [Common First-Run Errors & Fixes](#6-common-first-run-errors--fixes)

---

## 1. Prerequisites & Version Matrix

ShortsSplitter uses strict toolchain pinning. Ensure your environment matches these versions:

| Component | Pinned Version | Verification Command |
| :--- | :--- | :--- |
| **Flutter SDK** | `3.47.5` (channel stable) | `flutter --version` |
| **Dart SDK** | `3.13.4` (sound null-safety) | `dart --version` |
| **Java Development Kit (JDK)** | OpenJDK `17` (LTS) | `java -version` |
| **Android SDK Compile** | `API 36` | Android Studio SDK Manager |
| **Android SDK Target** | `API 35` (Android 15) | Android Studio SDK Manager |
| **Android SDK Minimum** | `API 28` (Android 9) | Validated in `build.gradle.kts` |
| **Android Build-Tools** | `35.0.0` or `36.0.0` | `sdkmanager --list` |
| **Android Platform-Tools** | `adb` 35.0+ | `adb version` |

---

## 2. Operating System Setup

### Linux (Ubuntu / Debian)

1. **Install Base System Dependencies:**
   ```bash
   sudo apt update
   sudo apt install -y curl git unzip xz-utils zip libglu1-mesa clang cmake ninja-build pkg-config libgtk-3-dev openjdk-17-jdk
   ```

2. **Configure Java 17 as Default:**
   ```bash
   sudo update-alternatives --config java
   # Select OpenJDK 17
   export JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64
   echo "export JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64" >> ~/.bashrc
   ```

3. **Install Flutter SDK (`3.47.5`):**
   ```bash
   cd ~
   git clone https://github.com/flutter/flutter.git -b stable
   cd flutter
   git checkout 3.47.5
   export PATH="$PATH:$HOME/flutter/bin"
   echo 'export PATH="$PATH:$HOME/flutter/bin"' >> ~/.bashrc
   source ~/.bashrc
   ```

4. **Verify Environment:**
   ```bash
   flutter doctor
   ```

### macOS

1. **Install Homebrew & System Prerequisites:**
   ```bash
   /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
   brew install git openjdk@17
   ```

2. **Configure Java 17 Path:**
   ```bash
   sudo ln -sfn /opt/homebrew/opt/openjdk@17/libexec/openjdk.jdk /Library/Java/JavaVirtualMachines/openjdk-17.jdk
   export JAVA_HOME=$(/usr/libexec/java_home -v 17)
   echo 'export JAVA_HOME=$(/usr/libexec/java_home -v 17)' >> ~/.zshrc
   ```

3. **Install Flutter SDK (`3.47.5`):**
   ```bash
   cd ~
   git clone https://github.com/flutter/flutter.git -b stable
   cd flutter
   git checkout 3.47.5
   export PATH="$PATH:$HOME/flutter/bin"
   echo 'export PATH="$PATH:$HOME/flutter/bin"' >> ~/.zshrc
   source ~/.zshrc
   ```

### Windows

1. **Enable Long Paths:**
   Open PowerShell as Administrator and execute:
   ```powershell
   New-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem" -Name "LongPathsEnabled" -Value 1 -PropertyType DWORD -Force
   ```
2. **Install Git & OpenJDK 17:**
   Download and install Git for Windows from [git-scm.com](https://git-scm.com/) and Eclipse Temurin JDK 17 from [adoptium.net](https://adoptium.net/).
3. **Configure Environment Variables:**
   - Add `JAVA_HOME` pointing to `C:\Program Files\Eclipse Adoptium\jdk-17.x.x-hotspot`.
   - Add `%JAVA_HOME%\bin` and `C:\flutter\bin` to your system `PATH`.
4. **Checkout Pinned Flutter:**
   ```powershell
   cd C:\
   git clone https://github.com/flutter/flutter.git -b stable
   cd flutter
   git checkout 3.47.5
   ```

---

## 3. Cloning & Repository Initialization

1. **Clone the Repository:**
   ```bash
   git clone https://github.com/shortssplitter/shorts_splitter.git
   cd shorts_splitter
   ```

2. **Accept Android SDK Licenses:**
   ```bash
   flutter doctor --android-licenses
   ```

3. **Install Flutter Dependencies:**
   ```bash
   flutter pub get
   ```

4. **Execute Pre-flight Verification:**
   ```bash
   ./scripts/verify.sh
   ```
   *(Windows: run `dart format --output=none --set-exit-if-changed . && flutter analyze && flutter test`)*

---

## 4. Running on an Android Emulator

1. **Create an Android Virtual Device (AVD):**
   Open Android Studio > **Virtual Device Manager** and create a device:
   - **Device:** Pixel 7 or Pixel 8
   - **System Image:** Android 14 (`API 34`, `x86_64`) or Android 15 (`API 35`, `x86_64`) with Google Play services
2. **Launch the Emulator:**
   ```bash
   # List installed AVDs
   emulator -list-avds

   # Start targeted AVD
   emulator -avd Pixel_8_API_35
   ```
3. **Launch ShortsSplitter:**
   ```bash
   flutter run
   ```

---

## 5. Running on a Physical Android Device

1. **Enable Developer Options on Device:**
   - Open **Settings** > **About Phone**.
   - Tap **Build Number** 7 times until you see *"You are now a developer!"*.
2. **Enable USB Debugging:**
   - Go to **Settings** > **System** > **Developer Options**.
   - Enable **USB Debugging**.
   - On Android 11+, you may alternatively enable **Wireless Debugging**.
3. **Connect Device via USB:**
   Connect your device and authorize the host computer RSA key fingerprint prompt.
4. **Verify ADB Connection:**
   ```bash
   adb devices
   # Expected output:
   # List of devices attached
   # 123456789ABCDEF    device
   ```
5. **Run the App on Connected Device:**
   ```bash
   flutter run -d <device-id>
   ```

---

## 6. Common First-Run Errors & Fixes

### Issue 1: Android SDK Licenses Not Accepted
- **Symptom:** `Android license status unknown` in `flutter doctor`.
- **Fix:** Execute:
  ```bash
  flutter doctor --android-licenses
  ```
  Press `y` to accept all SDK package licenses.

### Issue 2: Incompatible Java Runtime (AGP 8.x Requires JDK 17)
- **Symptom:** Gradle failure: `Unsupported class file major version 65` or `Android Gradle plugin requires Java 17`.
- **Fix:** Verify `java -version` returns Java 17. Configure Android Studio's embedded JDK:
  - Settings > Build, Execution, Deployment > Build Tools > Gradle > **Gradle JDK** -> Choose **Java 17**.

### Issue 3: Missing Linux C/C++ Toolchain
- **Symptom:** `clang++ is required for Linux development`.
- **Fix:** If developing primarily for Android on Linux, desktop builds can be ignored, or install native build tools:
  ```bash
  sudo apt install clang cmake ninja-build libgtk-3-dev
  ```

### Issue 4: Device Unauthorized via ADB
- **Symptom:** `adb devices` shows `device unauthorized`.
- **Fix:**
  ```bash
  adb kill-server
  adb start-server
  ```
  Disconnect and reconnect USB cable. Accept the authorization popup on the phone screen.

