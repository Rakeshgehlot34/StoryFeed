#!/usr/bin/env python3
"""
ShortsSplitter Web Tester & Video Processing Server
--------------------------------------------------
A local web application to test video splitting, 9:16 Shorts conversions,
crop-to-fill, blurred backgrounds, and solid letterbox padding directly
on your computer before exporting to your phone.

Uses standard Python library (no external pip dependencies needed) + system FFmpeg.
"""

import cgi
import http.server
import json
import mimetypes
import os
import re
import shutil
import subprocess
import sys
import time
import urllib.parse
from pathlib import Path

# Directories
BASE_DIR = Path(__file__).resolve().parent
PROJECT_DIR = BASE_DIR.parent.parent
UPLOADS_DIR = BASE_DIR / "uploads"
OUTPUTS_DIR = BASE_DIR / "outputs"
SAMPLES_DIR = BASE_DIR / "samples"

UPLOADS_DIR.mkdir(parents=True, exist_ok=True)
OUTPUTS_DIR.mkdir(parents=True, exist_ok=True)
SAMPLES_DIR.mkdir(parents=True, exist_ok=True)

# Copy /tmp sample if it exists
TMP_SAMPLE = Path("/tmp/test_video/source_23s.mp4")
if TMP_SAMPLE.exists() and not (SAMPLES_DIR / "sample_23s.mp4").exists():
    try:
        shutil.copy(TMP_SAMPLE, SAMPLES_DIR / "sample_23s.mp4")
    except Exception:
        pass


def get_ffmpeg_path():
    p = shutil.which("ffmpeg")
    if p:
        return p
    local_p = Path.home() / ".local/bin/ffmpeg"
    if local_p.exists():
        return str(local_p)
    return "ffmpeg"


def get_ffprobe_path():
    p = shutil.which("ffprobe")
    if p:
        return p
    local_p = Path.home() / ".local/bin/ffprobe"
    if local_p.exists():
        return str(local_p)
    return "ffprobe"


FFMPEG = get_ffmpeg_path()
FFPROBE = get_ffprobe_path()


