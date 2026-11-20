# Architecture Decision Records (ADR)

This document records the foundational architectural, platform, and technology decisions made for **ShortsSplitter**.

---

## Table of Contents
1. [ADR 001: Selection of Flutter as the Application Framework](#adr-001-selection-of-flutter-as-the-application-framework)
2. [ADR 002: State Management with Riverpod (flutter_riverpod)](#adr-002-state-management-with-riverpod-flutter_riverpod)
3. [ADR 003: Encapsulating FFmpeg Behind the VideoProcessor Domain Interface](#adr-003-encapsulating-ffmpeg-behind-the-videoprocessor-domain-interface)
4. [ADR 004: Dual Processing Modes (Stream Copy vs Frame-Accurate Re-encode)](#adr-004-dual-processing-modes-stream-copy-vs-frame-accurate-re-encode)
5. [ADR 005: 4-Tier Android Scoped Storage Strategy (SAF-First)](#adr-005-4-tier-android-scoped-storage-strategy-saf-first)
6. [ADR 006: 9:16 Default Canvas with No Auto-Crop](#adr-006-916-default-canvas-with-no-auto-crop)
7. [ADR 007: Font-Independent PNG-Rendered Text Overlays via dart:ui](#adr-007-font-independent-png-rendered-text-overlays-via-dartui)
8. [ADR 008: 100% Local-Only Offline Processing (Zero Network & Zero Analytics)](#adr-008-100-local-only-offline-processing-zero-network--zero-analytics)
9. [ADR 009: Antigravity-Based Autonomous Engineering Governance](#adr-009-antigravity-based-autonomous-engineering-governance)

---

## ADR 001: Selection of Flutter as the Application Framework

- **Status:** Accepted
- **Date:** 2026-11-17

### Context
ShortsSplitter requires high performance video preview playback, seamless platform channel communication with native C/C++ libraries (FFmpeg), and consistent Material 3 UI behavior across both Android and iOS devices.

### Decision
Build the application using Flutter (Channel stable, Dart 3).

### Consequences
- **Positive:** Single unified codebase for Android and iOS; rich UI primitives for video controls; declarative routing with GoRouter.
- **Negative:** Native binary sizes are larger due to embedding Flutter Engine and FFmpeg native shared libraries (`.so` / `.framework`). Addressed by providing architecture-split APKs (`--split-per-abi`).

---

## ADR 002: State Management with Riverpod (`flutter_riverpod`)

- **Status:** Accepted
- **Date:** 2026-11-17

### Context
The app coordinates complex asynchronous workflows (file selection, stream-based progress updates from native background threads, disk write probing, and user preferences). State must be testable headlessly without `BuildContext` dependency.

### Decision
Adopt `flutter_riverpod` with `Notifier` and `AsyncNotifier` patterns.

### Consequences
- **Positive:** Compile-time safety; decoupled dependency injection via provider overrides (e.g., swapping `videoProcessorProvider` with `FakeVideoProcessor`); automatic cache invalidation and cancellation of subscriptions on widget disposal.
- **Negative:** Requires team alignment on Riverpod conventions and avoidance of legacy `ChangeNotifier` patterns.

---

## ADR 003: Encapsulating FFmpeg Behind the `VideoProcessor` Domain Interface

- **Status:** Accepted
- **Date:** 2026-11-17

### Context
Video manipulation libraries for Flutter change frequently (the original `ffmpeg_kit_flutter` was archived upstream, necessitating migration to community forks like `ffmpeg_kit_flutter_new`). Direct coupling of UI controllers to third-party FFmpeg classes risks vendor lock-in and prevents automated headless unit testing.

### Decision
Abstract all video inspection and trimming operations behind an abstract `VideoProcessor` interface in `lib/features/processing/domain/video_processor.dart`.

### Consequences
- **Positive:** Zero FFmpeg imports in UI, domain models, or split planning logic; test suites run instantly using `FakeVideoProcessor`; the underlying transcode engine can be swapped with native Android MediaCodec or iOS AVFoundation pipelines without rewriting any application logic.
- **Negative:** Requires maintaining mapping models (`VideoMetadata`, `ProcessingProgress`) between native FFmpeg statistics and the domain layer.

---

## ADR 004: Dual Processing Modes (Stream Copy vs Frame-Accurate Re-encode)

- **Status:** Accepted
- **Date:** 2026-11-17

### Context
Users splitting a 1-hour podcast video on a battery-constrained mobile device cannot wait 30 minutes for CPU-intensive H.264 software transcoding. However, users creating vertical Shorts from landscape footage require visual re-encoding (cropping or blurring).

### Decision
Provide two distinct modes:
1. **Fast Mode (`-c copy`):** Near-instantaneous stream copy cutting at nearest keyframes, with timestamps aligned using `-avoid_negative_ts make_zero`.
2. **Precise Mode (`libx264`):** Full re-encode guaranteeing millisecond-accurate cuts and enabling 9:16 vertical crop or blurred background letterboxing. If the user chooses a 9:16 aspect ratio transform, the app automatically switches to Precise Mode.

### Consequences
- **Positive:** Fast splits take 1-3 seconds; creative transforms are fully supported with clear user feedback.
- **Negative:** Users must be educated on keyframe alignment tradeoffs when selecting Fast Mode.

---

## ADR 005: 4-Tier Android Scoped Storage Strategy (SAF-First)

- **Status:** Accepted
- **Date:** 2026-11-17

### Context
Android 9 (API 28) permitted broad direct filesystem access (`WRITE_EXTERNAL_STORAGE`). Android 10 (API 29) introduced Scoped Storage. Android 11 (API 30) strictly mandated Storage Access Framework (SAF) or MediaStore. Android 13 (API 33) removed `READ_EXTERNAL_STORAGE` in favor of `READ_MEDIA_VIDEO`. A single naive storage mechanism cannot reliably support API 28 through API 35+.

### Decision
Implement a 4-tier storage resolution hierarchy in `ClipWriterFactory`:
1. **Tier 1 (Universal API 28+):** SAF Tree URI via `ACTION_OPEN_DOCUMENT_TREE` with `takePersistableUriPermission`.
2. **Tier 2 (Fallback API 28 only):** Direct file writes to `/storage/emulated/0/Movies/ShortsSplitter`.
3. **Tier 3 (Fallback API 29–35+):** MediaStore Video collection with `RELATIVE_PATH = "Movies/ShortsSplitter"`.
4. **Tier 4 (Final Safety):** App-specific external storage (`/Android/data/.../files/ShortsSplitter/`).

### Consequences
- **Positive:** 100% compliance across all Android versions from API 28 to API 35+; zero crashes when permissions are revoked or folders are deleted.
- **Negative:** Requires JNI platform channel bridge (`StorageBridge.kt`) to stream FFmpeg temp files into SAF output streams.

---

## ADR 006: 9:16 Default Canvas with No Auto-Crop

- **Status:** Accepted
- **Date:** 2026-11-17

### Context
YouTube Shorts, Instagram Reels, and TikTok require vertical video (`9:16`). Automatically cropping horizontal (16:9) video to vertical often cuts off speakers, subtitles, or critical visual details, leading to user frustration.

### Decision
Default to **9:16 vertical canvas using Scale-to-Fit** with a blurred background or solid color letterbox padding. Auto-crop is never applied unless the user explicitly enables the "Crop to Fill" toggle.

### Consequences
- **Positive:** Preserves 100% of original visual content without surprising the creator.
- **Negative:** Requires multi-stream FFmpeg filter graphs (`split`, `scale`, `boxblur`, `overlay`) which take longer to encode than simple stream copy.

---

## ADR 007: Font-Independent PNG-Rendered Text Overlays via `dart:ui`

- **Status:** Accepted
- **Date:** 2026-11-17

### Context
Creators require sequential clip badges (e.g., `Part 1/5`, `Part 2/5`). Native FFmpeg text filters (`drawtext`) depend on local TrueType font files (`.ttf`), which vary wildly across Android device OEMs and frequently fail to render modern Unicode characters, Japanese/Korean scripts, or color emojis.

### Decision
Render text overlay badges in Flutter using `dart:ui` (`PictureRecorder` and `Canvas`) into a transparent PNG file on disk via `OverlayRenderer`, then composite the PNG onto the video using FFmpeg's `overlay` filter.

### Consequences
- **Positive:** 100% universal support for all Unicode characters, accents, and emojis; zero font file distribution overhead; identical pixel-perfect badge styling across all devices.
- **Negative:** Requires an intermediate disk write of a tiny transparent `.png` prior to encoding each clip.

---

## ADR 008: 100% Local-Only Offline Processing (Zero Network & Zero Analytics)

- **Status:** Accepted
- **Date:** 2026-11-17

### Context
Video creators frequently handle unreleased, sensitive, or personal footage. Uploading video chunks to remote cloud servers for transcoding introduces bandwidth costs, latency, privacy risks, and infrastructure bills.

### Decision
Process all media strictly on-device using local FFmpeg binaries and local persistent storage. The app includes zero network permissions (`android.permission.INTERNET` is omitted), zero remote tracking SDKs, and zero telemetry analytics.

### Consequences
- **Positive:** Complete creator privacy; zero cloud operating costs; full functionality in airplane mode or remote locations.
- **Negative:** Transcode speed and battery consumption depend entirely on local device hardware CPU capabilities.

---

## ADR 009: Antigravity-Based Autonomous Engineering Governance

- **Status:** Accepted
- **Date:** 2026-11-17

### Context
Maintaining strict domain invariants, 4-tier storage compliance, and design token consistency across rapid iterations requires robust automated developer assistance without risking uncontrolled code drift or broken release artifacts.

### Decision
Configure the repository for Google Antigravity using an authoritative `AGENTS.md` (under 200 lines), specialized rules in `.agents/rules/`, task-specific skills in `.agents/skills/`, and pre-commit workflows in `.agents/workflows/`.

### Consequences
- **Positive:** Enforces strict Definition of Done, automated verify gates, and zero-placeholder standards across all automated turns.
- **Negative:** Requires keeping agent rules, skills, and documentation synchronized via the `/docs-sync` workflow.

---

## ADR 010: Pure FitLayout Domain Model as Single Source of Truth & Tri-State Part Labeling

- **Status:** Accepted
- **Date:** 2026-11-19

### Context
Previously, canvas padding and overlay positioning relied on dynamic FFmpeg expressions evaluated at transcode time (`(W-w)/2`, `(H-h)/2`), while the Flutter live preview used an approximate widget layout. Under certain aspect ratios and rotation metadata, this caused alignment drift between what the creator previewed and the exported video. Additionally, single-part plans unconditionally stamped "Part 1/1" badges at top-right without an option to suppress or control label visibility.

### Decision
1. Introduce `FitLayout` as a pure, zero-dependency domain model calculating exact integer-even pixel geometry (`x`, `y`, `width`, `height`, `topBand`, `bottomBand`) and normalized bounding coordinates. Both `OverlayLivePreview` and `FilterGraphBuilder` strictly derive their layout from `FitLayout`.
2. Provide vertical positioning options (`Center` [default], `Top`, `Bottom`) and fine-tuning manual offset slider ($\pm 20\%$ of free space).
3. Introduce `PartLabelMode` with tri-state selection:
   - `Auto` (Default): Shows part label only when total parts $> 1$; suppresses auto label on single-part conversions.
   - `Always`: Always stamps part label, including single-part plans.
   - `Never`: Disables auto part numbering completely.
4. Support per-part visibility override in `PartMessageDialog` (`Project Default`, `Show`, `Hide`) and single-clip export naming options (`Original name` vs `With suffix`).

### Consequences
- **Positive:** Exact 1:1 pixel parity between preview and export; perfect vertical and horizontal centering symmetry; zero redundant "Part 1/1" badges on single shorts; creator-controlled label visibility.
- **Negative:** Filter graph builder replaces generic expressions with precalculated integer coordinates, requiring test updates to match exact pixel numbers.

---

## ADR 008: Embedded SQLite via Drift & Two-Stage Processing Pipeline

### Status
Accepted

### Context
Managing 100+ clip parts from 2-hour videos in SharedPreferences JSON lists suffered from $O(N)$ string deserialization bottlenecks, lacked foreign key cascade deletion, risked partial file corruption on process kill, and created flat folder clutter when exporting dozens of clips.

### Decision
1. **Adopt Drift SQLite (`drift: ^2.31.0`):** Define strongly-typed tables (`sources`, `projects`, `parts`, `jobs`, `job_events`, `app_settings`) with native cascade deletion (`ON DELETE CASCADE`) and compound performance indexes (`idx_parts_project_index`, `idx_projects_updated_at`).
2. **Implement Non-Destructive Legacy Migration:** Automatically migrate SharedPreferences JSON history to SQLite in a single transaction while preserving the raw SharedPreferences data as a backup.
3. **Two-Stage Workflow:**
   - Stage 1: Ultra-fast stream-copy split (`-c copy`) into project subfolder (`<saveLocation>/<SourceName>/`). Probes actual cut points, records keyframe-snapped timestamps, and flags parts exceeding 180s.
   - Stage 2: Selective transcode of user-chosen parts from the parts review screen.
4. **Safe In-Place Replacement (`SafeClipReplacer`):** Write transcoded clip to temporary storage $\to$ verify integrity $\to$ write staged file beside target $\to$ verify $\to$ atomic delete of old file and rename staged to final name. Preserves original raw clip on any error.
5. **Output Folder Layout Resolver:** Multi-part plans ($\ge 2$ parts) write into dedicated subfolder `<saveLocation>/<SourceName>/`; single-part outputs ($= 1$) write directly into root without wrapper folder.
6. **Granular 4 Hz Progress Tracking:** Throttled monotonic progress tracker with per-row Riverpod selector `partProgressProvider(index)` using `.select()`, eliminating full-list rebuilds during transcoding.

### Consequences
- **Positive:** Sub-millisecond queries for thousands of parts; robust relational integrity; zero data loss during app crashes; uncluttered storage organization; immediate playback availability of raw parts while long encodes proceed.
- **Negative:** Added `drift`, `drift_flutter`, and `sqlite3_flutter_libs` dependencies; required build_runner code generation for Drift companions.

