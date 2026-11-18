# Test Case Catalogue & Traceability Matrix

## Taxonomy & Structure
Test cases in ShortsSplitter follow the deterministic numbering convention: `TC-<AREA>-<NNN>`
- `TC-FOUNDATION-<NNN>`: Architecture foundation, job queue, FFmpeg builders, fixtures, output verifiers.
- `TC-SPLIT-<NNN>`: Shorts Maker (3m cap, contiguity, 9:16 canvas, remainder merge, part messages).
- `TC-CUSTOM-<NNN>`: Custom Split (by duration, parts, custom points, no duration cap).
- `TC-EDIT-<NNN>`: Non-destructive Studio Editor (crop, rotate, speed, color eq, overlays, fades, reverse).
- `TC-CONV-<NNN>`: Transcoder (MP4, WebM, MKV, GIF palettegen, quality & compression presets).
- `TC-AUDIO-<NNN>`: Audio Studio (mute, voiceover, replace track, mix volumes, waveform trim).
- `TC-SHOT-<NNN>`: Frame Grabber (playhead grab, timestamp list, interval extraction).
- `TC-MERGE-<NNN>`: Multi-video Joiner (join 2+ clips, canvas normalization, crossfades).

---

## Phase 1: Foundation Test Cases

### TC-FOUNDATION-001: Application Identity & APK Naming
- **Area:** Build Configuration & Branding
- **Preconditions:** Host system with Flutter 3.47.5 and Gradle.
- **Procedure:** Run `./scripts/build_apk.sh --release` or verify Gradle `applicationVariants.all`.
- **Expected Result:** App name in `AndroidManifest.xml` references `@string/app_name` ("ShortsSplitter"). Generated APK matches `ShortsSplitter-<version>+<build>-release[-<abi>].apk`.
- **Automated Test:** Gradle build configuration inspection.
- **Traceability:** `android/app/build.gradle.kts`, `android/app/src/main/res/values/strings.xml`, `android/app/src/main/AndroidManifest.xml`.

### TC-FOUNDATION-002: Vector Branding & Icon Generation
- **Area:** Visual Assets
- **Preconditions:** ImageMagick / Inkscape or `scripts/gen_icons.sh`.
- **Procedure:** Execute `./scripts/gen_icons.sh`.
- **Expected Result:** Generates adaptive mipmap densities (mdpi through xxxhdpi), monochrome icon, notification drawable (`ic_notification.png`), and Play Store assets (512x512 icon, 1024x500 feature graphic).
- **Traceability:** `assets/branding/app_icon.svg`, `scripts/gen_icons.sh`, `scripts/gen_icons.ps1`.

### TC-FOUNDATION-003: Sequential JobQueueController & Crash Recovery
- **Area:** Jobs & State Management
- **Preconditions:** Riverpod test container with mocked `SharedPreferences`.
- **Procedure:** Queue multiple jobs across distinct tools; simulate app killed during execution.
- **Expected Result:** Strictly one job executes concurrently. Interrupted jobs are recovered on startup as failed/recoverable. Disposing screens does not abort jobs.
- **Automated Test:** `test/features/jobs/job_queue_controller_test.dart`.
- **Traceability:** `lib/features/jobs/domain/job_queue_controller.dart`, `lib/features/jobs/domain/models/job_record.dart`.

### TC-FOUNDATION-004: Video Transformation Filter Graph Compilation
- **Area:** Media Processing Domain
- **Preconditions:** Valid canvas dimensions and transformation parameters.
- **Procedure:** Invoke `FilterGraphBuilder.buildVideoFilterChain` with crop, rotate, flip, speed, color eq, and fades.
- **Expected Result:** Output string compiles correct FFmpeg filters (`crop`, `transpose`, `hflip`, `vflip`, `setpts`, `eq`, `fade`, `reverse`) in valid syntax. Returns `null` when no filters apply.
- **Automated Test:** `test/features/processing/filter_graph_builder_test.dart` (TC 7 & 8).
- **Traceability:** `lib/features/processing/domain/filter_graph_builder.dart`.

### TC-FOUNDATION-005: Audio Filter Compilation & Pitch-Preserving Atempo Chains
- **Area:** Audio Processing Domain
- **Preconditions:** Pure Dart domain environment.
- **Procedure:** Call `AudioGraphBuilder.buildAtempoChain` with values `< 0.5`, `0.5..2.0`, and `> 2.0`. Call `buildAudioFilters` and `buildAudioMixFilterComplex`.
- **Expected Result:** Fast speeds (> 2.0x) and slow speeds (< 0.5x) are correctly cascaded into chains of valid `atempo` filters (each bounded within [0.5, 2.0]). Audio mixing generates correct two-channel `amix`.
- **Automated Test:** `test/features/processing/audio_graph_builder_test.dart`.
- **Traceability:** `lib/features/processing/domain/audio_graph_builder.dart`.

### TC-FOUNDATION-006: Deterministic Media Fixture Generation
- **Area:** Testing Infrastructure
- **Preconditions:** Static `ffmpeg` v7.0+ on system PATH.
- **Procedure:** Run `./scripts/make_fixtures.sh` (or `.\scripts\make_fixtures.ps1`).
- **Expected Result:** Produces 8 standard test fixtures in `test/fixtures/` (`test_16_9.mp4`, `test_9_16.mp4`, `test_rotated.mp4`, `test_silent.mp4`, `test_vfr.mp4`, `test_70s.mp4`, `test_logo.png`, `test_audio.mp3`).
- **Traceability:** `scripts/make_fixtures.sh`, `scripts/make_fixtures.ps1`, `test/fixtures/`.

### TC-FOUNDATION-007: Headless OutputVerifier Stream & Pixel Inspection
- **Area:** Testing Infrastructure
- **Preconditions:** Generated test fixtures on disk.
- **Procedure:** Probe media stream metadata with `OutputVerifier.probe` and extract pixel colors via `OutputVerifier.extractPixelColor`.
- **Expected Result:** Resolves exact duration, width, height, FPS, audio sample rate, channels, rotation matrix, and pixel RGB values within tolerance.
- **Automated Test:** `test/utils/output_verifier_test.dart`.
- **Traceability:** `test/utils/output_verifier.dart`.

### TC-FOUNDATION-008: 5-Tab Adaptive Navigation Shell & Studio Grid
- **Area:** Presentation & Shell
- **Preconditions:** Flutter widget test environment.
- **Procedure:** Mount app shell at compact and expanded widths; tap through Home, Create, Jobs, History, Settings.
- **Expected Result:** NavigationBar (mobile) and NavigationRail (tablet) correctly display 5 destinations. Studio Tools Grid on Home displays 7 creative tools and navigates to proper routes.
- **Automated Test:** `test/features/home/presentation/screens/dashboard_screen_test.dart` / widget tests.
- **Traceability:** `lib/shared/widgets/app_scaffold.dart`, `lib/app/router.dart`, `lib/features/home/presentation/widgets/studio_tools_grid.dart`.

---

## Phase 2: Custom Split Tool Test Cases

### TC-CUSTOM-001: Custom Split by Duration (No 180s Cap)
- **Area:** Custom Split Domain
- **Preconditions:** Source video with duration > 180s (e.g. 700s).
- **Procedure:** Configure split with `CustomSplitMode.byDuration` and target duration 300s.
- **Expected Result:** Produces contiguous clips exceeding 180s without throwing `PlanValidationException`.
- **Automated Test:** `test/features/custom_split/custom_split_calculator_test.dart`.
- **Traceability:** `lib/features/custom_split/domain/custom_split_calculator.dart`.

### TC-CUSTOM-002: Trailing Remainder Absorption Rule (< 3.0s)
- **Area:** Custom Split Domain
- **Preconditions:** Source range with trailing remainder < 3.0s.
- **Procedure:** Calculate plan with `mergeShortTrailingClip: true` and `trailingMergeThresholdSeconds: 3.0`.
- **Expected Result:** Trailing remainder is absorbed into penultimate clip. When toggle is disabled, remainder clip remains independent.
- **Automated Test:** `test/features/custom_split/custom_split_calculator_test.dart`.
- **Traceability:** `lib/features/custom_split/domain/custom_split_calculator.dart`.

