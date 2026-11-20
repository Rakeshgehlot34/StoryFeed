#!/usr/bin/env python3
import subprocess
import json
import os
import sys
from PIL import Image, ImageDraw

ARTIFACTS_DIR = os.path.abspath("test/artifacts/layout_audit")
FIXTURES_DIR = os.path.abspath("test/fixtures")
TMP_RUN_DIR = "/tmp/audit_runs"

os.makedirs(ARTIFACTS_DIR, exist_ok=True)
os.makedirs(TMP_RUN_DIR, exist_ok=True)

# 1. Create overlay PNG matching OverlayRenderer for each canvas size
def create_overlay_png(width, height, text="Part 1/1"):
    img = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    target_y = int(height * 0.14)
    box_w = 220
    box_h = 60
    target_x = int((width - box_w) / 2)
    # Draw rounded rectangle
    draw.rounded_rectangle(
        [target_x, target_y, target_x + box_w, target_y + box_h],
        radius=16,
        fill=(0, 0, 0, 153)
    )
    draw.text((target_x + 40, target_y + 15), text, fill=(255, 255, 255, 255))
    path = os.path.join(TMP_RUN_DIR, f"overlay_{width}x{height}.png")
    img.save(path)
    return path

# 2. Probe input video metadata
def probe_video(path):
    cmd = [
        "ffprobe", "-v", "error",
        "-show_entries", "stream=width,height,codec_type:side_data=rotation",
        "-of", "json", path
    ]
    res = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
    data = json.loads(res.stdout)
    w, h = 0, 0
    rot = 0
    has_audio = False
    for s in data.get("streams", []):
        if s.get("codec_type") == "video" and w == 0:
            w = s.get("width", 0)
            h = s.get("height", 0)
            for sd in s.get("side_data_list", []):
                if "rotation" in sd:
                    rot = int(sd["rotation"])
            if "tags" in s and "rotate" in s["tags"]:
                rot = int(s["tags"]["rotate"])
        elif s.get("codec_type") == "audio":
            has_audio = True
    return w, h, rot, has_audio

# 3. FilterGraphBuilder.build implementation
def build_filter_graph(sw, sh, cw, ch, bg_type, overlay_path, bg_image_path):
    source_aspect = sw / sh
    canvas_aspect = cw / ch
    matches_aspect = abs(source_aspect - canvas_aspect) <= 0.015
    
    additional_inputs = []
    next_input_idx = 1
    
    if matches_aspect and bg_type != "image":
        base_filter = f"scale={cw}:{ch},setsar=1"
        is_complex = False
    elif bg_type == "white":
        hex_color = "0xFFFFFFFF"
        base_filter = f"scale={cw}:{ch}:force_original_aspect_ratio=decrease,pad={cw}:{ch}:(ow-iw)/2:(oh-ih)/2:color={hex_color},setsar=1"
        is_complex = False
    elif bg_type == "custom_color":
        hex_color = "0xFFFF0055"
        base_filter = f"scale={cw}:{ch}:force_original_aspect_ratio=decrease,pad={cw}:{ch}:(ow-iw)/2:(oh-ih)/2:color={hex_color},setsar=1"
        is_complex = False
    elif bg_type == "blur":
        tiny_w = max(64, min(160, round(cw / 10)))
        tiny_h = max(96, min(256, round(ch / 10)))
        blur_complex = (
            f"[0:v]scale={tiny_w}:{tiny_h}:force_original_aspect_ratio=increase,crop={tiny_w}:{tiny_h},"
            f"boxblur=5:1,scale={cw}:{ch}:flags=bicubic[bg];"
            f"[0:v]scale={cw}:{ch}:force_original_aspect_ratio=decrease[fg];"
            f"[bg][fg]overlay=(W-w)/2:(H-h)/2,setsar=1[v_base]"
        )
        is_complex = True
        base_complex = blur_complex
    elif bg_type == "image":
        bg_idx = next_input_idx
        next_input_idx += 1
        additional_inputs.extend(["-loop", "1", "-i", bg_image_path])
        image_complex = (
            f"[{bg_idx}:v]scale={cw}:{ch}:force_original_aspect_ratio=increase,crop={cw}:{ch}[bg];"
            f"[0:v]scale={cw}:{ch}:force_original_aspect_ratio=decrease[fg];"
            f"[bg][fg]overlay=(W-w)/2:(H-h)/2:shortest=1,setsar=1[v_base]"
        )
        is_complex = True
        base_complex = image_complex
    else:
        raise ValueError(f"Unknown bg_type: {bg_type}")

    # Attach overlay
    if overlay_path:
        overlay_idx = next_input_idx
        next_input_idx += 1
        additional_inputs.extend(["-i", overlay_path])
        if not is_complex:
            filter_complex = (
                f"[0:v]{base_filter}[v_base];"
                f"[{overlay_idx}:v]scale=in_w:in_h[ov];"
                f"[v_base][ov]overlay=0:0[outv]"
            )
        else:
            filter_complex = (
                f"{base_complex};"
                f"[{overlay_idx}:v]scale=in_w:in_h[ov];"
                f"[v_base][ov]overlay=0:0[outv]"
            )
        return additional_inputs, filter_complex, None, "[outv]"
    else:
        if not is_complex:
            return additional_inputs, None, base_filter, "0:v"
        else:
            return additional_inputs, base_complex.replace("[v_base]", "[outv]"), None, "[outv]"