def probe_video(file_path):
    """Probes a video file using ffprobe and returns dictionary of metadata."""
    if not os.path.exists(file_path):
        return None

    cmd = [
        FFPROBE,
        "-v", "quiet",
        "-print_format", "json",
        "-show_format",
        "-show_streams",
        str(file_path)
    ]
    try:
        res = subprocess.run(cmd, capture_output=True, text=True, check=True)
        data = json.loads(res.stdout)
    except Exception as e:
        print(f"Error probing {file_path}: {e}")
        return None

    streams = data.get("streams", [])
    format_info = data.get("format", {})

    video_stream = next((s for s in streams if s.get("codec_type") == "video"), None)
    audio_stream = next((s for s in streams if s.get("codec_type") == "audio"), None)

    # Collect all audio streams to detect multi-track and surround sound
    audio_streams = []
    default_audio_idx = 0
    a_idx = 0
    for s in streams:
        if s.get("codec_type") == "audio":
            tags = s.get("tags", {})
            lang = tags.get("language", f"track_{a_idx+1}")
            title = tags.get("title", f"Track {a_idx+1} ({lang.upper()})")
            disposition = s.get("disposition", {})
            is_default = disposition.get("default", 0) == 1
            if is_default:
                default_audio_idx = a_idx
            channels = int(s.get("channels", 2))
            ch_layout = s.get("channel_layout", "stereo")
            audio_streams.append({
                "audio_index": a_idx,
                "stream_index": int(s.get("index", 0)),
                "language": lang,
                "title": title,
                "channels": channels,
                "channel_layout": ch_layout,
                "is_default": is_default
            })
            a_idx += 1

    width = int(video_stream.get("width", 0)) if video_stream else 0
    height = int(video_stream.get("height", 0)) if video_stream else 0

    # Rotation tag handling
    rotation = 0
    if video_stream:
        side_data_list = video_stream.get("side_data_list", [])
        for sd in side_data_list:
            if "rotation" in sd:
                rotation = int(sd["rotation"])
        if "tags" in video_stream and "rotate" in video_stream["tags"]:
            try:
                rotation = int(video_stream["tags"]["rotate"])
            except ValueError:
                pass

    if rotation in [90, 270, -90, -270]:
        width, height = height, width

    duration = float(format_info.get("duration", 0.0))
    if duration <= 0.0 and video_stream:
        duration = float(video_stream.get("duration", 0.0))

    # Guard against truncated/incomplete video files (e.g. partial download or interrupted copy)
    is_truncated = False
    original_duration = duration
    if duration > 5.0 and video_stream:
        chk_target = max(0.0, duration - 2.0)
        chk_cmd = [
            FFMPEG, "-v", "error", "-ss", f"{chk_target:.2f}",
            "-i", str(file_path), "-frames:v", "1", "-f", "null", "-"
        ]
        chk_res = subprocess.run(chk_cmd, capture_output=True, text=True)
        if chk_res.returncode != 0 or "ended prematurely" in chk_res.stderr or "nothing was encoded" in chk_res.stderr:
            is_truncated = True
            low = 0.0
            high = duration
            for _ in range(12):
                mid = (low + high) / 2.0
                mid_cmd = [
                    FFMPEG, "-v", "error", "-ss", f"{mid:.2f}",
                    "-i", str(file_path), "-frames:v", "1", "-f", "null", "-"
                ]
                mid_res = subprocess.run(mid_cmd, capture_output=True, text=True)
                if mid_res.returncode == 0 and "ended prematurely" not in mid_res.stderr and "nothing was encoded" not in mid_res.stderr:
                    low = mid
                else:
                    high = mid
            duration = round(low, 2)

    fps = 30.0
    if video_stream and "r_frame_rate" in video_stream:
        parts = video_stream["r_frame_rate"].split("/")
        if len(parts) == 2 and float(parts[1]) > 0:
            fps = round(float(parts[0]) / float(parts[1]), 2)

    aspect_ratio = f"{width}:{height}"
    if width > 0 and height > 0:
        ratio_val = width / height
        if abs(ratio_val - (16 / 9)) < 0.05:
            aspect_ratio = "16:9 (Landscape)"
        elif abs(ratio_val - (9 / 16)) < 0.05:
            aspect_ratio = "9:16 (Shorts/Vertical)"
        elif abs(ratio_val - 1.0) < 0.05:
            aspect_ratio = "1:1 (Square)"
        elif abs(ratio_val - (4 / 3)) < 0.05:
            aspect_ratio = "4:3 (Standard)"
        else:
            aspect_ratio = f"{width}x{height} ({ratio_val:.2f}:1)"

    size_bytes = int(format_info.get("size", os.path.getsize(file_path)))
    size_mb = f"{size_bytes / (1024 * 1024):.2f} MB"

    return {
        "filepath": str(file_path),
        "filename": os.path.basename(file_path),
        "width": width,
        "height": height,
        "duration": round(duration, 2),
        "duration_formatted": f"{int(duration // 60)}:{int(duration % 60):02d}",
        "fps": fps,
        "aspect_ratio": aspect_ratio,
        "has_video": video_stream is not None,
        "video_codec": video_stream.get("codec_name", "unknown") if video_stream else "none",
        "has_audio": len(audio_streams) > 0,
        "audio_codec": audio_stream.get("codec_name", "unknown") if audio_stream else "none",
        "audio_streams": audio_streams,
        "default_audio_idx": default_audio_idx,
        "size_bytes": size_bytes,
        "size_mb": size_mb,
        "is_truncated": is_truncated,
        "original_duration": round(original_duration, 2),
        "original_duration_formatted": f"{int(original_duration // 60)}:{int(original_duration % 60):02d}",
    }


def plan_clips(source_duration, split_duration, trim_start=0.0, trim_end=None, merge_remainder=True, base_name="video"):
    """
    Computes clip segments strictly according to ShortsSplitter rules:
    - Zero gaps, zero overlaps
    - Hard 180s cap per clip
    - Trailing remainder < 3.0s merged into penultimate clip if sum <= 180s
    """
    if trim_end is None or trim_end <= 0 or trim_end > source_duration:
        trim_end = source_duration
    trim_start = max(0.0, float(trim_start))
    trim_end = min(source_duration, float(trim_end))
    active_duration = max(0.0, trim_end - trim_start)

    if split_duration <= 0 or split_duration >= active_duration:
        return [{
            "index": 1,
            "start": round(trim_start, 3),
            "end": round(trim_end, 3),
            "duration": round(active_duration, 3),
            "name": f"{base_name}_part_001.mp4"
        }]

    segments = []
    current_time = trim_start
    index = 1

    while current_time < trim_end:
        end_time = min(current_time + split_duration, trim_end)
        dur = end_time - current_time
        segments.append({
            "index": index,
            "start": round(current_time, 3),
            "end": round(end_time, 3),
            "duration": round(dur, 3),
            "name": f"{base_name}_part_{index:03d}.mp4"
        })
        current_time = end_time
        index += 1

    if merge_remainder and len(segments) > 1:
        last = segments[-1]
        penultimate = segments[-2]
        if last["duration"] < 3.0 and (penultimate["duration"] + last["duration"]) <= 180.0:
            penultimate["duration"] = round(penultimate["duration"] + last["duration"], 3)
            penultimate["end"] = last["end"]
            segments.pop()

    return segments