### TC-CUSTOM-003: Equal Parts Segmentation (2 <= N <= 50)
- **Area:** Custom Split Domain
- **Preconditions:** Active trim range $[T_{start}, T_{end}]$.
- **Procedure:** Calculate plan with `CustomSplitMode.byParts` for $N \in [2, 50]$.
- **Expected Result:** Divides duration into $N$ equal parts with perfect contiguity: $e_k == s_{k+1}$ and $e_{N-1} == T_{end}$.
- **Automated Test:** `test/features/custom_split/custom_split_calculator_test.dart`.
- **Traceability:** `lib/features/custom_split/domain/custom_split_calculator.dart`.

### TC-CUSTOM-004: Arbitrary Custom Split Points
- **Area:** Custom Split Domain
- **Preconditions:** User-supplied split point timestamps $[p_1, p_2, \dots]$.
- **Procedure:** Provide unsorted points including points outside bounds.
- **Expected Result:** Points are filtered to $(T_{start}, T_{end})$, sorted ascending, and clips formed between adjacent boundaries.
- **Automated Test:** `test/features/custom_split/custom_split_calculator_test.dart`.
- **Traceability:** `lib/features/custom_split/domain/custom_split_calculator.dart`.

### TC-CUSTOM-005: File Size Estimation Mode
- **Area:** Custom Split Domain
- **Preconditions:** Target file size in MB and video bitrate.
- **Procedure:** Calculate plan with `CustomSplitMode.bySize`.
- **Expected Result:** Computes duration per clip: $\text{duration} = (\text{targetBytes} \times 8) / \text{bitrate}$.
- **Automated Test:** `test/features/custom_split/custom_split_calculator_test.dart`.
- **Traceability:** `lib/features/custom_split/domain/custom_split_calculator.dart`.

### TC-CUSTOM-006: Fast Stream-Copy vs Precise Re-encode Execution
- **Area:** Media Processing Integration
- **Preconditions:** Test fixture `test_70s.mp4`.
- **Procedure:** Execute fast stream-copy (`-c copy`) and precise re-encode (`libx264/aac`). Probe outputs with `OutputVerifier`.
- **Expected Result:** Fast cut completes instantaneously with matching stream properties; precise cut matches target durations and codecs.
- **Automated Test:** `test/features/custom_split/custom_split_integration_test.dart`.
- **Traceability:** `lib/features/processing/data/ffmpeg_video_processor.dart`.

### TC-CUSTOM-007: Interactive Clip Operations (Adjust, Merge, Split)
- **Area:** Custom Split Domain
- **Preconditions:** Active `CustomClipPlan`.
- **Procedure:** Invoke `adjustBoundary`, `mergeWithNext`, and `splitClip`.
- **Expected Result:** Correctly shifts boundary between adjacent clips, merges neighboring parts, and splits clip in two with updated zero-padded names.
- **Automated Test:** `test/features/custom_split/custom_split_calculator_test.dart`.
- **Traceability:** `lib/features/custom_split/domain/custom_split_calculator.dart`.

### TC-CUSTOM-008: Custom Split UI Flow & Plan Review Integration
- **Area:** Presentation
- **Preconditions:** Flutter widget test environment.
- **Procedure:** Render `CustomSplitScreen` and `CustomSplitPlanReviewScreen`; verify state updates and job enqueueing into `JobQueueController`.
- **Expected Result:** UI renders all 4 mode options, plan summary updates dynamically, and "Start Split" enqueues job into background queue.
- **Automated Test:** `test/features/custom_split/custom_split_screen_test.dart`, `custom_split_controller_test.dart`.
- **Traceability:** `lib/features/custom_split/presentation/screens/custom_split_screen.dart`, `custom_split_plan_review_screen.dart`.

---

## Phase 3: Studio Video Editor Test Cases

### TC-EDIT-001: Non-Destructive EditProject Domain Model & Serialization
- **Area:** Editor Domain
- **Preconditions:** Pure Dart environment.
- **Procedure:** Instantiate `EditProject` with nested transform, canvas, speed, color, fades, watermark, and text specs; serialize to JSON and restore via `fromJson`.
- **Expected Result:** Round-trip JSON preserves 100% of project properties with zero data loss.
- **Automated Test:** `test/features/editor/edit_project_test.dart`.
- **Traceability:** `lib/features/editor/domain/models/edit_project.dart`.

### TC-EDIT-002: Reverse Playback Memory Safety Invariant (<= 15.0s)
- **Area:** Editor Domain Invariants
- **Preconditions:** `EditProject` with duration > 15.0s.
- **Procedure:** Attempt to enable `reverse: true` and validate project.
- **Expected Result:** Throws `PlanValidationException` when duration exceeds 15.0s; passes when duration $\le 15.0\text{s}$.
- **Automated Test:** `test/features/editor/edit_project_test.dart`.
- **Traceability:** `lib/features/editor/domain/models/edit_project.dart`.

### TC-EDIT-003: 1-Pass Complex Filter Compilation (Trim, Crop, Rotate, Flips)
- **Area:** Video Transformation Compiler
- **Preconditions:** Configured `EditProject`.
- **Procedure:** Call `EditorFilterCompiler.compileExport`.
- **Expected Result:** Assembles input trimming (`-ss`, `-t`), rotation (`transpose`), flips (`hflip`/`vflip`), and canvas scaling into a single-pass filter complex.
- **Automated Test:** `test/features/editor/editor_filter_compiler_test.dart`.
- **Traceability:** `lib/features/editor/domain/editor_filter_compiler.dart`.

### TC-EDIT-004: Pitch-Preserving Speed Scaling (0.25x - 4.0x via Atempo)
- **Area:** Media Processing Integration
- **Preconditions:** Source video fixture `test_16_9.mp4`.
- **Procedure:** Compile and execute 1.5x speed transcode with `preservePitch: true`. Probe output with `OutputVerifier`.
- **Expected Result:** Output video duration scales inversely with speed ($D / S$) while preserving pitch without distortion.
- **Automated Test:** `test/features/editor/editor_integration_test.dart`.
- **Traceability:** `lib/features/editor/domain/editor_filter_compiler.dart`, `lib/features/processing/domain/audio_graph_builder.dart`.

### TC-EDIT-005: Color Correction & Grading Presets
- **Area:** Video Filters
- **Preconditions:** Configured color adjustments (brightness, contrast, saturation, and presets).
- **Procedure:** Compile export command and verify generated `eq` filter values.
- **Expected Result:** Generates correct `eq=brightness=B:contrast=C:saturation=S` arguments for Vibrant, Cinematic, Vintage, and B&W presets.
- **Automated Test:** `test/features/editor/editor_filter_compiler_test.dart`.
- **Traceability:** `lib/features/editor/domain/editor_filter_compiler.dart`.

### TC-EDIT-006: Watermark & Text Overlay Placement
- **Area:** Media Processing Integration
- **Preconditions:** Input video `test_16_9.mp4` and watermark `test_logo.png`.
- **Procedure:** Execute 1-pass export with watermark and text badge; probe output with `OutputVerifier`.
- **Expected Result:** FFmpeg overlays the scaled watermark at the target position (e.g. top-right) and renders text badge with transparency.
- **Automated Test:** `test/features/editor/editor_integration_test.dart`.
- **Traceability:** `lib/features/editor/domain/editor_filter_compiler.dart`, `lib/features/processing/data/overlay_renderer.dart`.

### TC-EDIT-007: Rapid 5-Second Quick Preview Generation
- **Area:** Presentation & Processing
- **Preconditions:** Active `EditProject`.
- **Procedure:** Call `controller.generatePreview()` / `processor.generateEditPreview(...)`.
- **Expected Result:** Generates a rapid preview clip using the ultrafast preset capped at 5.0 seconds.
- **Automated Test:** `test/features/editor/editor_controller_test.dart`, `editor_filter_compiler_test.dart`.
- **Traceability:** `lib/features/editor/domain/editor_filter_compiler.dart`, `lib/features/processing/data/ffmpeg_video_processor.dart`.

