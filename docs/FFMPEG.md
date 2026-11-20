# FFmpeg Architecture & Command Recipes

Technical guide to media processing in ShortsSplitter: the `VideoProcessor` boundary, filter graph construction, command recipes, keyframe caveats, and session debugging.

---

## Table of Contents
1. [The Pinned FFmpeg Package](#1-the-pinned-ffmpeg-package)
2. [The VideoProcessor Abstraction](#2-the-videoprocessor-abstraction)
3. [FilterGraphBuilder Overview](#3-filtergraphbuilder-overview)
4. [FFmpeg Command Recipes](#4-ffmpeg-command-recipes)
   - [Recipe 1: Stream Copy (Fast Mode)](#recipe-1-stream-copy-fast-mode)
   - [Recipe 2: Frame-Accurate Cut (Precise Mode)](#recipe-2-frame-accurate-cut-precise-mode)
   - [Recipe 3: 9:16 Solid Color Letterbox](#recipe-3-916-solid-color-letterbox)
   - [Recipe 4: 9:16 Blurred-Background Letterbox](#recipe-4-916-blurred-background-letterbox)
   - [Recipe 5: 9:16 Center Crop](#recipe-5-916-center-crop)
   - [Recipe 6: PNG Text Badge Overlay](#recipe-6-png-text-badge-overlay)
5. [Keyframe Caveats & Seeking Accuracy](#5-keyframe-caveats--seeking-accuracy)
6. [Reading & Diagnosing FFmpeg Session Logs](#6-reading--diagnosing-ffmpeg-session-logs)
7. [How to Swap the Transcoding Engine](#7-how-to-swap-the-transcoding-engine)

---

## 1. The Pinned FFmpeg Package

ShortsSplitter pins **`ffmpeg_kit_flutter_new: ^4.6.8`** in `pubspec.yaml`.

### Why This Package?
The original `ffmpeg-kit-flutter` repository was archived by its maintainer in 2023. The `ffmpeg_kit_flutter_new` fork is the actively maintained community continuation providing:
- Precompiled native C/C++ binaries for Android (`arm64-v8a`, `armeabi-v7a`, `x86_64`) and iOS.
- Compatibility with Android 14 and 15 toolchains (`compileSdk 36`).
- Asynchronous session execution with live statistics streams (`time`, `size`, `bitrate`, `speed`).

---

## 2. The VideoProcessor Abstraction

All media inspection and splitting operations are quarantined behind the abstract `VideoProcessor` interface:

```dart
// lib/features/processing/domain/video_processor.dart
abstract class VideoProcessor {
  Future<VideoMetadata> getMetadata(String videoPath);

  Stream<ProcessingProgress> splitVideo({
    required String sourcePath,
    required ClipPlanPart part,
    required CanvasSpec canvasSpec,
    required OverlaySpec overlaySpec,
    required String outputPath,
  });

  Future<void> cancel();
}
```

No UI widget, controller, or domain model may import `ffmpeg_kit_flutter_new`. Concrete implementation lives strictly in:
`lib/features/processing/data/ffmpeg_video_processor.dart`.

---

## 3. FilterGraphBuilder Overview

Complex visual operations (resizing, padding, blurring, and overlays) are converted into FFmpeg `-vf` filter graph syntax by `FilterGraphBuilder` (`lib/features/processing/domain/filter_graph_builder.dart`).

The builder chains individual video filters separated by commas or labeled filter links, guaranteeing correct aspect ratio preservation and pixel format alignment.

---

## 4. FFmpeg Command Recipes

### Recipe 1: Stream Copy (Fast Mode)
Near-instantaneous slice without re-encoding video or audio frames:
```bash
ffmpeg -y -ss 00:01:00.000 -to 00:02:00.000 -i input.mp4 \
  -c copy -avoid_negative_ts make_zero output_part_001.mp4
```
- `-c copy`: Copies raw compressed H.264 packets directly without decoding.
- `-avoid_negative_ts make_zero`: Shifts packet timestamps so clip starts at time `00:00:00`.

### Recipe 2: Frame-Accurate Cut (Precise Mode)
Re-encodes video frames with accurate seeking to land on the exact millisecond cut point:
```bash
ffmpeg -y -ss 00:01:15.500 -to 00:02:15.500 -i input.mp4 \
  -c:v libx264 -preset faster -crf 22 -pix_fmt yuv420p \
  -c:a aac -b:a 192k -ar 44100 output_part_001.mp4
```

### Recipe 3: 9:16 Solid Color Letterbox
Uses `FitLayout` precalculated integer coordinates to scale video and pad top/bottom with solid color with zero filter default reliance:
```bash
ffmpeg -y -ss 0.0 -i input.mp4 -t 60.0 \
  -vf "scale=1080:608,pad=1080:1920:0:656:color=white,setsar=1" \
  -c:v libx264 -preset ultrafast -crf 23 -pix_fmt yuv420p \
  -c:a aac -b:a 192k output_part_001.mp4
```

### Recipe 4: 9:16 Blurred-Background Letterbox
Downscales a 10% copy (`108x192`), applies fast `boxblur=5:1`, upscales to canvas (`1080x1920:flags=bicubic`), and overlays the foreground video at exact `FitLayout` coordinates:
```bash
ffmpeg -y -ss 0.0 -i input.mp4 -t 60.0 \
  -filter_complex "[0:v]scale=108:192:force_original_aspect_ratio=increase,crop=108:192,boxblur=5:1,scale=1080:1920:flags=bicubic[bg];[0:v]scale=1080:608[fg];[bg][fg]overlay=0:656,setsar=1[outv]" \
  -map "[outv]" -map 0:a? \
  -c:v libx264 -preset ultrafast -crf 23 -pix_fmt yuv420p \
  -c:a aac -b:a 192k output_part_001.mp4
```

### Recipe 5: 9:16 Center Crop
Scales and center-crops landscape video into full-bleed vertical 9:16:
```bash
ffmpeg -y -ss 0.0 -t 60.0 -i input.mp4 \
  -vf "scale=1080:1920:force_original_aspect_ratio=increase,crop=1080:1920" \
  -c:v libx264 -preset faster -crf 22 -pix_fmt yuv420p \
  -c:a aac -b:a 192k output_part_001.mp4
```

### Recipe 6: PNG Text Badge Overlay
Overlays a transparent PNG badge generated by `OverlayRenderer` onto the video:
```bash
ffmpeg -y -ss 0.0 -t 60.0 -i input.mp4 -i badge.png \
  -filter_complex "[0:v][1:v]overlay=(W-w)/2:120[outv]" \
  -map "[outv]" -map 0:a? \
  -c:v libx264 -preset faster -crf 22 -pix_fmt yuv420p \
  -c:a aac -b:a 192k output_part_001.mp4
```

---

## 5. Keyframe Caveats & Seeking Accuracy

- **Stream Copy Limitation:** H.264 video streams only encode full pictures at keyframes (I-frames), which typically occur every 1 to 5 seconds. Stream copy (`-c copy`) can only cut on an existing I-frame. If user requests cut at `00:15.000` but the nearest I-frame is at `00:13.800`, stream copy starts at `00:13.800`.
- **Precise Mode Requirement:** When frame-accurate millisecond cuts or visual transformations (crop, blur, badge) are required, ShortsSplitter automatically activates Precise Mode (`libx264`).

---

## 6. Reading & Diagnosing FFmpeg Session Logs

During export, native FFmpegKit prints diagnostic logs. To stream logs in real time:

```bash
adb logcat -v time | grep "ffmpeg-kit"
```

### Typical Log Output
```
I/ffmpeg-kit(12345): Input #0, mov,mp4,m4a,3gp, from '/data/user/0/.../input.mp4':
I/ffmpeg-kit(12345):   Duration: 00:08:24.32, start: 0.000000, bitrate: 14210 kb/s
I/ffmpeg-kit(12345):   Stream #0:0: Video: h264 (High), yuv420p(tv, bt709), 1920x1080, 29.97 fps
I/ffmpeg-kit(12345):   Stream #0:1: Audio: aac (LC), 48000 Hz, stereo, fltp, 192 kb/s
I/ffmpeg-kit(12345): Stream mapping:
I/ffmpeg-kit(12345):   Stream #0:0 -> #0:0 (h264 (native) -> h264 (libx264))
I/ffmpeg-kit(12345): frame= 1800 fps= 84 q=24.0 size= 24576kB time=00:01:00.00 bitrate=3354.2kbits/s speed=2.8x
```

### Inspecting Execution Failures
If FFmpeg fails, `FFmpegVideoProcessor` logs the return code and full session output to `AppLogger.error()` before throwing typed `ProcessingException`.

---

## 7. How to Swap the Transcoding Engine

Because the system is isolated behind `VideoProcessor`, the native transcode engine can be swapped without touching UI or domain logic:

1. Create your implementation:
   ```dart
   // lib/features/processing/data/mediacodec_video_processor.dart
   class MediaCodecVideoProcessor implements VideoProcessor {
     // Implement using native Android MediaCodec or Media3 Transformer
   }
   ```
2. Update the Riverpod provider in `processing_controller.dart`:
   ```dart
   final videoProcessorProvider = Provider<VideoProcessor>((ref) {
     return MediaCodecVideoProcessor();
   });
   ```
3. Zero presentation screens or domain models require modification.