def get_bold_font(font_size=52):
    font_candidates = [
        "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf",
        "/usr/share/fonts/truetype/liberation/LiberationSans-Bold.ttf",
        "/usr/share/fonts/truetype/freefont/FreeSansBold.ttf",
        "/usr/share/fonts/truetype/noto/NotoSans-Bold.ttf",
        "/usr/share/fonts/truetype/noto/NotoSans-Regular.ttf",
    ]
    from PIL import ImageFont
    for fp in font_candidates:
        if os.path.exists(fp):
            try:
                return ImageFont.truetype(fp, font_size)
            except Exception:
                pass
    try:
        return ImageFont.load_default(size=font_size)
    except Exception:
        return ImageFont.load_default()


def create_text_overlay_png(text, width=1080, height=1920, position="top_center", font_size=52, out_path=None):
    """
    Renders overlay text into a transparent PNG file.
    Matches ShortsSplitter's OverlayRenderer (universal Unicode & zero-font-dependency support).
    Dynamically scales the pill badge to snugly fit bold, highly legible text without wasted space.
    """
    try:
        from PIL import Image, ImageDraw
        if out_path is None:
            out_path = str(OUTPUTS_DIR / f"overlay_{int(time.time() * 1000)}.png")
        img = Image.new("RGBA", (width, height), (0, 0, 0, 0))
        draw = ImageDraw.Draw(img)

        # Scale font size gracefully based on canvas width (52px for 1080p)
        effective_font_size = max(38, int(width * (font_size / 1080.0)))
        font = get_bold_font(effective_font_size)

        bbox = draw.textbbox((0, 0), text, font=font)
        text_w = bbox[2] - bbox[0]
        text_h = bbox[3] - bbox[1]

        # Snug pill padding matching mobile design tokens
        pad_x = 36
        pad_y = 16
        badge_w = text_w + (pad_x * 2)
        badge_h = text_h + (pad_y * 2)

        # Calculate coordinates based on safe zone presets
        if position == "bottom_center":
            x0 = (width - badge_w) // 2
            y0 = int(height * 0.78)
        elif position == "top_left":
            x0 = 48
            y0 = int(height * 0.14)
        elif position == "top_right":
            x0 = width - badge_w - 48
            y0 = int(height * 0.14)
        else:  # top_center (default YouTube Shorts safe zone)
            x0 = (width - badge_w) // 2
            y0 = int(height * 0.14)

        x1 = x0 + badge_w
        y1 = y0 + badge_h

        # Semi-transparent dark pill background (65% black) with stadium rounded ends
        draw.rounded_rectangle(
            [x0, y0, x1, y1],
            radius=badge_h // 2,
            fill=(15, 17, 26, 210),
            outline=(255, 255, 255, 50),
            width=2
        )

        # Precise text alignment inside the pill
        text_x = x0 + pad_x - bbox[0]
        text_y = y0 + pad_y - bbox[1]

        # Subtle shadow for extra pop over bright video frames
        draw.text((text_x + 2, text_y + 2), text, font=font, fill=(0, 0, 0, 200))
        # Crisp white foreground text
        draw.text((text_x, text_y), text, font=font, fill=(255, 255, 255, 255))

        img.save(out_path, "PNG")
        return out_path
    except Exception as e:
        print(f"Overlay creation failed: {e}")
        return None