### TC-EDIT-008: Studio Editor UI Dock & Background Queue Dispatch
- **Area:** Presentation & Queue Integration
- **Preconditions:** Flutter widget test environment.
- **Procedure:** Mount `EditorScreen`, interact with tool dock chips (Trim, Canvas, Speed, Color, Overlay, Effects), and tap "Export Studio Video".
- **Expected Result:** UI renders all tool docks, sliders and chips respond cleanly, and export enqueues job into `JobQueueController`.
- **Automated Test:** `test/features/editor/editor_screen_test.dart`, `editor_controller_test.dart`.
- **Traceability:** `lib/features/editor/presentation/screens/editor_screen.dart`, `editor_controller.dart`.

---

## Phase 4: Format Convert & Compression Test Cases

### TC-CONV-001: MP4 H.264 & H.265 (HEVC) Transcoding
- **Area:** Video Transcoding Domain
- **Preconditions:** Source video input path.
- **Procedure:** Compile and execute conversion to MP4 H.264 and MP4 H.265.
- **Expected Result:** H.264 uses `libx264`, `yuv420p`, and `+faststart`. H.265 includes `libx265`, `-tag:v hvc1` for Apple/Android compatibility, and audio in AAC. Output verified via `OutputVerifier`.
- **Automated Test:** `test/features/convert/convert_filter_compiler_test.dart`, `convert_integration_test.dart`.
- **Traceability:** `lib/features/convert/domain/convert_filter_compiler.dart`, `lib/features/processing/data/ffmpeg_video_processor.dart`.

### TC-CONV-002: WebM (VP9 + Opus) Transcoding
- **Area:** Video Transcoding Domain
- **Preconditions:** Source video input path.
- **Procedure:** Compile and verify WebM conversion commands.
- **Expected Result:** Uses `libvpx-vp9` with `-b:v 0` for constant quality or calculated bitrate, paired with `libopus` audio.
- **Automated Test:** `test/features/convert/convert_filter_compiler_test.dart`.
- **Traceability:** `lib/features/convert/domain/convert_filter_compiler.dart`.

### TC-CONV-003: Aspect-Preserving Video Downscaling & FPS Clamping
- **Area:** Media Processing Domain
- **Preconditions:** Source video dimensions (e.g., 1080p, 4K).
- **Procedure:** Select resolution preset (e.g. 720p HD) and FPS cap (e.g. 30 FPS).
- **Expected Result:** Compiles `scale='if(gt(iw,ih),min(iw,MAX),-2)':'if(gt(iw,ih),-2,min(ih,MAX))'` guaranteeing even dimensions and aspect preservation without distortion or black borders. Clamps FPS via `fps=N`.
- **Automated Test:** `test/features/convert/convert_filter_compiler_test.dart`, `convert_integration_test.dart`.
- **Traceability:** `lib/features/convert/domain/convert_filter_compiler.dart`.

### TC-CONV-004: Target Size Mode (Constrained VBR for Discord & WhatsApp)
- **Area:** Compression Domain
- **Preconditions:** Video duration and target size in megabytes (e.g., 16MB for WhatsApp, 25MB for Discord).
- **Procedure:** Compute required video bitrate: `(targetBytes * 8 * 0.98 - audioBits) / duration`.
- **Expected Result:** Bitrate calculated with 2% container overhead; passes `-b:v`, `-maxrate`, and `-bufsize` to constrain output under the target size.
- **Automated Test:** `test/features/convert/convert_filter_compiler_test.dart`, `convert_config_test.dart`.
- **Traceability:** `lib/features/convert/domain/convert_filter_compiler.dart`, `models/convert_config.dart`.

### TC-CONV-005: Animated GIF Generation with 2-Pass Palettegen
- **Area:** GIF Processing Domain
- **Preconditions:** Source video fixture `test_16_9.mp4`.
- **Procedure:** Convert to Animated GIF with max width 480px and 15 FPS.
- **Expected Result:** Uses single-pass `-filter_complex` executing `fps`, `scale`, `split`, `palettegen`, and `paletteuse=dither=bayer` with `-an`. Output verified as valid GIF with width 480 and zero audio.
- **Automated Test:** `test/features/convert/convert_integration_test.dart`, `convert_filter_compiler_test.dart`.
- **Traceability:** `lib/features/convert/domain/convert_filter_compiler.dart`.

### TC-CONV-006: High-Fidelity Audio Extraction (MP3, WAV, AAC, Opus)
- **Area:** Audio Processing Domain
- **Preconditions:** Source video with audio track.
- **Procedure:** Select Audio Only format across MP3, WAV, AAC, and Opus.
- **Expected Result:** Passes `-vn` to strip video; uses target audio codec (`libmp3lame`, `pcm_s16le`, `aac`, `libopus`) and user-selected bitrate. Output verified via `OutputVerifier`.
- **Automated Test:** `test/features/convert/convert_integration_test.dart`, `convert_filter_compiler_test.dart`.
- **Traceability:** `lib/features/convert/domain/convert_filter_compiler.dart`.

### TC-CONV-007: Output Size Estimator & Bitrate Heuristics
- **Area:** Domain Modeling
- **Preconditions:** Source metadata (duration, width, height, size) and `ConvertConfig`.
- **Procedure:** Call `ConvertConfig.estimateOutputSizeBytes()`.
- **Expected Result:** Accurately estimates output size based on target MB, audio-only bitrate, GIF palette frames, or resolution/CRF/FPS matrix with HEVC/VP9 savings.
- **Automated Test:** `test/features/convert/convert_config_test.dart`, `convert_controller_test.dart`.
- **Traceability:** `lib/features/convert/domain/models/convert_config.dart`.

### TC-CONV-008: Convert & Compress UI, Presets, and Queue Integration
- **Area:** Presentation & Queue Integration
- **Preconditions:** Flutter widget test environment.
- **Procedure:** Mount `ConvertScreen`, toggle formats (MP4, GIF, Audio), test preset chips, and enqueue conversion.
- **Expected Result:** UI renders dynamically for each format type, updates size estimate, and dispatches job into `JobQueueController`.
- **Automated Test:** `test/features/convert/convert_screen_test.dart`, `convert_controller_test.dart`.
- **Traceability:** `lib/features/convert/presentation/screens/convert_screen.dart`, `convert_controller.dart`.

---

## Phase 5: Audio Studio Test Cases

### TC-AUDIO-001: Original Audio Volume Scaling & Full Muting
- **Area:** Audio Studio Domain & Transcoding
- **Preconditions:** Video input fixture with audio track.
- **Procedure:** Configure `AudioStudioConfig` with `muteOriginal: true` or `originalVolume: 0.5`.
- **Expected Result:** Compiles `-an` or `volume=0.5` in filter graph; when muted, completely strips or ignores original stream. Output audio verified via `OutputVerifier`.
- **Automated Test:** `test/features/audio_studio/audio_studio_compiler_test.dart`, `audio_studio_integration_test.dart`.
- **Traceability:** `lib/features/audio_studio/domain/audio_studio_compiler.dart`, `lib/features/processing/data/ffmpeg_video_processor.dart`.

### TC-AUDIO-002: Background Music Replacement & Looping
- **Area:** Audio Studio Domain
- **Preconditions:** Video fixture and background audio track (`test_audio.mp3`).
- **Procedure:** Configure background music track with `loop: true` and `muteOriginal: true`.
- **Expected Result:** Compiles `-stream_loop -1 -i <musicPath>` and maps music track directly to `[aout]` with `-c:v copy` and `-shortest` matching video length.
- **Automated Test:** `test/features/audio_studio/audio_studio_compiler_test.dart`, `audio_studio_integration_test.dart`.
- **Traceability:** `lib/features/audio_studio/domain/audio_studio_compiler.dart`.

