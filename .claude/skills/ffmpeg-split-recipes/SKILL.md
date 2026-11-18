---
name: ffmpeg-split-recipes
description: Battle-tested FFmpeg command recipes for stream-copy, frame-accurate re-encode, 9:16 center crop, 9:16 blurred-background letterbox, and keyframe-alignment handling in ShortsSplitter.
---

# FFmpeg Video Split Recipes for YouTube Shorts

This skill documents the exact FFmpeg argument lists executed by `FFmpegVideoProcessor` in `ShortsSplitter`. All commands are passed as `List<String>` argument tokens to `FFmpegKit.executeWithArgumentsAsync()` to avoid shell escaping issues with spaces in paths.

---

## 1. Fast Stream-Copy Split (No Re-encode)

### When to Use
- User selects **Fast Mode** AND **Original Aspect Ratio**.
- Splitting long videos (1GB+) in seconds without CPU/battery load.

### Command Pattern
```bash
ffmpeg -y -ss <startSeconds> -i "<inputPath>" -t <durationSeconds> -c copy -avoid_negative_ts make_zero "<outputPath>"
```

### Argument List in Dart
```dart
[
  '-y',
  '-ss', segment.startSeconds.toStringAsFixed(3),
  '-i', inputPath,
  '-t', segment.durationSeconds.toStringAsFixed(3),
  '-c', 'copy',
  '-avoid_negative_ts', 'make_zero',
  outputPath,
]
```

### Critical Keyframe-Alignment Caveat
- Stream copy (`-c copy`) slices at the nearest **I-frame (keyframe)**.
- If the video has an I-frame interval of 2–5 seconds, the cut may start slightly before or after the requested start time.
- If the video has non-zero start timestamps or B-frames, `-avoid_negative_ts make_zero` shifts initial timestamps to start cleanly from `00:00:00.000` to prevent frozen first frames on mobile players.

---

## 2. Precise Re-encode Split (Frame-Accurate)

### When to Use
- User selects **Precise Mode** OR any aspect-ratio transformation.
- Guarantees cuts exactly to the millisecond, re-generating keyframes at boundary 0.

### Command Pattern
```bash
ffmpeg -y -ss <startSeconds> -i "<inputPath>" -t <durationSeconds> -vf "scale=trunc(iw/2)*2:trunc(ih/2)*2" -c:v libx264 -preset veryfast -crf 22 -c:a aac -b:a 128k "<outputPath>"
```

### Argument List in Dart
```dart
[
  '-y',
  '-ss', segment.startSeconds.toStringAsFixed(3),
  '-i', inputPath,
  '-t', segment.durationSeconds.toStringAsFixed(3),
  '-vf', 'scale=trunc(iw/2)*2:trunc(ih/2)*2',
  '-c:v', 'libx264',
  '-preset', 'veryfast',
  '-crf', '22',
  '-c:a', 'aac',
  '-b:a', '128k',
  outputPath,
]
```
*Note: `scale=trunc(iw/2)*2:trunc(ih/2)*2` ensures both width and height are divisible by 2, avoiding H.264 `width not divisible by 2` crashes.*

---

## 3. 9:16 Center Crop (Full Bleed Vertical)

### When to Use
- Converts landscape (16:9) or standard (4:3) videos directly into full-screen 9:16 vertical Shorts by cropping left and right edges.

### FFmpeg Filter Expression
```
crop='if(gte(a,9/16),ih*9/16,iw)':'if(gte(a,9/16),ih,iw*16/9)':'(iw-ow)/2':'(ih-oh)/2',scale=1080:1920:force_original_aspect_ratio=decrease,pad=1080:1920:(ow-iw)/2:(oh-ih)/2
```

### Argument List in Dart
```dart
[
  '-y',
  '-ss', segment.startSeconds.toStringAsFixed(3),
  '-i', inputPath,
  '-t', segment.durationSeconds.toStringAsFixed(3),
  '-vf',
  "crop='if(gte(a,9/16),ih*9/16,iw)':'if(gte(a,9/16),ih,iw*16/9)':'(iw-ow)/2':'(ih-oh)/2',scale=1080:1920:force_original_aspect_ratio=decrease,pad=1080:1920:(ow-iw)/2:(oh-ih)/2",
  '-c:v', 'libx264',
  '-preset', 'veryfast',
  '-crf', '22',
  '-c:a', 'aac',
  '-b:a', '128k',
  outputPath,
]
```

---

## 4. 9:16 Blurred-Background (Shorts Letterbox)

### When to Use
- Converts horizontal/landscape video to 9:16 vertical Shorts without cutting off content. The original video is centered in its full aspect ratio over a blurred, stretched background.

### Filter Complex Expression
```
[0:v]scale=1080:1920:force_original_aspect_ratio=increase,crop=1080:1920,boxblur=luma_radius=min(h\,w)/20:luma_power=2[bg];[0:v]scale=1080:1920:force_original_aspect_ratio=decrease[fg];[bg][fg]overlay=(W-w)/2:(H-h)/2
```

### Argument List in Dart
```dart
[
  '-y',
  '-ss', segment.startSeconds.toStringAsFixed(3),
  '-i', inputPath,
  '-t', segment.durationSeconds.toStringAsFixed(3),
  '-filter_complex',
  '[0:v]scale=1080:1920:force_original_aspect_ratio=increase,crop=1080:1920,boxblur=luma_radius=min(h\\,w)/20:luma_power=2[bg];[0:v]scale=1080:1920:force_original_aspect_ratio=decrease[fg];[bg][fg]overlay=(W-w)/2:(H-h)/2',
  '-c:v', 'libx264',
  '-preset', 'veryfast',
  '-crf', '22',
  '-c:a', 'aac',
  '-b:a', '128k',
  outputPath,
]
```

---

## 5. Building Commands from a Clip Plan

```dart
List<String> buildArgsForSegment({
  required String inputPath,
  required ClipSegment segment,
  required String outputPath,
  required SplitMode mode,
  required AspectRatioOption aspectRatio,
}) {
  // If user selected 9:16 crop or blur, re-encoding is strictly mandatory.
  if (aspectRatio == AspectRatioOption.cropVertical) {
    return _buildCropVerticalArgs(inputPath, segment, outputPath);
  } else if (aspectRatio == AspectRatioOption.blurVertical) {
    return _buildBlurVerticalArgs(inputPath, segment, outputPath);
  } else if (mode == SplitMode.fast) {
    return _buildStreamCopyArgs(inputPath, segment, outputPath);
  } else {
    return _buildPreciseArgs(inputPath, segment, outputPath);
  }
}
```