def build_ffmpeg_command(
    input_path,
    output_path,
    start,
    duration,
    mode="blur_background",
    aspect_ratio="9:16",
    bg_color="black",
    vertical_align="center",
    overlay_text=None,
    overlay_position="top_center",
    font_size=52,
    clip_idx=1,
    total_clips=1,
    audio_track_idx=0,
    resolution="1080p"
):
    """
    Builds the FFmpeg command matching ShortsSplitter FilterGraphBuilder:
    Supports 1080p (Full HD) and 4K (Ultra HD) output resolutions.
    CRITICAL: ALWAYS maps video with -map 0:v (or -map [outv]) AND a SINGLE stereo audio track
    (-map 0:a:{idx}?, -ac 2, -ar 48000) to guarantee 100% Android & YouTube Shorts compliance.
    """
    # Safe audio mapping: exactly 1 audio stream, preventing multi-track breakage in mobile apps
    audio_map = f"0:a:{audio_track_idx}?" if audio_track_idx is not None else "0:a:0?"

    # Resolve target canvas dimensions based on aspect ratio and resolution
    is_4k = (resolution == "4k")
    if is_4k:
        if aspect_ratio == "1:1":
            target_w, target_h = 2160, 2160
        elif aspect_ratio == "16:9":
            target_w, target_h = 3840, 2160
        elif aspect_ratio == "4:5":
            target_w, target_h = 2160, 2700
        elif aspect_ratio == "original" or mode == "original":
            meta = probe_video(input_path)
            if meta and meta.get("width") and meta.get("height"):
                target_w = (int(meta["width"]) // 2) * 2
                target_h = (int(meta["height"]) // 2) * 2
            else:
                target_w, target_h = 3840, 2160
        else:  # 9:16 4K Shorts/Reels/TikTok
            target_w, target_h = 2160, 3840
        h264_level = "5.1"
        crf_val = "18"  # Visually lossless cinema mastering quality for 4K
        audio_bitrate = "320k"
    else:
        if aspect_ratio == "1:1":
            target_w, target_h = 1080, 1080
        elif aspect_ratio == "16:9":
            target_w, target_h = 1920, 1080
        elif aspect_ratio == "4:5":
            target_w, target_h = 1080, 1350
        elif aspect_ratio == "original" or mode == "original":
            meta = probe_video(input_path)
            if meta and meta.get("width") and meta.get("height"):
                target_w = (int(meta["width"]) // 2) * 2
                target_h = (int(meta["height"]) // 2) * 2
            else:
                target_w, target_h = 1920, 1080
        else:  # 9:16 standard 1080p Shorts/Reels/TikTok
            target_w, target_h = 1080, 1920
        h264_level = "4.1"
        crf_val = "22"  # Balanced high quality standard
        audio_bitrate = "192k"

    # Sanitize color string for FFmpeg pad filter
    color_val = bg_color.strip() if bg_color else "black"
    if color_val.startswith("#"):
        color_val = f"0x{color_val[1:]}"
    elif color_val.lower() == "dark grey" or color_val.lower() == "dark grey":
        color_val = "0x212121"

    # Vertical alignment expression for pad and overlay filters
    if vertical_align == "top":
        pad_y = "0"
        overlay_y = "0"
    elif vertical_align == "bottom":
        pad_y = "(oh-ih)"
        overlay_y = "(H-h)"
    else:  # center
        pad_y = "(oh-ih)/2"
        overlay_y = "(H-h)/2"

    cmd = [
        FFMPEG,
        "-y",
        "-ss", f"{start:.3f}",
        "-i", input_path,
    ]

    overlay_png = None
    if overlay_text:
        text = overlay_text.replace("{n}", str(clip_idx)).replace("{total}", str(total_clips))
        overlay_png = create_text_overlay_png(text, target_w, target_h, position=overlay_position, font_size=font_size)
        if overlay_png:
            cmd.extend(["-i", overlay_png])

    cmd.extend(["-t", f"{duration:.3f}"])

    if overlay_png:
        # Complex filter overlay with PNG
        if mode == "crop_to_fill":
            fc = (
                f"[0:v]scale={target_w}:{target_h}:force_original_aspect_ratio=increase,crop={target_w}:{target_h},setsar=1[v_base];"
                f"[v_base][1:v]overlay=0:0[outv]"
            )
        elif mode == "blur_background":
            fc = (
                f"[0:v]scale=108:192:force_original_aspect_ratio=increase,crop=108:192,boxblur=5:1,scale={target_w}:{target_h}:flags=bicubic[bg];"
                f"[0:v]scale={target_w}:{target_h}:force_original_aspect_ratio=decrease,scale=trunc(iw/2)*2:trunc(ih/2)*2[fg];"
                f"[bg][fg]overlay=(W-w)/2:{overlay_y},setsar=1[v_base];"
                f"[v_base][1:v]overlay=0:0[outv]"
            )
        elif mode == "solid_color" or mode == "black_letterbox":
            fc = (
                f"[0:v]scale={target_w}:{target_h}:force_original_aspect_ratio=decrease,scale=trunc(iw/2)*2:trunc(ih/2)*2,pad={target_w}:{target_h}:(ow-iw)/2:{pad_y}:color={color_val},setsar=1[v_base];"
                f"[v_base][1:v]overlay=0:0[outv]"
            )
        else:
            fc = (
                f"[0:v]scale=trunc(iw/2)*2:trunc(ih/2)*2,setsar=1[v_base];"
                f"[v_base][1:v]overlay=0:0[outv]"
            )

        cmd.extend([
            "-filter_complex", fc,
            "-map", "[outv]",
            "-map", audio_map,
        ])
    else:
        # Standard filter without PNG overlay
        if mode == "crop_to_fill":
            vf = f"scale={target_w}:{target_h}:force_original_aspect_ratio=increase,crop={target_w}:{target_h},setsar=1"
            cmd.extend([
                "-vf", vf,
                "-map", "0:v",
                "-map", audio_map,
            ])
        elif mode == "blur_background":
            fc = (
                f"[0:v]scale=108:192:force_original_aspect_ratio=increase,crop=108:192,boxblur=5:1,scale={target_w}:{target_h}:flags=bicubic[bg];"
                f"[0:v]scale={target_w}:{target_h}:force_original_aspect_ratio=decrease,scale=trunc(iw/2)*2:trunc(ih/2)*2[fg];"
                f"[bg][fg]overlay=(W-w)/2:{overlay_y},setsar=1[outv]"
            )
            cmd.extend([
                "-filter_complex", fc,
                "-map", "[outv]",
                "-map", audio_map,
            ])
        elif mode == "solid_color" or mode == "black_letterbox":
            vf = f"scale={target_w}:{target_h}:force_original_aspect_ratio=decrease,scale=trunc(iw/2)*2:trunc(ih/2)*2,pad={target_w}:{target_h}:(ow-iw)/2:{pad_y}:color={color_val},setsar=1"
            cmd.extend([
                "-vf", vf,
                "-map", "0:v",
                "-map", audio_map,
            ])
        else:
            vf = "scale=trunc(iw/2)*2:trunc(ih/2)*2,setsar=1"
            cmd.extend([
                "-vf", vf,
                "-map", "0:v",
                "-map", audio_map,
            ])

    # YouTube Shorts & Android 100% compliant encoding settings:
    # 1. H.264 High Profile (Level 4.1 for 1080p, Level 5.1 for 4K) with 2-second keyframe GOP interval
    # 2. AAC Stereo (2-channel downmix, 48kHz, 192k for 1080p, 320k for 4K) preventing surround failures
    # 3. MOOV atom at head (+faststart) for instant playback
    cmd.extend([
        "-c:v", "libx264",
        "-profile:v", "high",
        "-level", h264_level,
        "-preset", "veryfast",
        "-crf", crf_val,
        "-g", "48",
        "-keyint_min", "24",
        "-pix_fmt", "yuv420p",
        "-c:a", "aac",
        "-b:a", audio_bitrate,
        "-ac", "2",
        "-ar", "48000",
        "-movflags", "+faststart",
        "-max_muxing_queue_size", "1024",
        output_path
    ])

    return cmd


class ShortsTesterRequestHandler(http.server.SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=str(BASE_DIR), **kwargs)

    def do_HEAD(self):
        url = urllib.parse.urlparse(self.path)
        path = url.path
        if path.startswith("/api/video/"):
            clip_name = path[len("/api/video/"):]
            clip_path = OUTPUTS_DIR / clip_name
            if clip_path.exists():
                file_size = clip_path.stat().st_size
                self.send_response(200)
                self.send_header("Content-Type", "video/mp4")
                self.send_header("Content-Length", str(file_size))
                self.send_header("Accept-Ranges", "bytes")
                self.end_headers()
                return
        elif path == "/api/video_raw":
            query = urllib.parse.parse_qs(url.query)
            target = query.get("path", [None])[0]
            if target and os.path.exists(target):
                file_size = os.path.getsize(target)
                self.send_response(200)
                self.send_header("Content-Type", "video/mp4")
                self.send_header("Content-Length", str(file_size))
                self.send_header("Accept-Ranges", "bytes")
                self.end_headers()
                return
        super().do_HEAD()

    def do_GET(self):
        url = urllib.parse.urlparse(self.path)
        path = url.path

        if path == "/" or path == "/index.html":
            self.send_file(BASE_DIR / "index.html", "text/html")
            return

        if path == "/api/status":
            self.send_json({
                "status": "ok",
                "ffmpeg": FFMPEG,
                "ffprobe": FFPROBE,
                "python": sys.version.split()[0]
            })
            return

        if path == "/api/samples":
            samples = []
            seen = set()
            for p in list(PROJECT_DIR.glob("*.mp4")) + list(SAMPLES_DIR.glob("*.mp4")) + list(Path("/tmp/test_video").glob("*.mp4")):
                if str(p) in seen:
                    continue
                seen.add(str(p))
                meta = probe_video(p)
                if meta and meta.get("has_video"):
                    meta["sample_url"] = f"/api/video_raw?path={urllib.parse.quote(str(p))}"
                    samples.append(meta)
            self.send_json({"samples": samples})
            return

        if path.startswith("/api/video/"):
            clip_name = path[len("/api/video/"):]
            clip_path = OUTPUTS_DIR / clip_name
            self.stream_video(clip_path)
            return

        if path == "/api/video_raw":
            query = urllib.parse.parse_qs(url.query)
            target = query.get("path", [None])[0]
            if target and os.path.exists(target):
                self.stream_video(Path(target))
            else:
                self.send_error(404, "File not found")
            return

        if path.startswith("/api/download/"):
            clip_name = path[len("/api/download/"):]
            clip_path = OUTPUTS_DIR / clip_name
            if clip_path.exists():
                self.download_file(clip_path)
            else:
                self.send_error(404, "File not found")
            return

        super().do_GET()

    def do_POST(self):
        url = urllib.parse.urlparse(self.path)
        path = url.path

        if path == "/api/upload":
            self.handle_upload()
            return

        if path == "/api/probe":
            self.handle_probe()
            return

        if path == "/api/plan":
            self.handle_plan()
            return

        if path == "/api/process_single":
            self.handle_process_single()
            return

        if path == "/api/process":
            self.handle_process()
            return

        self.send_error(404, "Endpoint not found")

    def handle_upload(self):
        """Handles video file upload using multipart/form-data."""
        content_type = self.headers.get("Content-Type", "")
        if not content_type.startswith("multipart/form-data"):
            self.send_json({"error": "Expected multipart/form-data"}, status=400)
            return

        form = cgi.FieldStorage(
            fp=self.rfile,
            headers=self.headers,
            environ={"REQUEST_METHOD": "POST", "CONTENT_TYPE": content_type}
        )

        if "file" not in form:
            self.send_json({"error": "No file field in form"}, status=400)
            return

        file_item = form["file"]
        if not file_item.filename:
            self.send_json({"error": "Empty filename"}, status=400)
            return

        safe_name = re.sub(r'[^a-zA-Z0-9_.-]', '_', os.path.basename(file_item.filename))
        out_path = UPLOADS_DIR / safe_name
        with open(out_path, "wb") as f:
            f.write(file_item.file.read())

        meta = probe_video(out_path)
        if not meta:
            self.send_json({"error": "Uploaded file is not a valid video"}, status=400)
            return

        meta["sample_url"] = f"/api/video_raw?path={urllib.parse.quote(str(out_path))}"
        self.send_json({"success": True, "metadata": meta})

    def handle_probe(self):
        """Probes a file path given in JSON body."""
        data = self.read_json_body()
        file_path = data.get("filepath")
        if not file_path or not os.path.exists(file_path):
            self.send_json({"error": "File does not exist"}, status=400)
            return

        meta = probe_video(file_path)
        if not meta:
            self.send_json({"error": "Failed to probe video file"}, status=400)
            return

        meta["sample_url"] = f"/api/video_raw?path={urllib.parse.quote(str(file_path))}"
        self.send_json({"success": True, "metadata": meta})

    def handle_plan(self):
        """Plans clip segments based on input video duration and split options."""
        data = self.read_json_body()
        file_path = data.get("filepath")
        if not file_path or not os.path.exists(file_path):
            self.send_json({"error": "File not found"}, status=400)
            return

        split_dur = float(data.get("split_duration", 0))
        trim_start = float(data.get("trim_start", 0.0))
        trim_end = data.get("trim_end")
        if trim_end is not None:
            trim_end = float(trim_end)
        merge_remainder = bool(data.get("merge_remainder", True))
        custom_base = data.get("custom_base_name") or Path(file_path).stem
        custom_base = re.sub(r'[^a-zA-Z0-9_-]', '_', custom_base)

        source_meta = probe_video(file_path)
        if not source_meta:
            self.send_json({"error": "Could not read video metadata"}, status=400)
            return

        segments = plan_clips(
            source_duration=source_meta["duration"],
            split_duration=split_dur,
            trim_start=trim_start,
            trim_end=trim_end,
            merge_remainder=merge_remainder,
            base_name=custom_base
        )
        self.send_json({
            "success": True,
            "total_clips": len(segments),
            "segments": segments,
            "source_meta": source_meta
        })

    def handle_process_single(self):
        """Processes a single clip segment and returns its metadata."""
        data = self.read_json_body()
        file_path = data.get("filepath")
        if not file_path or not os.path.exists(file_path):
            self.send_json({"error": "Input file not found"}, status=400)
            return

        mode = data.get("mode", "blur_background")
        aspect_ratio = data.get("aspect_ratio", "9:16")
        bg_color = data.get("bg_color", "black")
        vertical_align = data.get("vertical_align", "center")
        overlay_position = data.get("overlay_position", "top_center")
        font_size = int(data.get("font_size", 52))

        seg = data.get("segment", {})
        idx = int(seg.get("index", 1))
        start = float(seg.get("start", 0.0))
        duration = float(seg.get("duration", 0.0))
        total_clips = int(data.get("total_clips", 1))
        overlay_text = data.get("overlay_text")
        if overlay_text and overlay_text.strip() == "":
            overlay_text = None

        custom_base = data.get("custom_base_name") or Path(file_path).stem
        base_name = re.sub(r'[^a-zA-Z0-9_-]', '_', custom_base)
        timestamp = int(time.time())
        pad_width = max(3, len(str(total_clips)))

        clip_name = f"{base_name}_part_{idx:0{pad_width}d}_{timestamp}.mp4"
        out_clip_path = str(OUTPUTS_DIR / clip_name)

        audio_track_idx = data.get("audio_track_idx")
        if audio_track_idx is not None:
            audio_track_idx = int(audio_track_idx)
        else:
            source_meta = probe_video(file_path)
            audio_track_idx = source_meta.get("default_audio_idx", 0) if source_meta else 0

        resolution = data.get("resolution", "1080p")

        cmd = build_ffmpeg_command(
            input_path=file_path,
            output_path=out_clip_path,
            start=start,
            duration=duration,
            mode=mode,
            aspect_ratio=aspect_ratio,
            bg_color=bg_color,
            vertical_align=vertical_align,
            overlay_text=overlay_text,
            overlay_position=overlay_position,
            font_size=font_size,
            clip_idx=idx,
            total_clips=total_clips,
            audio_track_idx=audio_track_idx,
            resolution=resolution
        )

        t0 = time.time()
        try:
            subprocess.run(cmd, check=True, capture_output=True, text=True)
        except subprocess.CalledProcessError as err:
            stderr = err.stderr or ""
            if "ended prematurely" in stderr or "Output file is empty" in stderr or "Invalid argument" in stderr or "nothing was encoded" in stderr:
                if os.path.exists(out_clip_path):
                    try:
                        os.remove(out_clip_path)
                    except Exception:
                        pass
                self.send_json({
                    "success": False,
                    "eof_reached": True,
                    "error": f"Source video ended at clip {idx}."
                }, status=200)
                return

            self.send_json({
                "error": f"FFmpeg processing failed on clip {idx}: {stderr[:300]}"
            }, status=500)
            return

        proc_time = round(time.time() - t0, 2)

        clip_meta = probe_video(out_clip_path)
        clip_file_size = os.path.getsize(out_clip_path) if os.path.exists(out_clip_path) else 0
        if not clip_meta or not clip_meta.get("has_video") or clip_file_size < 2048:
            if os.path.exists(out_clip_path):
                try:
                    os.remove(out_clip_path)
                except Exception:
                    pass
            self.send_json({
                "success": False,
                "eof_reached": True,
                "error": f"Clip {idx} reached end of available media in source video."
            }, status=200)
            return

        clip_data = {
            "index": idx,
            "name": clip_name,
            "start": start,
            "duration": duration,
            "resolution": f"{clip_meta['width']}x{clip_meta['height']}",
            "aspect_ratio": clip_meta["aspect_ratio"],
            "size_mb": clip_meta["size_mb"],
            "has_video": clip_meta["has_video"],
            "has_audio": clip_meta["has_audio"],
            "video_codec": clip_meta["video_codec"],
            "url": f"/api/video/{clip_name}",
            "download_url": f"/api/download/{clip_name}",
            "processing_time": f"{proc_time}s"
        }

        self.send_json({
            "success": True,
            "clip": clip_data
        })

    def handle_process(self):
        """Processes video splitting and 9:16 conversion."""
        data = self.read_json_body()
        file_path = data.get("filepath")
        if not file_path or not os.path.exists(file_path):
            self.send_json({"error": "Input file not found"}, status=400)
            return

        mode = data.get("mode", "blur_background")
        split_dur = float(data.get("split_duration", 0))
        merge_remainder = bool(data.get("merge_remainder", True))
        overlay_text = data.get("overlay_text")
        if overlay_text and overlay_text.strip() == "":
            overlay_text = None

        source_meta = probe_video(file_path)
        if not source_meta:
            self.send_json({"error": "Could not read video metadata"}, status=400)
            return

        segments = plan_clips(source_meta["duration"], split_dur, merge_remainder)
        total_clips = len(segments)

        base_name = Path(file_path).stem
        base_name = re.sub(r'[^a-zA-Z0-9_-]', '_', base_name)
        timestamp = int(time.time())

        clips_result = []
        pad_width = max(3, len(str(total_clips)))

        start_time_all = time.time()
        audio_track_idx = data.get("audio_track_idx")
        if audio_track_idx is not None:
            audio_track_idx = int(audio_track_idx)
        else:
            audio_track_idx = source_meta.get("default_audio_idx", 0)

        for seg in segments:
            idx = seg["index"]
            clip_name = f"{base_name}_part_{idx:0{pad_width}d}_{timestamp}.mp4"
            out_clip_path = str(OUTPUTS_DIR / clip_name)

            cmd = build_ffmpeg_command(
                input_path=file_path,
                output_path=out_clip_path,
                start=seg["start"],
                duration=seg["duration"],
                mode=mode,
                overlay_text=overlay_text,
                clip_idx=idx,
                total_clips=total_clips,
                audio_track_idx=audio_track_idx
            )

            print(f"Executing: {' '.join(cmd)}")
            t0 = time.time()
            try:
                subprocess.run(cmd, check=True, capture_output=True, text=True)
            except subprocess.CalledProcessError as err:
                print(f"FFmpeg error: {err.stderr}")
                self.send_json({
                    "error": f"FFmpeg processing failed on clip {idx}: {err.stderr[:300]}"
                }, status=500)
                return

            proc_time = round(time.time() - t0, 2)

            # Probe generated clip to ensure video is valid
            clip_meta = probe_video(out_clip_path)
            if not clip_meta or not clip_meta.get("has_video"):
                self.send_json({
                    "error": f"Clip {idx} was generated without a valid video stream (black screen defect prevented)."
                }, status=500)
                return

            clips_result.append({
                "index": idx,
                "name": clip_name,
                "start": seg["start"],
                "duration": seg["duration"],
                "resolution": f"{clip_meta['width']}x{clip_meta['height']}",
                "aspect_ratio": clip_meta["aspect_ratio"],
                "size_mb": clip_meta["size_mb"],
                "has_video": clip_meta["has_video"],
                "has_audio": clip_meta["has_audio"],
                "video_codec": clip_meta["video_codec"],
                "url": f"/api/video/{clip_name}",
                "download_url": f"/api/download/{clip_name}",
                "processing_time": f"{proc_time}s"
            })

        total_proc_time = round(time.time() - start_time_all, 2)

        self.send_json({
            "success": True,
            "total_clips": total_clips,
            "clips": clips_result,
            "mode": mode,
            "total_processing_time": f"{total_proc_time}s"
        })

    def stream_video(self, file_path):
        """Streams a video file supporting HTTP Range requests for instant HTML5 playback."""
        if not file_path.exists():
            self.send_error(404, "File not found")
            return

        file_size = file_path.stat().st_size
        range_header = self.headers.get("Range")

        if not range_header:
            self.send_response(200)
            self.send_header("Content-Type", "video/mp4")
            self.send_header("Content-Length", str(file_size))
            self.send_header("Accept-Ranges", "bytes")
            self.end_headers()
            with open(file_path, "rb") as f:
                shutil.copyfileobj(f, self.wfile)
            return

        # Parse range header
        match = re.match(r"bytes=(\d+)-(\d*)", range_header)
        if not match:
            self.send_error(416, "Requested Range Not Satisfiable")
            return

        start = int(match.group(1))
        end = int(match.group(2)) if match.group(2) else file_size - 1

        if start >= file_size or end >= file_size or start > end:
            self.send_response(416)
            self.send_header("Content-Range", f"bytes */{file_size}")
            self.end_headers()
            return

        chunk_size = end - start + 1
        self.send_response(206)
        self.send_header("Content-Type", "video/mp4")
        self.send_header("Content-Range", f"bytes {start}-{end}/{file_size}")
        self.send_header("Content-Length", str(chunk_size))
        self.send_header("Accept-Ranges", "bytes")
        self.end_headers()

        with open(file_path, "rb") as f:
            f.seek(start)
            bytes_left = chunk_size
            while bytes_left > 0:
                buf = f.read(min(bytes_left, 65536))
                if not buf:
                    break
                self.wfile.write(buf)
                bytes_left -= len(buf)

    def download_file(self, file_path):
        file_size = file_path.stat().st_size
        try:
            self.send_response(200)
            self.send_header("Content-Type", "application/octet-stream")
            self.send_header("Content-Disposition", f'attachment; filename="{file_path.name}"')
            self.send_header("Content-Length", str(file_size))
            self.end_headers()
            with open(file_path, "rb") as f:
                shutil.copyfileobj(f, self.wfile)
        except (BrokenPipeError, ConnectionResetError):
            pass

    def send_file(self, path, mime_type):
        if not path.exists():
            self.send_error(404, "File not found")
            return
        content = path.read_bytes()
        try:
            self.send_response(200)
            self.send_header("Content-Type", mime_type)
            self.send_header("Content-Length", str(len(content)))
            self.end_headers()
            self.wfile.write(content)
        except (BrokenPipeError, ConnectionResetError):
            pass

    def send_json(self, data, status=200):
        body = json.dumps(data, indent=2).encode("utf-8")
        try:
            self.send_response(status)
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(body)))
            self.send_header("Access-Control-Allow-Origin", "*")
            self.end_headers()
            self.wfile.write(body)
        except (BrokenPipeError, ConnectionResetError):
            pass

    def read_json_body(self):
        length = int(self.headers.get("Content-Length", 0))
        if length <= 0:
            return {}
        raw = self.rfile.read(length)
        try:
            return json.loads(raw.decode("utf-8"))
        except Exception:
            return {}


def run_server(port=8080):
    server_address = ("", port)
    try:
        httpd = http.server.ThreadingHTTPServer(server_address, ShortsTesterRequestHandler)
    except OSError:
        port = 8081
        server_address = ("", port)
        httpd = http.server.ThreadingHTTPServer(server_address, ShortsTesterRequestHandler)

    print("=" * 65)
    print(" 🚀 ShortsSplitter Local Web Tester & Laboratory")
    print(f" 🌐 Open in browser: http://localhost:{port}")
    print(f" 🎬 FFmpeg Engine:   {FFMPEG}")
    print(f" 📂 Working Dir:     {BASE_DIR}")
    print("=" * 65)
    try:
        httpd.serve_forever()
    except KeyboardInterrupt:
        print("\nStopping server...")
        httpd.server_close()


if __name__ == "__main__":
    port_arg = int(sys.argv[1]) if len(sys.argv) > 1 else 8080
    run_server(port_arg)