### TC-AUDIO-003: Multi-Track Audio Mixing (Original + Music + Voice-over)
- **Area:** Audio Studio Domain & Processing
- **Preconditions:** Source video, background music file, and voice-over audio file.
- **Procedure:** Mix three audio streams simultaneously with independent volume multipliers via `amix=inputs=3:duration=first:dropout_transition=2`.
- **Expected Result:** Normalizes inputs via `aresample=44100`, applies individual volume filters, and produces a single unified `[aout]` without clipping or audio drift.
- **Automated Test:** `test/features/audio_studio/audio_studio_compiler_test.dart`, `audio_studio_integration_test.dart`.
- **Traceability:** `lib/features/audio_studio/domain/audio_studio_compiler.dart`.

### TC-AUDIO-004: Smart Sidechain Audio Ducking
- **Area:** Audio Studio Processing Domain
- **Preconditions:** Background music track and voice-over narration track.
- **Procedure:** Enable `autoDucking: true` in `AudioStudioConfig`.
- **Expected Result:** Injects `[a_music][a_voice] sidechaincompress=threshold=0.08:ratio=5:attack=50:release=300 [ducked_music]` filter chain, automatically suppressing background music whenever voice-over activity is detected.
- **Automated Test:** `test/features/audio_studio/audio_studio_compiler_test.dart`, `audio_studio_integration_test.dart`.
- **Traceability:** `lib/features/audio_studio/domain/audio_studio_compiler.dart`.

### TC-AUDIO-005: Timeline Offset & Audio Delay (`adelay`)
- **Area:** Audio Processing Domain
- **Preconditions:** Audio track with `startTimeSeconds > 0`.
- **Procedure:** Compile audio track with delay offset (e.g. 2.5s).
- **Expected Result:** Calculates delay in milliseconds (`2500|2500`) and applies `adelay=2500|2500` filter so track starts at exact timeline position.
- **Automated Test:** `test/features/audio_studio/audio_studio_compiler_test.dart`.
- **Traceability:** `lib/features/audio_studio/domain/audio_studio_compiler.dart`.

### TC-AUDIO-006: Standalone Audio Extraction (MP3, WAV, AAC, Opus)
- **Area:** Audio Studio Transcoding Domain
- **Preconditions:** Video and background music tracks configured with `exportMode: AudioStudioExportMode.audioOnly`.
- **Procedure:** Compile and transcode mixed audio into standalone MP3 audio file.
- **Expected Result:** Passes `-vn` to discard video stream, encodes mixed audio to selected format (`libmp3lame`, `192k`), verified as valid audio file via `OutputVerifier`.
- **Automated Test:** `test/features/audio_studio/audio_studio_integration_test.dart`, `audio_studio_compiler_test.dart`.
- **Traceability:** `lib/features/audio_studio/domain/audio_studio_compiler.dart`.

### TC-AUDIO-007: Microphone Voice-over Recording Lifecycle
- **Area:** Platform Integration & Audio Recording
- **Preconditions:** Android microphone permission granted (`RECORD_AUDIO`).
- **Procedure:** Start recording voice-over via `AudioRecorderBridge`, record audio, stop recording, and verify output AAC file path and duration.
- **Expected Result:** `AudioRecorderBridge.kt` configures `MediaRecorder` with `AudioSource.MIC`, `OutputFormat.MPEG_4`, and `AudioEncoder.AAC` at 44.1kHz / 192kbps. Headless fallback returns mock path.
- **Automated Test:** `test/features/audio_studio/audio_studio_controller_test.dart`.
- **Traceability:** `android/.../AudioRecorderBridge.kt`, `lib/features/audio_studio/data/audio_recording_service.dart`.

### TC-AUDIO-008: Audio Studio UI, Timeline Mixer, and Unified Queue Integration
- **Area:** Presentation & Queue Integration
- **Preconditions:** Flutter widget test environment.
- **Procedure:** Mount `AudioStudioScreen`, inspect timeline level bars, mute toggle, volume sliders, ducking switch, and tap "Export Mixed Video".
- **Expected Result:** UI renders track cards, interacts with volume and ducking controls, and enqueues `JobType.audioStudio` into `JobQueueController`.
- **Automated Test:** `test/features/audio_studio/audio_studio_screen_test.dart`, `audio_studio_controller_test.dart`.
- **Traceability:** `lib/features/audio_studio/presentation/screens/audio_studio_screen.dart`, `audio_studio_controller.dart`.

---

## Phase 6: Screenshot Capture Test Cases

### TC-SHOT-001: Instant Playhead Frame Extraction (Lossless PNG)
- **Area:** Video Frame Extraction Domain
- **Preconditions:** Video input fixture `test_16_9.mp4`.
- **Procedure:** Execute `ScreenshotCompiler.buildCaptureArgs` for PNG at 1.5s with `-frames:v 1 -update 1`.
- **Expected Result:** Extracts crisp full-resolution frame matching video dimensions ($1920\times 1080$), encoded with `png` codec. Verified via `OutputVerifier.probe`.
- **Automated Test:** `test/features/screenshot/screenshot_integration_test.dart`, `screenshot_compiler_test.dart`.
- **Traceability:** `lib/features/screenshot/domain/screenshot_compiler.dart`, `lib/features/processing/data/ffmpeg_video_processor.dart`.

### TC-SHOT-002: High-Quality Compressed JPEG Frame Extraction with Quality Scale
- **Area:** Image Processing Domain
- **Preconditions:** Video input fixture `test_16_9.mp4`.
- **Procedure:** Execute frame extraction at 3.0s specifying JPEG format and quality 85%.
- **Expected Result:** Passes `-q:v 4` (mapped from 85%), creating valid JPEG image at $1920\times 1080$. Verified via `OutputVerifier.probe`.
- **Automated Test:** `test/features/screenshot/screenshot_integration_test.dart`, `screenshot_compiler_test.dart`.
- **Traceability:** `lib/features/screenshot/domain/screenshot_compiler.dart`.

### TC-SHOT-003: Custom Timestamp List Filtering & Frame Capture
- **Area:** Domain Modeling & Planning
- **Preconditions:** User-defined timestamp list with out-of-range and duplicate entries.
- **Procedure:** Call `ScreenshotConfig.calculatePlannedTimestamps()` with range $[10.0, 40.0]$.
- **Expected Result:** Clamps and filters timestamps within range, sorts ascending, and generates zero-padded filenames e.g. `{base}_frame_01_00m12s300ms.png`.
- **Automated Test:** `test/features/screenshot/screenshot_config_test.dart`, `screenshot_controller_test.dart`.
- **Traceability:** `lib/features/screenshot/domain/models/screenshot_config.dart`.

### TC-SHOT-004: Periodic Interval Extraction (Every X Seconds)
- **Area:** Mathematical Planning Domain
- **Preconditions:** `ScreenshotConfig` with `intervalType: IntervalType.byDuration` and `intervalSeconds: 10.0`.
- **Procedure:** Calculate planned items across $[0.0, 30.0]$.
- **Expected Result:** Returns 4 distinct evenly spaced timestamp points ($0.0, 10.0, 20.0, 30.0$).
- **Automated Test:** `test/features/screenshot/screenshot_config_test.dart`.
- **Traceability:** `lib/features/screenshot/domain/models/screenshot_config.dart`.

### TC-SHOT-005: Equal Frame Count Segmentation across Trim Range
- **Area:** Mathematical Planning Domain
- **Preconditions:** `ScreenshotConfig` with `intervalType: IntervalType.byCount` and `frameCount: 5`.
- **Procedure:** Calculate planned items across $[0.0, 40.0]$.
- **Expected Result:** Computes step $\Delta t = 10.0\text{s}$ yielding exact timestamps $[0.0, 10.0, 20.0, 30.0, 40.0]$.
- **Automated Test:** `test/features/screenshot/screenshot_config_test.dart`.
- **Traceability:** `lib/features/screenshot/domain/models/screenshot_config.dart`.

### TC-SHOT-006: In-App Interactive Preview (Pan, Pinch-to-Zoom, Share & Save)
- **Area:** Presentation & UX
- **Preconditions:** Captured `ScreenshotItem`.
- **Procedure:** Render `ScreenshotPreviewDialog`, verify `InteractiveViewer` zoom boundaries, resolution badges, file size formatting, and trigger save to gallery.
- **Expected Result:** Dialog renders full-screen with pan/zoom gesture handling, metadata chip display, and writes to gallery via `ClipWriter`.
- **Automated Test:** `test/features/screenshot/screenshot_screen_test.dart`, `screenshot_controller_test.dart`.
- **Traceability:** `lib/features/screenshot/presentation/widgets/screenshot_preview_dialog.dart`.

