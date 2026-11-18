---
name: ffmpeg-split-recipes
description: Tested FFmpeg command patterns for fast stream-copy splits, precise re-encoding, 9:16 center cropping, and 9:16 blurred-background letterboxing.
---

# FFmpeg Video Split Recipes & Filters

## Trigger Conditions
Use this skill when:
- Modifying `lib/features/processing/data/ffmpeg_video_processor.dart` or `filter_graph_builder.dart`.
- Adding or adjusting video transformation filters, canvas padding, or background fills.
- Debugging AV desync, black frames, or keyframe seek inaccuracy during video splitting.

---

## 1. Fast Stream-Copy Split (No Re-encoding)
Allowed ONLY when source matches canvas, no background fill, no trim, and no text overlay.
```bash
ffmpeg -y -ss {startSeconds} -i "{inputPath}" -t {durationSeconds} \
  -c copy -avoid_negative_ts make_zero "{outputPath}"
```

---

## 2. Fit Without Cropping + Solid Color Background (Letterbox / Pillarbox)
Default mode: preserves full video frame centered over a padded canvas.
```bash
ffmpeg -y -ss {startSeconds} -i "{inputPath}" -t {durationSeconds} \
  -vf "scale={w}:{h}:force_original_aspect_ratio=decrease,pad={w}:{h}:(ow-iw)/2:(oh-ih)/2:color={0xHEX},setsar=1" \
  -map 0:a? \
  -c:v libx264 -preset veryfast -crf 22 -r 60 \
  -c:a aac -b:a 128k -pix_fmt yuv420p -movflags +faststart "{outputPath}"
```

---

## 3. Fit Without Cropping + Blurred Video Background
Video is centered; background is filled with blurred, scaled video duplicate.
```bash
ffmpeg -y -ss {startSeconds} -i "{inputPath}" -t {durationSeconds} \
  -filter_complex "[0:v]scale={w}:{h}:force_original_aspect_ratio=increase,crop={w}:{h},boxblur=luma_radius=min(h\\,w)/20:luma_power=2[bg]; \
                   [0:v]scale={w}:{h}:force_original_aspect_ratio=decrease[fg]; \
                   [bg][fg]overlay=(W-w)/2:(H-h)/2,setsar=1[outv]" \
  -map "[outv]" -map 0:a? \
  -c:v libx264 -preset veryfast -crf 22 -r 60 \
  -c:a aac -b:a 128k -pix_fmt yuv420p -movflags +faststart "{outputPath}"
```

---

## 4. Custom Gallery Image Background
```bash
ffmpeg -y -ss {startSeconds} -i "{inputPath}" -loop 1 -i "{imagePath}" -t {durationSeconds} \
  -filter_complex "[1:v]scale={w}:{h}:force_original_aspect_ratio=increase,crop={w}:{h}[bg]; \
                   [0:v]scale={w}:{h}:force_original_aspect_ratio=decrease[fg]; \
                   [bg][fg]overlay=(W-w)/2:(H-h)/2:shortest=1,setsar=1[outv]" \
  -map "[outv]" -map 0:a? \
  -c:v libx264 -preset veryfast -crf 22 -r 60 \
  -c:a aac -b:a 128k -pix_fmt yuv420p -movflags +faststart "{outputPath}"
```

---

## 5. Explicit Crop to Fill
Enabled only when user explicitly toggles "Crop to fill".
```bash
ffmpeg -y -ss {startSeconds} -i "{inputPath}" -t {durationSeconds} \
  -vf "scale={w}:{h}:force_original_aspect_ratio=increase,crop={w}:{h},setsar=1" \
  -map 0:a? \
  -c:v libx264 -preset veryfast -crf 22 -r 60 \
  -c:a aac -b:a 128k -pix_fmt yuv420p -movflags +faststart "{outputPath}"
```

---

## 6. Text Overlay via Transparent PNG
Rendered in pure Flutter (`dart:ui`) to a temp PNG, guaranteeing universal Unicode and emoji support:
- **Whole Clip:**
  `[v_base][overlay_in]overlay=0:0[outv]`
- **Timed Display (First N Seconds):**
  `[v_base][overlay_in]overlay=0:0:enable='between(t,0,{duration})'[outv]`

---

## 7. Android 9 (API 28) Compatibility & Software Fallback
If hardware / high-level transcode fails on low-spec chips:
```bash
-c:v libx264 -profile:v baseline -level 3.1 -preset ultrafast -pix_fmt yuv420p
```
