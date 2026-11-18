# ShortsSplitter Documentation Index

Welcome to the technical documentation for **ShortsSplitter**, a production-grade Flutter application that splits long videos into contiguous, sequentially numbered vertical clips optimized for YouTube Shorts, Instagram Reels, and TikTok.

---

## "Start Here" Fast Paths

Choose the reading order that matches your current goal:

### Path A: New Developer Onboarding
1. [SETUP.md](./SETUP.md): Install Flutter, Android SDK, and launch your first debug build.
2. [ARCHITECTURE.md](./ARCHITECTURE.md): Understand feature-first layering and the inward dependency rule.
3. [COMMANDS.md](./COMMANDS.md): Bookmark daily CLI commands and code-generation scripts.
4. [UI_GUIDE.md](./UI_GUIDE.md): Master design tokens, the 14 shared widgets, and 4 required screen states.
5. [CONTRIBUTING.md](./CONTRIBUTING.md): Review branch standards, conventional commits, and Definition of Done.

### Path B: Production Build & Release
1. [BUILD_AND_RELEASE.md](./BUILD_AND_RELEASE.md): Step-by-step keystore signing, split-ABI APKs, and Play Console AABs.
2. [ANDROID_COMPAT.md](./ANDROID_COMPAT.md): Compatibility matrix covering Android 9 (API 28) to Android 15 (API 35+).
3. [TESTING.md](./TESTING.md): Pre-release test checklist covering real-device edge cases.
4. [CHANGELOG.md](../CHANGELOG.md): Record version increments following Keep a Changelog.

### Path C: Debugging & Field Diagnostics
1. [TROUBLESHOOTING.md](./TROUBLESHOOTING.md): Rapid symptom-cause-fix table for 20+ common runtime and build issues.
2. [FFMPEG.md](./FFMPEG.md): How to inspect native FFmpeg session logs and command execution.
3. [STORAGE_AND_PERMISSIONS.md](./STORAGE_AND_PERMISSIONS.md): Debug SAF tree permissions, MediaStore fallbacks, and temp file lifecycles.

---

## Complete Documentation Catalog

| Document | Primary Audience | Description |
| :--- | :--- | :--- |
| [SETUP.md](./SETUP.md) | All Developers | Environment setup (Flutter, JDK 17, Android SDK), OS notes, emulator/device setup, and initial run. |
| [COMMANDS.md](./COMMANDS.md) | All Developers | Copy-paste CLI reference for Flutter, scripts, adb, Android SDK tools, Git, and Antigravity workflows. |
| [ARCHITECTURE.md](./ARCHITECTURE.md) | Engineers & Architects | Clean feature-first layer maps, data flows, Mermaid diagrams, and strict FFmpeg isolation boundaries. |
| [FEATURES.md](./FEATURES.md) | Product & QA | In-depth breakdown of the 180s cap, trim handles, plan review, overlay badges, and canvas formats. |
| [UI_GUIDE.md](./UI_GUIDE.md) | UI/UX Engineers | Screen inventory, GoRouter paths, design tokens, 14 reusable primitives, and accessibility standards. |
| [STORAGE_AND_PERMISSIONS.md](./STORAGE_AND_PERMISSIONS.md) | Android Engineers | 4-tier storage strategy (SAF, MediaStore, legacy, app-external), runtime permission matrix, and lifecycle. |
| [ANDROID_COMPAT.md](./ANDROID_COMPAT.md) | QA & Mobile Engineers | API 28 through API 35+ validation checklist, emulator images, and hardware encoder fallbacks. |
| [FFMPEG.md](./FFMPEG.md) | Media Engineers | `VideoProcessor` abstraction, FilterGraphBuilder filter recipes (crop, blur, color, text), and session logging. |
| [BUILD_AND_RELEASE.md](./BUILD_AND_RELEASE.md) | Release Engineers | Keystore generation, `key.properties`, R8/ProGuard rules, split-ABI generation, and Play Console release steps. |
| [TESTING.md](./TESTING.md) | QA & Engineers | Testing pyramid, Riverpod fakes (`FakeVideoProcessor`, `FakeClipWriter`), widget test harness, and device QA. |
| [TEST_CASES.md](./TEST_CASES.md) | QA & Engineers | Deterministic test case catalogue (`TC-<AREA>-<NNN>`), procedures, and traceability matrix. |
| [TROUBLESHOOTING.md](./TROUBLESHOOTING.md) | All Developers | Comprehensive symptom-cause-fix matrix resolving 20+ build, FFmpeg, SAF, and platform errors. |
| [AGENT_SETUP.md](./AGENT_SETUP.md) | AI & Team Leads | Antigravity AI configuration, rules, skills, workflows, and strict automation boundaries. |
| [CONTRIBUTING.md](./CONTRIBUTING.md) | Contributors | Branch conventions, conventional commit standards, PR requirements, and code hygiene rules. |
| [DECISIONS.md](./DECISIONS.md) | Architects & Maintainers | Architecture Decision Records (ADRs) tracking structural choices from inception through current release. |
| [PRIVACY.md](./PRIVACY.md) | Users & Compliance | Clear, human-readable summary of on-device processing, zero-network footprint, and storage governance. |

