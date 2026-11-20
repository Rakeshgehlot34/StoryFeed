# ShortsSplitter Features & Functional Specifications

Detailed specifications, domain invariants, and mathematical rules governing every feature in ShortsSplitter.

---

## Table of Contents
1. [Hard 3-Minute (180s) Cap](#1-hard-3-minute-180s-cap)
2. [Custom Start & End Range Trimmer](#2-custom-start--end-range-trimmer)
3. [Plan Review & Interactive Part Editing](#3-plan-review--interactive-part-editing)
4. [Overlay Badges & Text Hierarchy](#4-overlay-badges--text-hierarchy)
5. [Canvas Formatting & Background Rendering](#5-canvas-formatting--background-rendering)
6. [Sequential Clip Naming & Zero Padding](#6-sequential-clip-naming--zero-padding)
7. [Trailing Remainder Merge Logic](#7-trailing-remainder-merge-logic)
8. [Transcoding Modes: Fast vs Precise](#8-transcoding-modes-fast-vs-precise)
9. [Destination Storage & Duplicate Handling](#9-destination-storage--duplicate-handling)
10. [Project History & Activity Metrics](#10-project-history--activity-metrics)
11. [YouTube Shorts Platform Specifications](#11-youtube-shorts-platform-specifications)
12. [Centralized Validation Architecture & Platform Invariants](#12-centralized-validation-architecture--platform-invariants)
13. [Interactive Trim Timeline & Mathematical Coordinate Mapper](#13-interactive-trim-timeline--mathematical-coordinate-mapper)
14. [Selective Clip Processing & High-Performance Engine](#14-selective-clip-processing--high-performance-engine)

---

## 1. Hard 3-Minute (180s) Cap

ShortsSplitter enforces a strict hard ceiling of **180.0 seconds** (3 minutes max) on every generated clip.

### Multi-Layer Enforcement
1. **Presentation Layer (UI):** Target duration inputs are clamped to `[1, 180]`. Preset chips provide `15s`, `30s`, `45s`, `60s`, `90s`, `2 min (120s)`, and `3 min (180s)`. Inputs exceeding 180s display immediate visual validation feedback.
2. **Domain Layer (`PlanValidator`):** Throws `PlanValidationException` if any clip segment's duration satisfies:
   $$\text{duration} > 180.0 \quad \text{or} \quad \text{duration} < 1.0$$
3. **Processing Layer (`FFmpegVideoProcessor`):** Asserts `part.durationSeconds <= 180.0` immediately before dispatching commands to native FFmpeg.

---

## 2. Custom Start & End Range Trimmer

Allows users to isolate an arbitrary section of a long video before splitting.

### Specifications & Advanced Controls
- **Preview Player:** Integrated `VideoPlayer` powered by singleton `PlayerService`. Features tap-to-play/pause, live playback position overlay, and duration timestamps.
- **Dual-Handle RangeSlider & Playhead:** Range slider with visual playhead indicator. Tapping "Zoom In" toggles a 5x magnified view for sub-second precision.
- **Quick Action Snapping:**
  - `Set Start Here`: Snaps `startSeconds` directly to current video playback position.
  - `Set End Here`: Snaps `endSeconds` directly to current video playback position.
  - `Play Trim`: Plays strictly the bounded selection (`startSeconds` to `endSeconds`) with auto-stop and rewind.
  - `Jump to Start / End`: Seeks directly to the respective boundary with muted audio.
- **Scrollable Wheel Time Picker (`WheelTimePickerSheet`):** Modal bottom sheet providing tactile `ListWheelScrollView` wheels for hours, minutes, seconds, and milliseconds, with live preview seeking and direct keyboard entry toggle.
- **Fine-Nudge Controls:** Nudge bar with target toggle (`[ Start | End ]`) providing `-1s`, `-0.1s`, `-1f` (1/30s), `+1f`, `+0.1s`, and `+1s` adjustments with auto-repeating timer on press-and-hold and haptic feedback.
- **Validation Rules:**
  - `startSeconds >= 0.0`
  - `endSeconds <= totalVideoDuration`
  - `endSeconds - startSeconds >= 1.0` (minimum 1 second range; disables next button and shows warning if violated)
- **Contiguity Guarantee:** Only footage within the selected trim range is split. Slices inside the range remain strictly contiguous.

---

## 3. Plan Review & Interactive Part Editing

Before any transcoding begins, users inspect the generated split plan on the **Plan Review Screen** (`/plan-review`).

### Capabilities
- **Summary Metrics:** Total shorts count, total split duration, source video resolution, and canvas aspect ratio.
- **Single-Part Smart Detection:** When an already-short video yields exactly 1 short, a dedicated info banner displays "Your video fits in 1 short. No splitting needed!", and the action button reflects "Create 1 Short (XX.Xs)". If the source is already 9:16 and $\le 180$s without edits, an "Already Shorts-ready: Fast stream copy available" badge is shown.
- **Part List:** Each part displays index (`Part 1 of N`), timestamps (`00:00.000 - 01:00.000`), duration, and effective overlay text (or "No label (tap to add)" badge when suppressed or empty).
- **Interactive Boundary Editing:**
  - Dragging or entering a new boundary timestamp updates both adjacent clips:
    $$\text{Clip}_i.\text{endSeconds} = \text{newBoundary} = \text{Clip}_{i+1}.\text{startSeconds}$$
  - Preserves contiguity with zero gaps and zero overlaps.
  - Automatically rejected if boundary adjustment causes either clip to violate the 180s cap or 1s minimum.
- **Split Part:** Any clip $\ge 2.0$ seconds can be split into two sub-clips at its midpoint or a chosen timestamp.
- **Merge Parts:** Any two adjacent parts can be merged into a single clip, provided their combined duration $\le 180.0$ seconds.
- **Per-Part Label Visibility Dialog:** Tapping any part's message opens `PartMessageDialog` with an explicit override selector (`Project Default`, `Show`, `Hide`) and optional custom message.

---

## 4. Overlay Badges & Text Hierarchy

Text overlays (e.g. `Part 1/5`) are rendered as transparent PNG images via `dart:ui` by `OverlayRenderer`. This guarantees universal Unicode and emoji rendering without relying on system font files.

### Part Label Modes
ShortsSplitter provides three distinct modes for part label rendering:
1. **Auto (Default):** Show part label only when the sequence produces **more than 1 clip**. For single-clip conversions, the auto label is cleanly suppressed, eliminating meaningless "Part 1/1" badges.
2. **Always:** Show part label on every clip, including single-clip conversions ("Part 1/1").
3. **Never:** Completely disable auto part numbering across all clips.

### 4-Tier Resolution Hierarchy
When generating the overlay badge for clip $i$, the engine evaluates rules in strict order:
1. **Specific Part Custom Message:** If user defined a custom message for part $i$, use it directly (never suppressed by Auto/Never modes).
2. **All Parts Message:** Else if user defined a global custom message, evaluate it.
3. **Per-Part Override & Auto Label Template:** Else if per-part override is `show` or (`useProjectDefault` with `partLabelMode != never` and not suppressed by 1-clip Auto), evaluate the template (default: `Part {n}/{total}`).
4. **No Overlay:** Else render no badge.

### Token Replacement Variables
Templates support dynamic string replacement:
- `{n}`: current clip 1-based index (e.g. `1`).
- `{total}`: total count of clips in the sequence (e.g. `5`).
- `{name}`: original video base filename.

### 7 Layout Position Presets
The overlay badge position supports 7 presets respecting the platform safe area:
- `topLeft`, `topCenter` (default), `topRight`, `center`, `bottomLeft`, `bottomCenter`, `bottomRight`.

---

## 5. Canvas Formatting & Background Rendering

ShortsSplitter formats any video container (landscape, square, or portrait) to meet vertical platform specifications using `FitLayout` as the single source of truth across Flutter live preview and native FFmpeg export.

### Pure Domain `FitLayout`
- **Integer-Even Pixel Alignment:** Computes exact integer coordinates (`x`, `y`, `width`, `height`, `topBand`, `bottomBand`) where all values are guaranteed even integers, avoiding odd-pixel blur and platform codec rejections.
- **Symmetric Centering:** By default, fitted videos are centered horizontally and vertically, guaranteeing `topBand == bottomBand` (within 2px even-pixel rounding).
- **Vertical Positions:**
  - `Center (Default)`: Horizontally and vertically centered.
  - `Top`: Pinned to the top edge (`topBand = 0`), leaving remaining space at the bottom.
  - `Bottom`: Pinned to the bottom edge (`bottomBand = 0`), leaving remaining space at the top.
- **Manual Offset Slider:** Fine-nudge slider allowing $\pm 20\%$ offset of the available free space.
- **Rotation Metadata & SAR:** Automatically swaps dimensions for 90°/270° orientation tags and scales non-square pixel aspect ratios before computing layout.

### Canvas Formats
1. **Vertical 9:16 (Default):** Standard `1080x1920` canvas for YouTube Shorts, Instagram Reels, and TikTok.
2. **Square 1:1:** `1080x1080` canvas for feeds.
3. **Landscape 16:9:** `1920x1080` canvas. Displays an in-app notice reminding users that horizontal videos over 60 seconds are not classified as YouTube Shorts.

### Fit & Background Styles (Never Auto-Crop by Default)
- **Scale to Fit (Default):** Video is scaled to fit within canvas bounds preserving original aspect ratio.
- **Blurred Background:** Background canvas is populated by a downscaled, blurred (`scale=108:192,boxblur=5:1,scale=1080:1920`) version of the video covering the canvas.
- **Solid Color:** Letterbox padding filled with user-selected solid color (default black, white, or custom hex).
- **Custom Image Background:** Looped image scaled to cover the canvas (`scale=cw:ch:force_original_aspect_ratio=increase,crop=cw:ch`) with foreground video overlaid at exact `FitLayout` coordinates.
- **Crop to Fill (Explicit Toggle):** Scales footage to fill the entire canvas, cropping edges for landscape footage.

---

## 6. Sequential Clip Naming & Zero Padding

Exported files follow a deterministic naming convention:
$$\text{\{originalName\}\_part\_\{NNN\}.mp4}$$

### Single-Part Naming Options
When a split job yields exactly 1 short (or for single-part conversions):
- **Name Only (`originalNameOnly`):** Saves as `{baseName}.mp4` without a redundant `_part_001` suffix.
- **With Suffix (`keepPartSuffix`):** Preserves standard `{baseName}_part_001.mp4`.

For all multi-part sequences ($\ge 2$ clips), `{baseName}_part_{NNN}.mp4` is strictly invariant across all platforms.

### Zero-Padding Rules
Padding width is computed as:
$$\text{padWidth} = \max(3, \text{digits}(\text{totalClips}))$$
- Total 5 clips: `video_part_001.mp4` through `video_part_005.mp4` (width 3).
- Total 45 clips: `video_part_001.mp4` through `video_part_045.mp4` (width 3).
- Total 1,200 clips: `video_part_0001.mp4` through `video_part_1200.mp4` (width 4).

---

## 7. Trailing Remainder Merge Logic

Prevents annoying 1-second or 2-second leftover clips at the end of a video.

### Logic
If total duration is not an exact multiple of the target duration:
$$\text{remainder} = \text{totalDuration} \pmod{\text{targetDuration}}$$
1. If $\text{remainder} < 3.0\text{s}$ AND `mergeShortTrailingClip` is enabled:
   - Check if $\text{penultimateDuration} + \text{remainder} \le 180.0\text{s}$.
   - If sum $\le 180.0\text{s}$: Merge remainder into penultimate clip.
   - If sum $> 180.0\text{s}$: Keep remainder as an independent clip.
2. If $\text{remainder} \ge 3.0\text{s}$ OR `mergeShortTrailingClip` is disabled:
   - Remainder remains an independent clip.

---

## 8. Transcoding Modes: Fast vs Precise

- **Fast Mode (`-c copy`):**
  - Near-instantaneous stream copy without re-encoding video or audio frames.
  - Slices at nearest keyframe (I-frame).
  - Preserves original resolution and audio sync using `-avoid_negative_ts make_zero`.
  - Available only when keeping original aspect ratio without overlays.
- **Precise Mode (`libx264`):**
  - Frame-accurate cuts landing on exact millisecond timestamps.
  - Required for canvas transformations (9:16 blur, crop, solid padding) and text overlay badges.
  - Encoded with `libx264` (`preset=faster`, `crf=22`) and `aac` audio (`192k`).

---

## 9. Destination Storage & Duplicate Handling

- **Destination Picker:** User chooses persistent destination via Android Storage Access Framework (SAF).
- **Duplicate File Handling:**
  - **Overwrite (Default):** Replaces existing file with identical name.
  - **Auto-suffix:** Appends `_1`, `_2` before the extension (e.g. `video_part_001_1.mp4`).

---

## 10. Project History & Activity Metrics

- **Persistence:** Metadata stored locally via `HistoryRepository` backed by `SharedPreferences`.
- **Metrics Calculated:** Total videos processed, total shorts created, cumulative runtime, and disk space occupied.
- **Search & Multi-Delete:** Real-time search by filename, long-press multi-select deletion, and single-item swipe dismissal with undo SnackBar.

---

## 11. YouTube Shorts Platform Specifications

> ⚠️ **Verification Notice:** Verify current platform policy directly on [YouTube Help](https://support.google.com/youtube/answer/10059070).

As of YouTube's official platform update:
- **Maximum Duration:** YouTube Shorts supports videos up to **3 minutes (180 seconds)** in duration.
- **Aspect Ratio:** Must be vertical (`9:16`) or square (`1:1`). Horizontal videos (`16:9`) are uploaded as standard long-form videos regardless of duration.
- **Audio & Copyright:** Commercial music tracks from the YouTube Shorts sound library may carry 60-second usage limits; speech and original audio support full 3-minute clips.

---

## 12. Centralized Validation Architecture & Platform Invariants

ShortsSplitter employs a centralized, pure-domain validation architecture to ensure robust input handling across all creation tools and prevent runtime failures.

### Architecture Components
- **`ValidationResult` & `ValidationIssue`:** Immutable domain value objects categorizing problems by severity (`error`, `warning`, `info`, `success`), associated input `fieldId`, error code, user-friendly message, and optional action labels (e.g., "Choose Folder", "Open Settings").
- **Pure Domain Validators:** Completely decoupled from the Flutter UI layer, allowing 100% test coverage with zero mock requirements:
  - `SelectVideoValidator`: Validates video presence, non-zero file size, non-zero duration, and supported container formats (`.mp4`, `.mov`, `.mkv`, `.webm`, `.avi`, `.flv`, `.3gp`, `.m4v`).
  - `TrimValidator`: Enforces $0 \le \text{start} < \text{end} \le \text{duration}$ and a minimum trim range of 1.0 second.
  - `SplitSettingsValidator`: Enforces the 180s platform ceiling in Shorts mode, minimum 1.0s clip length, and a 500-part sanity cap.
  - `BackgroundValidator`: Validates ARGB color ranges and ensures custom background image files exist on disk.
  - `OverlayValidator`: Enforces non-empty template text and verifies watermark logo assets exist.
  - `AudioValidator`: Ensures audio files exist and verifies Android microphone permissions before voice-over recording.
  - `OutputLocationValidator`: Verifies write permissions, folder existence, and SAF tree URI persistable permissions.
  - `ExportPreflightValidator`: Checks available storage against $1.5\times$ estimated transcode requirement and blocks duplicate concurrent jobs.
  - `CustomSplitValidator`: Ensures cut points are within duration, non-duplicate, strictly ascending, and spaced $\ge 1.0\text{s}$ apart.
- **Action Button Invariant:** Primary action buttons remain tappable. On tap, validation runs:
  1. Shows the first problem as an accessible toast/snackbar via `AppMessenger`.
  2. Renders an inline error message on the offending field.
  3. Scrolls the viewport directly to the error field.
  4. Blocks navigation or export dispatch.

---

## 13. Interactive Trim Timeline & Mathematical Coordinate Mapper

The **Interactive Trim Timeline** (`InteractiveTrimTimeline`) is a custom-painted timeline engineered for sub-second precision trimming.

### Invariants & Specifications
- **Pure Coordinate Mapper (`TimelineMapper`):** Converts integer milliseconds $\leftrightarrow$ pixel $X$-coordinates with zero floating-point accumulation drift:
  - Clamps start handle to $[0, \text{endMs} - 1000\text{ms}]$.
  - Clamps end handle to $[\text{startMs} + 1000\text{ms}, \text{totalDurationMs}]$.
  - Enforces strict 48dp touch targets for accessibility (WCAG AA).
- **Clipped Playhead Invariant:** The playhead indicator is strictly clipped within the track rounded rectangle (`RRect`), guaranteeing it can never render outside the timeline borders.
- **Selection Playback Boundaries:** In "Play selection" mode, playback is clamped strictly within $[\text{startMs}, \text{endMs}]$ and auto-stops upon reaching the end cut point.
- **Throttled Scrubbing:** Position updates during drag gestures are throttled to 40ms to prevent player pipeline starvation while maintaining fluid 60fps UI rendering.

---

## 14. Selective Clip Processing & High-Performance Engine

Users can selectively process any subset of planned clips (e.g. 3 of 30 clips) without re-encoding the entire video.

### Invariants & Specifications
- **Strict Plan-Index Naming:** Output filenames strictly preserve plan indexing `{originalName}_part_{NNN}.mp4`, where `NNN` is zero-padded to `max(3, digits(totalClips))` based on the full plan. Unselected clips are never renumbered.
- **Part Lifecycle State Machine:**
  - `notProcessed`: Clip has not been transcoded yet.
  - `processing`: Clip is currently being transcoded.
  - `processed`: Clip finished successfully and output file exists on disk.
  - `failed`: Clip failed transcoding and displays inline "Retry" button.
  - `stale`: Modifying boundaries or overlay messages marks affected clips as stale.
  - `missing`: Output file was deleted externally; prompts re-processing.
- **Selection Action Bar:** Provides quick actions ("Select All", "Deselect", "Invert") and live count badge ("X of Y selected").
- **Partial History Badges:** Projects with partial exports display a "X/Y processed" badge and progress bar in History and Dashboard.
- **Single-Pass Segment Muxer:** When full stream-copy is selected, FFmpeg executes all cuts in a single pass at 2,926x realtime.
- **Downscaled Background Blur:** Input frames are scaled to 10% resolution ($108\times 192$), blurred, and upscaled bicubic, achieving a 4.3x desktop / >15x mobile speedup.
- **Hardware Acceleration:** Native `h264_mediacodec` on Android devices with software `libx264 ultrafast` fallback.

---

## 15. Two-Stage Workflow, Embedded SQLite & Output Folder Architecture

Designed for scaling seamlessly from 15-second clips to 2-hour longform videos.

### Two-Stage Workflow Architecture
- **Automatic Recommendation:** Videos longer than 20 minutes or generating more than 20 parts trigger the `WorkflowChoiceDialog`, recommending "Split first, convert later".
- **Stage 1 (Fast Stream-Copy Split):** Executes a single-pass stream copy (`-c copy`) segment split at speeds up to 3,000x realtime. Raw parts become immediately visible and playable in history. Keyframe snapping is probed, recording actual cut timestamps and flagging any part exceeding 180s with `>3:00 Cap`.
- **Stage 2 (Targeted Shorts Conversion):** Users select desired parts from the parts review screen and transcode only those parts into 9:16 Shorts with canvas scaling, background fill/blur, and labels.
- **Safe In-Place Replacement (`SafeClipReplacer`):** Staged temp file write (`.tmp.mp4`) beside original $\to$ integrity verification $\to$ atomic delete of raw file and rename of staged file to final name. On any error, original raw split file is preserved without corruption. Supports "Keep both" (`..._short.mp4`) or "Replace".

### Output Folder Layout (`FolderLayoutResolver`)
- **Multi-Part Projects ($\ge 2$ parts):** Automatically grouped into a sanitized, collision-safe subfolder: `<saveLocation>/<SourceName>/<SourceName>_part_001.mp4`.
- **Single-Part Projects ($= 1$ part):** Saved directly into root destination without creating redundant wrapper folders: `<saveLocation>/<SourceName>.mp4`.

### Reactive SQLite Persistence (Drift)
- Structured SQLite database replaces SharedPreferences for history, projects, and parts.
- Automated, non-destructive migration (`LegacyMigration`) copies all existing SharedPreferences history to SQLite on first launch while retaining raw data backups.
- Compound performance indexes and foreign keys with cascade deletion.
- Real-time SQL aggregation for dashboard statistics (`DashboardStatsRepository`).