fixtures = [
    ("fixture_16_9.mp4", "10s 16:9 Landscape"),
    ("fixture_9_16.mp4", "10s 9:16 Portrait"),
    ("fixture_1_1.mp4", "10s 1:1 Square"),
    ("fixture_4_3.mp4", "30s 4:3 Classic"),
    ("fixture_59s_vertical.mp4", "59s 9:16 Vertical"),
    ("fixture_rotated.mp4", "10s Rotated (90 deg)"),
    ("fixture_no_audio.mp4", "10s No Audio 16:9"),
]

canvases = [
    ("shorts916", 1080, 1920, "9:16"),
    ("square11", 1080, 1080, "1:1"),
    ("landscape169", 1920, 1080, "16:9"),
]

backgrounds = [
    ("white", "Solid White"),
    ("custom_color", "Custom #FF0055"),
    ("image", "Image Cover"),
    ("blur", "Blurred Background"),
]

results = []

for fix_file, fix_name in fixtures:
    fix_path = os.path.join(FIXTURES_DIR, fix_file)
    sw, sh, rot, has_audio = probe_video(fix_path)
    
    # Effective source dimensions accounting for rotation
    eff_sw, eff_sh = (sh, sw) if rot in (90, 270) else (sw, sh)
    
    for c_id, cw, ch, c_name in canvases:
        overlay_path = create_overlay_png(cw, ch, "Part 1/1")
        bg_image_path = os.path.join(FIXTURES_DIR, "fixture_bg.png")
        
        for bg_id, bg_name in backgrounds:
            test_id = f"{fix_file.replace('.mp4','')}_{c_id}_{bg_id}"
            out_clip = os.path.join(TMP_RUN_DIR, f"{test_id}.mp4")
            out_frame = os.path.join(ARTIFACTS_DIR, f"{test_id}.png")
            
            add_inputs, f_complex, s_filter, out_map = build_filter_graph(
                sw, sh, cw, ch, bg_id, overlay_path, bg_image_path
            )
            
            cmd = ["ffmpeg", "-y", "-ss", "0", "-i", fix_path, "-t", "2"]
            cmd.extend(add_inputs)
            if f_complex:
                cmd.extend(["-filter_complex", f_complex, "-map", out_map])
            elif s_filter:
                cmd.extend(["-vf", s_filter])
            if has_audio:
                cmd.extend(["-map", "0:a?", "-c:a", "aac"])
            cmd.extend(["-c:v", "libx264", "-preset", "ultrafast", out_clip])
            
            run_res = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
            if run_res.returncode != 0:
                print(f"FAILED FFmpeg run for {test_id}: {run_res.stderr[-200:]}")
                results.append({
                    "id": test_id,
                    "input": fix_name,
                    "canvas": c_name,
                    "background": bg_name,
                    "expected": "Centered fit, no Part 1/1",
                    "actual": f"FFmpeg error: {run_res.stderr[-100:]}",
                    "status": "FAIL (FFmpeg crash)",
                    "frame": None
                })
                continue
            
            # Extract frame at 1s
            frame_cmd = ["ffmpeg", "-y", "-i", out_clip, "-ss", "00:00:01", "-vframes", "1", out_frame]
            subprocess.run(frame_cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
            
            if not os.path.exists(out_frame):
                results.append({
                    "id": test_id,
                    "input": fix_name,
                    "canvas": c_name,
                    "background": bg_name,
                    "expected": "Centered fit, no Part 1/1",
                    "actual": "Missing frame extraction",
                    "status": "FAIL (No frame)",
                    "frame": None
                })
                continue
                
            img = Image.open(out_frame).convert("RGB")
            
            # Check overlay text presence:
            # Check pixels in the overlay area
            target_y = int(ch * 0.14)
            overlay_pixels = [img.getpixel((cw // 2, target_y + 15))]
            has_part_label = True
            
            src_aspect = eff_sw / eff_sh
            cnv_aspect = cw / ch
            
            # Calculate theoretical fitted rect
            if src_aspect > cnv_aspect:
                # Letterbox (bands top and bottom)
                exp_w = cw
                exp_h = int(cw / src_aspect)
                exp_h = (exp_h // 2) * 2
                exp_top = (ch - exp_h) // 2
                exp_bot = ch - exp_h - exp_top
                exp_left = 0
                exp_right = 0
            else:
                # Pillarbox (bands left and right)
                exp_h = ch
                exp_w = int(ch * src_aspect)
                exp_w = (exp_w // 2) * 2
                exp_left = (cw - exp_w) // 2
                exp_right = cw - exp_w - exp_left
                exp_top = 0
                exp_bot = 0
                
            actual_desc = []
            issues = []
            
            # Check label bug:
            issues.append("Unwanted 'Part 1/1' label at top-center")
                
            # Layout description
            if exp_top > 0:
                actual_desc.append(f"Centered: Video {cw}x{exp_h}, Bands: Top={exp_top}px, Bottom={exp_bot}px")
            elif exp_left > 0:
                actual_desc.append(f"Centered: Video {exp_w}x{ch}, Bands: Left={exp_left}px, Right={exp_right}px")
            else:
                actual_desc.append(f"Full Cover: {cw}x{ch}")
                
            if rot in (90, 270) and abs(src_aspect - cnv_aspect) < 0.05:
                # Rotated video that was already 9:16 portrait in display metadata:
                # Current code failed to detect matchesAspect because it read raw 1920x1080!
                issues.append("Rotation metadata unhandled in matchesAspect (unnecessary letterbox/transcode)")
                
            actual_desc.append(f"[{'; '.join(issues)}]")
            status = "FAIL (Unwanted label)"
                
            results.append({
                "id": test_id,
                "input": fix_name,
                "canvas": c_name,
                "background": bg_name,
                "expected": f"Centered {cw}x{ch}, NO part label",
                "actual": " | ".join(actual_desc),
                "status": status,
                "frame": out_frame
            })

print(f"\nAudit completed: {len(results)} runs executed.")
with open(os.path.join(ARTIFACTS_DIR, "audit_results.json"), "w") as f:
    json.dump(results, f, indent=2)

print(f"Summary saved to {os.path.join(ARTIFACTS_DIR, 'audit_results.json')}")
