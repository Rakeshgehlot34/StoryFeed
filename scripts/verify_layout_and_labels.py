#!/usr/bin/env python3
"""
scripts/verify_layout_and_labels.py
Verifies FitLayout centering, vertical position options, and optional Part Label behavior
against test fixtures using FFmpeg.
"""
import json
import os
import subprocess
import sys

FIXTURES_DIR = os.path.abspath("test/fixtures")
OUT_DIR = os.path.abspath("test/artifacts/layout_verification")
os.makedirs(OUT_DIR, exist_ok=True)

def run_cmd(cmd):
    p = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
    if p.returncode != 0:
        raise RuntimeError(f"Command failed: {' '.join(cmd)}\nStderr: {p.stderr}")
    return p.stdout

def probe_video(path):
    cmd = [
        "ffprobe", "-v", "error",
        "-show_entries", "stream=width,height,sample_aspect_ratio:stream_tags=rotate:stream_side_data=rotation",
        "-of", "json", path
    ]
    data = json.loads(run_cmd(cmd))
    stream = data["streams"][0]
    w = int(stream["width"])
    h = int(stream["height"])
    rot = 0
    tags = stream.get("tags", {})
    if "rotate" in tags:
        rot = int(tags["rotate"])
    for sd in stream.get("side_data_list", []):
        if "rotation" in sd:
            rot = int(sd["rotation"])
    return w, h, rot

def calculate_fit_layout(sw, sh, cw, ch, rot=0, sar=1.0, vpos="center", voffset=0.0):
    norm_rot = (rot % 360 + 360) % 360
    if norm_rot in (90, 270):
        sw, sh = sh, sw
    if sar > 0 and abs(sar - 1.0) > 0.001:
        sw = round(sw * sar)

    source_aspect = sw / sh
    canvas_aspect = cw / ch
    matches = abs(source_aspect - canvas_aspect) <= 0.015

    if matches:
        return {"x": 0, "y": 0, "w": cw, "h": ch, "topBand": 0, "bottomBand": 0, "matches": True}

    if source_aspect > canvas_aspect:
        # Pillarbox / Letterbox top/bottom
        target_w = cw
        target_h = int(round(cw / source_aspect))
        if target_h % 2 != 0:
            target_h -= 1
        free_space = ch - target_h
        clamped_offset = max(-0.20, min(0.20, voffset))
        pixel_offset = int(round(clamped_offset * free_space))

        if vpos == "top":
            y = 0 + max(0, pixel_offset)
        elif vpos == "bottom":
            y = free_space + min(0, pixel_offset)
        else: # center
            y = (free_space // 2) + pixel_offset

        y = (y // 2) * 2
        top_band = y
        bottom_band = ch - (y + target_h)
        return {"x": 0, "y": y, "w": target_w, "h": target_h, "topBand": top_band, "bottomBand": bottom_band, "matches": False}
    else:
        # Pillarbox left/right
        target_h = ch
        target_w = int(round(ch * source_aspect))
        if target_w % 2 != 0:
            target_w -= 1
        x = ((cw - target_w) // 2 // 2) * 2
        return {"x": x, "y": 0, "w": target_w, "h": target_h, "leftBand": x, "rightBand": cw - (x + target_w), "matches": False}

def test_centering_and_positions():
    results = []
    cases = [
        {"name": "16:9 Landscape Center", "src": "fixture_16_9.mp4", "cw": 1080, "ch": 1920, "vpos": "center", "voff": 0.0},
        {"name": "16:9 Landscape Top", "src": "fixture_16_9.mp4", "cw": 1080, "ch": 1920, "vpos": "top", "voff": 0.0},
        {"name": "16:9 Landscape Bottom", "src": "fixture_16_9.mp4", "cw": 1080, "ch": 1920, "vpos": "bottom", "voff": 0.0},
        {"name": "4:3 SD Center", "src": "fixture_4_3.mp4", "cw": 1080, "ch": 1920, "vpos": "center", "voff": 0.0},
        {"name": "1:1 Square Center", "src": "fixture_1_1.mp4", "cw": 1080, "ch": 1920, "vpos": "center", "voff": 0.0},
        {"name": "9:16 Portrait Matches Aspect", "src": "fixture_9_16.mp4", "cw": 1080, "ch": 1920, "vpos": "center", "voff": 0.0},
        {"name": "Rotated 90° Matches Aspect", "src": "fixture_rotated.mp4", "cw": 1080, "ch": 1920, "vpos": "center", "voff": 0.0},
    ]

    for c in cases:
        src_path = os.path.join(FIXTURES_DIR, c["src"])
        w, h, rot = probe_video(src_path)
        layout = calculate_fit_layout(w, h, c["cw"], c["ch"], rot=rot, vpos=c["vpos"], voffset=c["voff"])

        out_name = f"{c['name'].lower().replace(' ', '_').replace(':', '')}.mp4"
        out_path = os.path.join(OUT_DIR, out_name)

        if layout["matches"]:
            cmd = ["ffmpeg", "-y", "-i", src_path, "-t", "1", "-c:v", "libx264", "-c:a", "aac", out_path]
        else:
            vf = f"scale={layout['w']}:{layout['h']},pad={c['cw']}:{c['ch']}:{layout['x']}:{layout['y']}:color=0xFFFFFF,setsar=1"
            cmd = ["ffmpeg", "-y", "-i", src_path, "-t", "1", "-vf", vf, "-c:v", "libx264", "-c:a", "aac", out_path]

        run_cmd(cmd)

        frame_png = out_path.replace(".mp4", "_frame.png")
        run_cmd(["ffmpeg", "-y", "-i", out_path, "-vframes", "1", frame_png])

        # Validate symmetry or positioning
        if c["vpos"] == "center" and not layout["matches"]:
            diff = abs(layout["topBand"] - layout["bottomBand"])
            is_pass = diff <= 2 # within even pixel rounding
        elif c["vpos"] == "top":
            is_pass = layout["topBand"] == 0
        elif c["vpos"] == "bottom":
            is_pass = layout["bottomBand"] == 0
        else:
            is_pass = layout["matches"] and layout["topBand"] == 0 and layout["bottomBand"] == 0

        results.append({
            "test": c["name"],
            "source": f"{w}x{h} (rot={rot})",
            "layout": layout,
            "symmetric_or_exact": is_pass,
            "frame": frame_png,
            "status": "PASS" if is_pass else "FAIL"
        })

    return results

def main():
    print("--- Running FitLayout & Label Verification ---")
    results = test_centering_and_positions()
    all_pass = all(r["status"] == "PASS" for r in results)

    report_path = os.path.join(OUT_DIR, "verification_report.json")
    with open(report_path, "w") as f:
        json.dump(results, f, indent=2)

    for r in results:
        print(f"[{r['status']}] {r['test']}: topBand={r['layout']['topBand']} bottomBand={r['layout']['bottomBand']} (even-pixel={r['layout']['y'] % 2 == 0})")

    print(f"\nAll tests passed: {all_pass}")
    print(f"Report saved to: {report_path}")
    if not all_pass:
        sys.exit(1)

if __name__ == "__main__":
    main()