### TC-SHOT-007: Session Gallery Strip (Multi-Selection & Batch Save)
- **Area:** Presentation & State Management
- **Preconditions:** Active session with multiple captured frames.
- **Procedure:** Test `toggleSelection`, `selectAll`, `saveSelectedToGallery`, and `deleteSelected`.
- **Expected Result:** Controller maintains selected IDs, persists batch saves via `ClipWriter`, and removes deleted frames cleanly from session state and temp storage.
- **Automated Test:** `test/features/screenshot/screenshot_controller_test.dart`.
- **Traceability:** `lib/features/screenshot/presentation/controllers/screenshot_controller.dart`.

### TC-SHOT-008: Screenshot UI, Scrubber Controls, and Background Queue Integration
- **Area:** Presentation & Queue Integration
- **Preconditions:** Flutter widget test environment.
- **Procedure:** Mount `ScreenshotScreen`, inspect player scrubber, mode segmented chips, and enqueue batch extraction.
- **Expected Result:** UI renders all controls cleanly, updates slider/nudges, and dispatches `JobType.screenshot` into `JobQueueController`.
- **Automated Test:** `test/features/screenshot/screenshot_screen_test.dart`, `screenshot_controller_test.dart`.
- **Traceability:** `lib/features/screenshot/presentation/screens/screenshot_screen.dart`, `job_queue_controller.dart`.

---

### TC-MERGE-001: Fast Stream Copy Concatenation on Compatible Video Clips
- **Area:** Concat Demuxer / Performance
- **Preconditions:** At least 2 input videos sharing identical video codec, audio codec, dimensions, frame rate, and no active trim boundaries.
- **Procedure:** Compile concat list using `MergeFilterCompiler.generateConcatListContent`, execute fast stream copy with `MergeFilterCompiler.buildFastConcatArgs`.
- **Expected Result:** Concat completes with `-c copy` without transcoding; video and audio tracks are seamlessly joined; duration equals sum of inputs.
- **Automated Test:** `test/features/merge/merge_integration_test.dart`, `merge_filter_compiler_test.dart`.
- **Traceability:** `lib/features/merge/domain/merge_filter_compiler.dart`, `ffmpeg_video_processor.dart`.

### TC-MERGE-002: Crossfade Transitions Between Video Clips
- **Area:** Video Transition / Complex Filter
- **Preconditions:** Multiple clips with `MergeTransition.fade` and transition duration $D$.
- **Procedure:** Compile cascaded `xfade` (video) and `acrossfade` (audio) filters; verify computed offsets: $O_1 = \text{dur}_0 - D$, $O_i = O_{i-1} + \text{dur}_{i-1} - D$.
- **Expected Result:** FFmpeg renders smooth video crossfade dissolve and audio crossfade; resulting video duration equals $\sum \text{dur}_i - (N-1) \times D$.
- **Automated Test:** `test/features/merge/merge_integration_test.dart`, `merge_filter_compiler_test.dart`.
- **Traceability:** `lib/features/merge/domain/merge_filter_compiler.dart`, `ffmpeg_video_processor.dart`.

### TC-MERGE-003: Aspect Ratio Normalization with Letterbox Padding
- **Area:** Canvas Adaptation / Filter Complex
- **Preconditions:** Multiple input clips with disparate aspect ratios (e.g., 16:9 landscape and 9:16 vertical).
- **Procedure:** Select `CanvasFitMode.fitBlack` and preset `CanvasAspectRatioPreset.standard720p` (1280x720).
- **Expected Result:** Clips are scaled with `force_original_aspect_ratio=decrease` and centered with black letterbox/pillarbox padding; output matches exact target dimensions without distortion.
- **Automated Test:** `test/features/merge/merge_integration_test.dart`, `merge_filter_compiler_test.dart`.
- **Traceability:** `lib/features/merge/domain/merge_filter_compiler.dart`, `merge_project.dart`.

### TC-MERGE-004: Crop to Fill Canvas Normalization
- **Area:** Canvas Adaptation / Filter Complex
- **Preconditions:** Input video clips with different aspect ratios.
- **Procedure:** Select `CanvasFitMode.cropFill` with target aspect preset.
- **Expected Result:** Clips are scaled with `force_original_aspect_ratio=increase` and center-cropped to fill the canvas with no black borders.
- **Automated Test:** `test/features/merge/merge_filter_compiler_test.dart`.
- **Traceability:** `lib/features/merge/domain/merge_filter_compiler.dart`.

### TC-MERGE-005: Blurred Background Canvas Normalization
- **Area:** Canvas Adaptation / Filter Complex
- **Preconditions:** Disparate video aspect ratios with `CanvasFitMode.fitBlur`.
- **Procedure:** Compile multi-input filter graph splitting each video into background (blurred with `gblur=sigma=20`) and foreground (scaled to fit).
- **Expected Result:** Background fills canvas with blurred video content while foreground maintains original aspect ratio centered on top.
- **Automated Test:** `test/features/merge/merge_filter_compiler_test.dart`.
- **Traceability:** `lib/features/merge/domain/merge_filter_compiler.dart`.

### TC-MERGE-006: Missing Audio Handling via Synthetic Silence Generator
- **Area:** Audio Normalization / Error Prevention
- **Preconditions:** One or more video clips lack an audio stream (`hasAudio == false`, e.g., silent clip or screen recording).
- **Procedure:** Verify `MergeFilterCompiler` generates synthetic stereo silence stream (`anullsrc=r=44100:cl=stereo,atrim=0:<duration>,asetpts=PTS-STARTPTS`).
- **Expected Result:** Concat filter executes without FFmpeg stream mismatch errors; merged video has an uninterrupted synchronized audio track.
- **Automated Test:** `test/features/merge/merge_integration_test.dart`, `merge_filter_compiler_test.dart`.
- **Traceability:** `lib/features/merge/domain/merge_filter_compiler.dart`, `ffmpeg_video_processor.dart`.

### TC-MERGE-007: Clip Reordering, Duplication, and Trim Adjustment in UI
- **Area:** Presentation & State Management
- **Preconditions:** Multiple video clips loaded into `MergeController`.
- **Procedure:** Perform drag-and-drop reordering, tap duplicate button, and open trim modal dialog to set custom start and end cut points.
- **Expected Result:** Clip order updates correctly with proper index shifting; duplicate item receives unique ID; trim boundaries are clamped and reflected in total duration calculation.
- **Automated Test:** `test/features/merge/merge_controller_test.dart`, `merge_screen_test.dart`.
- **Traceability:** `lib/features/merge/presentation/controllers/merge_controller.dart`, `merge_clip_tile.dart`, `merge_trim_dialog.dart`.

### TC-MERGE-008: Unified Job Queue Dispatch & Background Foreground Service Execution
- **Area:** Queue & Background Service Integration
- **Preconditions:** Valid merge configuration with 2+ clips.
- **Procedure:** Dispatch merge job from `MergeScreen`; observe `JobRecord` submission into `JobQueueController`.
- **Expected Result:** Job is queued as `JobType.merge`, updates notification with progress percentage, writes final video via `ClipWriter`, and transitions to completed.
- **Automated Test:** `test/features/merge/merge_controller_test.dart`.
- **Traceability:** `lib/features/merge/presentation/controllers/merge_controller.dart`, `job_queue_controller.dart`, `ffmpeg_video_processor.dart`.

---

## Phase 8: Core Reliability & Validation Fixes

### TC-VAL-001: Centralized Video Selection Validation
- **Area:** Validation Domain
- **Preconditions:** Video picker state with null video, 0-byte file, or zero duration.
- **Procedure:** Run `SelectVideoValidator.validate`.
- **Expected Result:** Returns `ValidationResult` with specific error codes (`VIDEO_MISSING`, `VIDEO_ZERO_DURATION`, `VIDEO_EMPTY_FILE`) and actionable user messages.
- **Automated Test:** `test/core/validation/validators_test.dart`.
- **Traceability:** `lib/core/validation/validators/select_video_validator.dart`.

