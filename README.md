# ShortsSplitter 🎬✂️

[![CI](https://github.com/shortssplitter/shorts_splitter/actions/workflows/ci.yml/badge.svg)](https://github.com/shortssplitter/shorts_splitter/actions/workflows/ci.yml)
[![Flutter](https://img.shields.io/badge/Flutter-3.47.5-02569B?logo=flutter)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.13.4-0175C2?logo=dart)](https://dart.dev)
[![Android](https://img.shields.io/badge/Android-API%2028%20to%2035%2B-3DDC84?logo=android)](https://developer.android.com)
[![License](https://img.shields.io/badge/License-Proprietary-red.svg)]()

**ShortsSplitter** is a production-grade Flutter mobile application designed to slice long videos into contiguous, sequentially numbered clips optimized for YouTube Shorts, Instagram Reels, and TikTok. Built with a 4-tier Android Scoped Storage architecture (API 28 through API 35+), sound null-safety, and offline on-device media processing.

---

## Key Features

- **Hard 180s Cap:** Strict enforcement of the YouTube Shorts 3-minute limit across UI, validation domain, and FFmpeg transcode layers.
- **Interactive Trimming:** Visual RangeSlider and millisecond-accurate timefields (`mm:ss.mmm`) with quick trim chips (`First 60s`, `First 3 min`).
- **Plan Review & Part Customization:** Inspect planned slices before exporting. Adjust boundaries interactively, merge fragments under 3 seconds, or split parts with zero gaps.
- **Part Overlays & Badges:** Automatically stamp `Part {n}/{total}` or custom text using font-independent `dart:ui` PNG overlays supporting universal Unicode and emoji.
- **Canvas Formatting & Backgrounds:** Fit-without-crop into vertical 9:16 format with blurred background, solid custom hex colors, or full-bleed crop.
- **Sequential Clip Naming:** Guarantees zero-padded file naming (`{originalName}_part_001.mp4`) matching total clip counts.
- **4-Tier Scoped Storage Strategy:** SAF tree URI persistence, MediaStore collection fallback on Android 10–14, direct writes on Android 9, and app-specific external storage fallback.
- **Foreground Service Export:** Background execution with ongoing notification progress bar surviving task switching.
- **Dedicated Sequence Player:** Built-in full-screen video player with playback speed selector (1x, 1.5x, 2x) and previous/next clip controls.
- **Project History & Search:** Persisted project records, quick multi-select deletion, and undo SnackBar support.
- **Material 3 Design System:** Adaptive layout switching between bottom `NavigationBar` on phones and `NavigationRail` on tablets/wide screens, plus 5 creator accent colors.

---

## App Screens Preview

```
┌─────────────────┐   ┌─────────────────┐   ┌─────────────────┐   ┌─────────────────┐
│    Dashboard    │   │  Video Trimmer  │   │   Plan Review   │   │ Results Gallery │
│  [Quick Create] │   │ [===|======|==] │   │ Part 1 (0:00)   │   │ Part 001.mp4    │
│  [Stats: 12 Sh] │ → │ Start: 00:00.00 │ → │ Part 2 (1:00)   │ → │ Part 002.mp4    │
│  [Recent Proj]  │   │ End:   03:00.00 │   │ Part 3 (2:00)   │   │ [Open] [Share]  │
│ [History] [Set] │   │ [Next: Config]  │   │ [Export Shorts] │   │ [Play Sequence] │
└─────────────────┘   └─────────────────┘   └─────────────────┘   └─────────────────┘
```
*(Visual screenshots can be captured on device and placed in `docs/assets/screenshots/`)*

---

## Quick Start (5 Commands)

Get ShortsSplitter running locally on an emulator or connected device in five commands:

```bash
# 1. Clone the repository
git clone https://github.com/shortssplitter/shorts_splitter.git
cd shorts_splitter

# 2. Verify local environment prerequisites
flutter doctor

# 3. Fetch dependencies
flutter pub get

# 4. Verify static analysis and run tests
./scripts/verify.sh

# 5. Launch the app in debug mode
flutter run
```

---

## Project Documentation

Complete documentation is organized in the [`/docs`](./docs/README.md) directory:

- 📖 **[Documentation Index](./docs/README.md):** Complete navigation and guided reading paths.
- 🛠️ **[Setup Guide](./docs/SETUP.md):** Detailed platform setup for Linux, macOS, and Windows.
- ⚡ **[Commands Reference](./docs/COMMANDS.md):** Copy-paste CLI reference for Flutter, scripts, and adb.
- 🏛️ **[Architecture](./docs/ARCHITECTURE.md):** Inward dependency rules, layer breakdown, and Mermaid diagrams.
- ✨ **[Features Specification](./docs/FEATURES.md):** Deep-dive into duration caps, overlay hierarchies, and trimming rules.
- 🎨 **[UI & Design System Guide](./docs/UI_GUIDE.md):** Design tokens, 14 reusable widgets, and state handling.
- 💾 **[Storage & Permissions](./docs/STORAGE_AND_PERMISSIONS.md):** Android 9 to 15+ 4-tier storage architecture and URI handling.
- 📱 **[Android Compatibility](./docs/ANDROID_COMPAT.md):** Verification matrices and physical QA checklists.
- 🎞️ **[FFmpeg & Media Pipelines](./docs/FFMPEG.md):** Filter graph recipes, keyframe alignment, and session logs.
- 📦 **[Build & Release](./docs/BUILD_AND_RELEASE.md):** Signing configurations, R8 rules, and Play Console deployment.
- 🧪 **[Testing Strategy](./docs/TESTING.md):** Unit, widget, and platform test patterns.
- 🔍 **[Troubleshooting](./docs/TROUBLESHOOTING.md):** Solutions for 20+ common build, transcode, and storage issues.
- 🤖 **[Antigravity Agent Setup](./docs/AGENT_SETUP.md):** Rules, skills, and slash workflows for AI-assisted engineering.
- 🤝 **[Contributing Guide](./docs/CONTRIBUTING.md):** Branch naming, conventional commits, and Definition of Done.
- ⚖️ **[Architecture Decisions (ADR)](./docs/DECISIONS.md):** Historical record of foundational technical decisions.
- 🔒 **[Privacy Policy](./docs/PRIVACY.md):** Offline processing declaration and local data governance.