### TC-VAL-002: Precise Trim Boundary Validation
- **Area:** Validation Domain
- **Preconditions:** Arbitrary start/end seconds and total duration.
- **Procedure:** Run `TrimValidator.validate` with negative start, start >= end, range < 1.0s, and end > duration.
- **Expected Result:** Rejects invalid ranges with precise actionable errors; passes when $0 \le \text{start} < \text{end} \le \text{dur}$ and $(\text{end} - \text{start}) \ge 1.0\text{s}$.
- **Automated Test:** `test/core/validation/validators_test.dart`.
- **Traceability:** `lib/core/validation/validators/trim_validator.dart`.

### TC-VAL-003: Shorts Split Settings & 180s Limit Enforcement
- **Area:** Validation Domain
- **Preconditions:** `SplitConfig` with clip length < 1s, > 180s in Shorts mode, or > 500 clips.
- **Procedure:** Run `SplitSettingsValidator.validate`.
- **Expected Result:** Blocks invalid configurations; enforces 180s Shorts platform constraint and 500-clip sane cap.
- **Automated Test:** `test/core/validation/validators_test.dart`.
- **Traceability:** `lib/core/validation/validators/split_settings_validator.dart`.

### TC-VAL-004: Background Fill Spec Validation
- **Area:** Validation Domain
- **Preconditions:** Solid color, image, and blur background configurations.
- **Procedure:** Run `BackgroundValidator.validate` with invalid hex color and missing image file.
- **Expected Result:** Rejects missing images or invalid color values; validates existing image assets and blur presets.
- **Automated Test:** `test/core/validation/validators_test.dart`.
- **Traceability:** `lib/core/validation/validators/background_validator.dart`.

### TC-VAL-005: Text & Logo Overlay Spec Validation
- **Area:** Validation Domain
- **Preconditions:** `OverlaySpec` with active overlay and missing template or non-existent logo.
- **Procedure:** Run `OverlayValidator.validate`.
- **Expected Result:** Requires non-empty template and valid logo file path; allows standard auto-labeling.
- **Automated Test:** `test/core/validation/validators_test.dart`.
- **Traceability:** `lib/core/validation/validators/overlay_validator.dart`.

### TC-VAL-006: Audio Studio Track & Microphone Validation
- **Area:** Validation Domain
- **Preconditions:** Audio track configs with missing music, voice-over without mic permission, or all tracks muted.
- **Procedure:** Run `AudioValidator.validate`.
- **Expected Result:** Flags missing audio assets and prompts for mic permission before voice-over recording.
- **Automated Test:** `test/core/validation/validators_test.dart`.
- **Traceability:** `lib/core/validation/validators/audio_validator.dart`.

### TC-VAL-007: Output Storage Location & SAF Permission Validation
- **Area:** Validation Domain
- **Preconditions:** Empty directory path, revoked SAF tree URI, or missing local folder.
- **Procedure:** Run `OutputLocationValidator.validate`.
- **Expected Result:** Returns actionable error offering to pick or re-grant access to output folder.
- **Automated Test:** `test/core/validation/validators_test.dart`.
- **Traceability:** `lib/core/validation/validators/output_location_validator.dart`.

### TC-VAL-008: Export Preflight & System Resource Guarding
- **Area:** Validation Domain
- **Preconditions:** Active export job, low storage space (< 1.5x required), or disabled notifications.
- **Procedure:** Run `ExportPreflightValidator.validate`.
- **Expected Result:** Prevents concurrent duplicate exports; blocks when storage is insufficient; issues warning for notifications.
- **Automated Test:** `test/core/validation/validators_test.dart`.
- **Traceability:** `lib/core/validation/validators/export_preflight_validator.dart`.

### TC-VAL-009: Custom Split Cut Points & Boundary Spacing Validation
- **Area:** Validation Domain
- **Preconditions:** User-entered custom split timestamps.
- **Procedure:** Run `CustomSplitValidator.validatePoint` and `validatePlan`.
- **Expected Result:** Enforces strictly ascending points, prevents duplicate cuts, and guarantees >= 1.0s clip spacing.
- **Automated Test:** `test/core/validation/validators_test.dart`.
- **Traceability:** `lib/core/validation/validators/custom_split_validator.dart`.

### TC-TRIM-001: Integer Millisecond Timeline Coordinate Mapping
- **Area:** Presentation & Math Domain
- **Preconditions:** Video duration up to multiple hours; responsive viewport width.
- **Procedure:** Test `TimelineMapper` bidirectional conversions (`timeToX` <-> `xToTime`).
- **Expected Result:** Zero floating point rounding drift; clamps gestures cleanly at track boundaries $[0, \text{duration}]$.
- **Automated Test:** `test/features/create/timeline_mapper_test.dart`.
- **Traceability:** `lib/features/create/domain/timeline_mapper.dart`.

### TC-TRIM-002: Dual Handle Clamping & Minimum 1.0s Gap Invariant
- **Area:** Presentation & Gesture Domain
- **Preconditions:** Start handle and end handle positions.
- **Procedure:** Drag start handle toward end handle and end handle toward start handle.
- **Expected Result:** Handles never cross; enforce strict minimum gap of 1000ms; triggers haptic feedback at boundaries.
- **Automated Test:** `test/features/create/timeline_mapper_test.dart`, `interactive_trim_timeline_test.dart`.
- **Traceability:** `lib/features/create/domain/timeline_mapper.dart`, `interactive_trim_timeline.dart`.

### TC-TRIM-003: Strictly Clipped Playhead Rendering
- **Area:** Custom Painting
- **Preconditions:** Active video playback or scrubbing.
- **Procedure:** Scrub playhead past end or before start; verify rendering.
- **Expected Result:** Playhead indicator is strictly clipped within the track `RRect`; never renders outside the timeline bounds.
- **Automated Test:** `test/features/create/interactive_trim_timeline_test.dart`.
- **Traceability:** `lib/features/create/presentation/widgets/interactive_trim_timeline.dart`.

### TC-E2E-001: Create Shorts Single Job Dispatch & Idempotency Lock
- **Area:** End-to-End Orchestration
- **Preconditions:** Valid video and split plan.
- **Procedure:** Rapidly double tap "Start Export" on `PlanReviewScreen`.
- **Expected Result:** Internal `_isSubmitting` lock ensures strictly ONE export job is dispatched; subsequent taps ignored; temp files cleaned up on failure.
- **Automated Test:** Integration tests and `test/features/plan_review/plan_review_screen_test.dart`.
- **Traceability:** `lib/features/plan_review/presentation/screens/plan_review_screen.dart`, `export_job_controller.dart`.

### TC-HIST-001: History Date Grouping & Sorting
- **Area:** Presentation & State
- **Preconditions:** Project history records spanning multiple days.
- **Procedure:** Mount `HistoryScreen`; toggle sort orders (newest, oldest, duration, count).
- **Expected Result:** Projects are cleanly grouped under "Today", "Yesterday", "Earlier This Week", and "Older" headers; sort order updates reactively.
- **Automated Test:** `test/features/history/history_screen_test.dart`.
- **Traceability:** `lib/features/history/presentation/screens/history_screen.dart`, `history_controller.dart`.

### TC-HIST-002: Non-Blocking Asynchronous File Availability Checks
- **Area:** Performance & Storage
- **Preconditions:** Historical projects with valid and missing files on disk.
- **Procedure:** Load history list and inspect performance.
- **Expected Result:** No synchronous `File.existsSync()` blocking `build()`; renders instantly with cached/async checks; badges missing files.
- **Automated Test:** `test/features/history/history_screen_test.dart`.
- **Traceability:** `lib/features/history/domain/models/project_record.dart`, `history_project_card.dart`.

### TC-HIST-003: Stateful Tab Navigation Persistence
- **Area:** Navigation & Shell
- **Preconditions:** User configures trim or project in Create tab and switches to History tab and back.
- **Procedure:** Switch tabs via `AppScaffold` navigation destinations.
- **Expected Result:** `StatefulShellRoute.indexedStack` preserves full widget state, scroll position, and inputs without reload or data loss.
- **Automated Test:** Shell navigation widget tests.
- **Traceability:** `lib/app/router.dart`, `lib/shared/widgets/app_scaffold.dart`.

---

## Traceability Matrix

| Test Case ID | Feature / Component | Source File | Test File | Status |
|---|---|---|---|---|
| `TC-FOUNDATION-001` | APK Naming & Android App Name | `android/app/build.gradle.kts` | CLI verification | PASS |
| `TC-FOUNDATION-002` | Adaptive Branding Icons | `scripts/gen_icons.sh` | Shell verification | PASS |
| `TC-FOUNDATION-003` | Unified Job Queue Controller | `lib/features/jobs/domain/job_queue_controller.dart` | `test/features/jobs/job_queue_controller_test.dart` | PASS |
| `TC-FOUNDATION-004` | Video Filter Compilation | `lib/features/processing/domain/filter_graph_builder.dart` | `test/features/processing/filter_graph_builder_test.dart` | PASS |
| `TC-FOUNDATION-005` | Audio Graph & Atempo Chains | `lib/features/processing/domain/audio_graph_builder.dart` | `test/features/processing/audio_graph_builder_test.dart` | PASS |
| `TC-FOUNDATION-006` | Fixture Generator | `scripts/make_fixtures.sh` | Shell verification | PASS |
| `TC-FOUNDATION-007` | Headless Output Verifier | `test/utils/output_verifier.dart` | `test/utils/output_verifier_test.dart` | PASS |
| `TC-FOUNDATION-008` | 5-Tab Shell & 7 Studio Tools | `lib/shared/widgets/app_scaffold.dart` | Widget tests | PASS |
| `TC-CUSTOM-001` | Custom Split by Duration (No Cap) | `lib/features/custom_split/domain/custom_split_calculator.dart` | `test/features/custom_split/custom_split_calculator_test.dart` | PASS |
| `TC-CUSTOM-002` | Trailing Remainder Absorption Rule | `lib/features/custom_split/domain/custom_split_calculator.dart` | `test/features/custom_split/custom_split_calculator_test.dart` | PASS |
| `TC-CUSTOM-003` | Equal Parts Segmentation | `lib/features/custom_split/domain/custom_split_calculator.dart` | `test/features/custom_split/custom_split_calculator_test.dart` | PASS |
| `TC-CUSTOM-004` | Arbitrary Custom Split Points | `lib/features/custom_split/domain/custom_split_calculator.dart` | `test/features/custom_split/custom_split_calculator_test.dart` | PASS |
| `TC-CUSTOM-005` | File Size Estimation Mode | `lib/features/custom_split/domain/custom_split_calculator.dart` | `test/features/custom_split/custom_split_calculator_test.dart` | PASS |
| `TC-CUSTOM-006` | Fast Stream-Copy vs Precise Split | `lib/features/processing/data/ffmpeg_video_processor.dart` | `test/features/custom_split/custom_split_integration_test.dart` | PASS |
| `TC-CUSTOM-007` | Interactive Plan Editing | `lib/features/custom_split/domain/custom_split_calculator.dart` | `test/features/custom_split/custom_split_calculator_test.dart` | PASS |
| `TC-CUSTOM-008` | Custom Split UI & Review Screen | `lib/features/custom_split/presentation/` | `test/features/custom_split/custom_split_screen_test.dart` | PASS |
| `TC-EDIT-001` | Non-Destructive EditProject Model | `lib/features/editor/domain/models/edit_project.dart` | `test/features/editor/edit_project_test.dart` | PASS |
| `TC-EDIT-002` | Reverse Playback 15s Invariant | `lib/features/editor/domain/models/edit_project.dart` | `test/features/editor/edit_project_test.dart` | PASS |
| `TC-EDIT-003` | 1-Pass Complex Filter Compilation | `lib/features/editor/domain/editor_filter_compiler.dart` | `test/features/editor/editor_filter_compiler_test.dart` | PASS |
| `TC-EDIT-004` | Pitch-Preserving Speed (Atempo) | `lib/features/editor/domain/editor_filter_compiler.dart` | `test/features/editor/editor_integration_test.dart` | PASS |
| `TC-EDIT-005` | Color Correction & Grading Presets | `lib/features/editor/domain/editor_filter_compiler.dart` | `test/features/editor/editor_filter_compiler_test.dart` | PASS |
| `TC-EDIT-006` | Watermark & Text Overlay Placement | `lib/features/editor/domain/editor_filter_compiler.dart` | `test/features/editor/editor_integration_test.dart` | PASS |
| `TC-EDIT-007` | Rapid 5s Quick Preview | `lib/features/editor/domain/editor_filter_compiler.dart` | `test/features/editor/editor_controller_test.dart` | PASS |
| `TC-EDIT-008` | Studio Editor UI Dock & Queue | `lib/features/editor/presentation/` | `test/features/editor/editor_screen_test.dart` | PASS |
| `TC-CONV-001` | MP4 H.264 & H.265 Transcoding | `lib/features/convert/domain/convert_filter_compiler.dart` | `test/features/convert/convert_integration_test.dart` | PASS |
| `TC-CONV-002` | WebM VP9 + Opus Transcoding | `lib/features/convert/domain/convert_filter_compiler.dart` | `test/features/convert/convert_filter_compiler_test.dart` | PASS |
| `TC-CONV-003` | Aspect-Preserving Downscale & FPS | `lib/features/convert/domain/convert_filter_compiler.dart` | `test/features/convert/convert_integration_test.dart` | PASS |
| `TC-CONV-004` | Target Size Mode (Discord/WhatsApp) | `lib/features/convert/domain/convert_filter_compiler.dart` | `test/features/convert/convert_config_test.dart` | PASS |
| `TC-CONV-005` | 2-Pass Palettegen Animated GIF | `lib/features/convert/domain/convert_filter_compiler.dart` | `test/features/convert/convert_integration_test.dart` | PASS |
| `TC-CONV-006` | Audio Extraction (MP3, WAV, AAC, Opus) | `lib/features/convert/domain/convert_filter_compiler.dart` | `test/features/convert/convert_integration_test.dart` | PASS |
| `TC-CONV-007` | Output Size Estimator | `lib/features/convert/domain/models/convert_config.dart` | `test/features/convert/convert_config_test.dart` | PASS |
| `TC-CONV-008` | Convert & Compress UI & Queue | `lib/features/convert/presentation/` | `test/features/convert/convert_screen_test.dart` | PASS |
| `TC-AUDIO-001` | Original Audio Volume Scaling & Muting | `lib/features/audio_studio/domain/audio_studio_compiler.dart` | `test/features/audio_studio/audio_studio_integration_test.dart` | PASS |
| `TC-AUDIO-002` | Background Music Replacement & Loop | `lib/features/audio_studio/domain/audio_studio_compiler.dart` | `test/features/audio_studio/audio_studio_integration_test.dart` | PASS |
| `TC-AUDIO-003` | Multi-Track Audio Mixing | `lib/features/audio_studio/domain/audio_studio_compiler.dart` | `test/features/audio_studio/audio_studio_compiler_test.dart` | PASS |
| `TC-AUDIO-004` | Smart Sidechain Audio Ducking | `lib/features/audio_studio/domain/audio_studio_compiler.dart` | `test/features/audio_studio/audio_studio_integration_test.dart` | PASS |
| `TC-AUDIO-005` | Timeline Offset & Audio Delay | `lib/features/audio_studio/domain/audio_studio_compiler.dart` | `test/features/audio_studio/audio_studio_compiler_test.dart` | PASS |
| `TC-AUDIO-006` | Standalone Audio Extraction | `lib/features/audio_studio/domain/audio_studio_compiler.dart` | `test/features/audio_studio/audio_studio_integration_test.dart` | PASS |
| `TC-AUDIO-007` | Microphone Voice-over Recording | `lib/features/audio_studio/data/audio_recording_service.dart` | `test/features/audio_studio/audio_studio_controller_test.dart` | PASS |
| `TC-AUDIO-008` | Audio Studio UI & Queue Integration | `lib/features/audio_studio/presentation/` | `test/features/audio_studio/audio_studio_screen_test.dart` | PASS |
| `TC-SHOT-001` | Instant Playhead Frame Extraction (PNG) | `lib/features/screenshot/domain/screenshot_compiler.dart` | `test/features/screenshot/screenshot_integration_test.dart` | PASS |
| `TC-SHOT-002` | High-Quality Compressed JPEG Frame | `lib/features/screenshot/domain/screenshot_compiler.dart` | `test/features/screenshot/screenshot_integration_test.dart` | PASS |
| `TC-SHOT-003` | Custom Timestamp List Filtering | `lib/features/screenshot/domain/models/screenshot_config.dart` | `test/features/screenshot/screenshot_config_test.dart` | PASS |
| `TC-SHOT-004` | Interval Extraction (Every X Seconds) | `lib/features/screenshot/domain/models/screenshot_config.dart` | `test/features/screenshot/screenshot_config_test.dart` | PASS |
| `TC-SHOT-005` | Equal Frame Count Segmentation | `lib/features/screenshot/domain/models/screenshot_config.dart` | `test/features/screenshot/screenshot_config_test.dart` | PASS |
| `TC-SHOT-006` | In-App Interactive Preview (Pan/Zoom/Save) | `lib/features/screenshot/presentation/widgets/` | `test/features/screenshot/screenshot_screen_test.dart` | PASS |
| `TC-SHOT-007` | Session Gallery Strip & Batch Save | `lib/features/screenshot/presentation/controllers/` | `test/features/screenshot/screenshot_controller_test.dart` | PASS |
| `TC-SHOT-008` | Screenshot UI, Scrubber & Queue | `lib/features/screenshot/presentation/screens/` | `test/features/screenshot/screenshot_screen_test.dart` | PASS |
| `TC-MERGE-001` | Fast Stream Copy Concatenation | `lib/features/merge/domain/merge_filter_compiler.dart` | `test/features/merge/merge_integration_test.dart` | PASS |
| `TC-MERGE-002` | Crossfade Video & Audio Transitions | `lib/features/merge/domain/merge_filter_compiler.dart` | `test/features/merge/merge_integration_test.dart` | PASS |
| `TC-MERGE-003` | Aspect Normalization & Letterbox | `lib/features/merge/domain/merge_filter_compiler.dart` | `test/features/merge/merge_integration_test.dart` | PASS |
| `TC-MERGE-004` | Crop to Fill Canvas Normalization | `lib/features/merge/domain/merge_filter_compiler.dart` | `test/features/merge/merge_filter_compiler_test.dart` | PASS |
| `TC-MERGE-005` | Blurred Background Canvas Normalization | `lib/features/merge/domain/merge_filter_compiler.dart` | `test/features/merge/merge_filter_compiler_test.dart` | PASS |
| `TC-MERGE-006` | Synthetic Silence for Missing Audio | `lib/features/merge/domain/merge_filter_compiler.dart` | `test/features/merge/merge_integration_test.dart` | PASS |
| `TC-MERGE-007` | Clip Reorder, Duplicate & Trim in UI | `lib/features/merge/presentation/controllers/merge_controller.dart` | `test/features/merge/merge_controller_test.dart` | PASS |
| `TC-MERGE-008` | Unified Job Queue & Merge Execution | `lib/features/jobs/domain/job_queue_controller.dart` | `test/features/merge/merge_controller_test.dart` | PASS |
| `TC-VAL-001` | Video Selection Validator | `lib/core/validation/validators/select_video_validator.dart` | `test/core/validation/validators_test.dart` | PASS |
| `TC-VAL-002` | Precise Trim Boundary Validator | `lib/core/validation/validators/trim_validator.dart` | `test/core/validation/validators_test.dart` | PASS |
| `TC-VAL-003` | Shorts Split Settings Validator | `lib/core/validation/validators/split_settings_validator.dart` | `test/core/validation/validators_test.dart` | PASS |
| `TC-VAL-004` | Background Spec Validator | `lib/core/validation/validators/background_validator.dart` | `test/core/validation/validators_test.dart` | PASS |
| `TC-VAL-005` | Overlay Spec Validator | `lib/core/validation/validators/overlay_validator.dart` | `test/core/validation/validators_test.dart` | PASS |
| `TC-VAL-006` | Audio Studio Validator | `lib/core/validation/validators/audio_validator.dart` | `test/core/validation/validators_test.dart` | PASS |
| `TC-VAL-007` | Output Location & SAF Validator | `lib/core/validation/validators/output_location_validator.dart` | `test/core/validation/validators_test.dart` | PASS |
| `TC-VAL-008` | Export Preflight Validator | `lib/core/validation/validators/export_preflight_validator.dart` | `test/core/validation/validators_test.dart` | PASS |
| `TC-VAL-009` | Custom Split Points Validator | `lib/core/validation/validators/custom_split_validator.dart` | `test/core/validation/validators_test.dart` | PASS |
| `TC-VAL-010` | Parts Selection Validator | `lib/core/validation/validators/parts_selection_validator.dart` | `test/core/validation/validators_test.dart` | PASS |
| `TC-TRIM-001` | Integer Ms Timeline Coordinate Mapper | `lib/features/create/domain/timeline_mapper.dart` | `test/features/create/timeline_mapper_test.dart` | PASS |
| `TC-TRIM-002` | Dual Handle Clamping & 1s Min Gap | `lib/features/create/domain/timeline_mapper.dart` | `test/features/create/timeline_mapper_test.dart` | PASS |
| `TC-TRIM-003` | Clipped Playhead Custom Painting | `lib/features/create/presentation/widgets/interactive_trim_timeline.dart` | `test/features/create/interactive_trim_timeline_test.dart` | PASS |
| `TC-E2E-001` | Create Shorts Single Job Dispatch | `lib/features/plan_review/presentation/screens/plan_review_screen.dart` | `test/features/plan_review/plan_review_screen_test.dart` | PASS |
| `TC-SELECT-001` | Selective Processing & Naming Invariant | `lib/features/plan_review/domain/models/clip_processing_state.dart` | `test/features/plan_review/clip_processing_state_test.dart` | PASS |
| `TC-SELECT-002` | Selective Processing UI & Accessibility | `lib/features/plan_review/presentation/screens/plan_review_screen.dart` | `test/features/plan_review/plan_review_selection_widget_test.dart` | PASS |
| `TC-SELECT-003` | Selective Real Fixture Integration | `lib/features/processing/data/ffmpeg_video_processor.dart` | `test/features/processing/selective_split_integration_test.dart` | PASS |
| `TC-HIST-001` | History Date Grouping & Sorting | `lib/features/history/presentation/screens/history_screen.dart` | `test/features/history/history_screen_test.dart` | PASS |
| `TC-HIST-002` | Non-Blocking File Availability Check | `lib/features/history/domain/models/project_record.dart` | `test/features/history/history_screen_test.dart` | PASS |
| `TC-HIST-003` | Stateful Tab Navigation Persistence | `lib/app/router.dart` | Widget tests | PASS |
| `TC-HIST-004` | Partial Completion History Badge | `lib/features/history/presentation/widgets/history_project_card.dart` | `test/features/history/history_partial_test.dart` | PASS |
| `TC-PERF-001` | Single-Pass Stream-Copy Segment Muxer | `lib/features/processing/data/ffmpeg_video_processor.dart` | Benchmark runner | PASS |
| `TC-PERF-002` | Downscaled 10% Background Blur | `lib/features/processing/domain/filter_graph_builder.dart` | Benchmark runner | PASS |
| `TC-PERF-003` | Hardware Encoder with Mediacodec | `lib/features/processing/data/ffmpeg_video_processor.dart` | `scripts/check_16kb.sh` | PASS |
| `TC-PERF-004` | Execution Watchdog Timer | `lib/features/processing/data/ffmpeg_video_processor.dart` | `FFmpegVideoProcessor._executeSession` | PASS |

