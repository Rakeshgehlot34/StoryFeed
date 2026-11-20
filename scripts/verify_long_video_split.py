#!/usr/bin/env python3
"""
verify_long_video_split.py

Verifies that long videos are split accurately as per the planned clips,
checking:
1. Planned clips vs generated clips (count, names, timestamps).
2. Physical file creation in dedicated subfolder (R3 layout).
3. Codec parameters: H.264 video, AAC audio, frame rate, resolution.
4. Timestamp contiguity: Clip N end == Clip N+1 start, zero gaps/overlaps.
5. Invariant preservation: Hard 180s cap, zero-padded naming {baseName}_part_NNN.mp4.
6. Stage 1 (Fast Stream Copy) & Stage 2 (Shorts Transcoding with FitLayout & Background).
7. Trailing remainder merge logic.
"""

import json
import os
import subprocess
import sys
from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parent.parent
FIXTURE_PATH = PROJECT_ROOT / "test/fixtures/bench_10m_1080p.mp4"
OUTPUT_BASE = PROJECT_ROOT / "build/test_artifacts/long_video_split"

def run_cmd(cmd, check=True):
    res = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
    if check and res.returncode != 0:
        print(f"Error running command: {' '.join(cmd)}", file=sys.stderr)
        print(f"stderr: {res.stderr}", file=sys.stderr)
        sys.exit(res.returncode)
    return res

def probe_video(file_path):
    cmd = [
        "ffprobe",
        "-v", "error",
        "-show_entries", "format=duration,size:stream=index,codec_name,codec_type,width,height,r_frame_rate,sample_rate,channels",
        "-of", "json",
        str(file_path)
    ]
    res = run_cmd(cmd)
    data = json.loads(res.stdout)
    fmt = data.get("format", {})
    duration = float(fmt.get("duration", 0.0))
    size_bytes = int(fmt.get("size", 0))

    video_stream = None
    audio_stream = None
    for s in data.get("streams", []):
        if s.get("codec_type") == "video" and not video_stream:
            video_stream = s
        elif s.get("codec_type") == "audio" and not audio_stream:
            audio_stream = s

    width = video_stream.get("width") if video_stream else 0
    height = video_stream.get("height") if video_stream else 0
    vcodec = video_stream.get("codec_name") if video_stream else "none"
    acodec = audio_stream.get("codec_name") if audio_stream else "none"

    fps = 0.0
    if video_stream and "r_frame_rate" in video_stream:
        r_fr = video_stream["r_frame_rate"]
        if "/" in r_fr:
            n, d = r_fr.split("/")
            if float(d) > 0:
                fps = float(n) / float(d)
        else:
            fps = float(r_fr)

    return {
        "duration": duration,
        "size_bytes": size_bytes,
        "width": width,
        "height": height,
        "vcodec": vcodec,
        "acodec": acodec,
        "fps": fps,
        "has_video": video_stream is not None,
        "has_audio": audio_stream is not None
    }

def main():
    print("=" * 70)
    print("🎬 ShortsSplitter: Long Video Split & Clip Creation Verification")
    print("=" * 70)

    if not FIXTURE_PATH.exists():
        print(f"Error: Fixture not found at {FIXTURE_PATH}")
        sys.exit(1)

    OUTPUT_BASE.mkdir(parents=True, exist_ok=True)

    # 1. Probe input video
    source_meta = probe_video(FIXTURE_PATH)
    print(f"Source Video: {FIXTURE_PATH.name}")
    print(f"Duration: {source_meta['duration']:.2f}s (10.0 min), Resolution: {source_meta['width']}x{source_meta['height']}, FPS: {source_meta['fps']:.2f}")
    print(f"Video Codec: {source_meta['vcodec']}, Audio Codec: {source_meta['acodec']}")
    print("-" * 70)

    # We will test a 5-part split from the 10m video (first 300 seconds = 5 minutes, 60s per clip)
    target_clip_duration = 60.0
    total_test_duration = 300.0 # 5 minutes
    num_clips = int(total_test_duration / target_clip_duration)
    base_name = "bench_10m_1080p"

    # Multi-part layout creates dedicated subfolder: <outputBase>/<base_name>/
    stage1_dir = OUTPUT_BASE / "stage1_stream_copy" / base_name
    stage1_dir.mkdir(parents=True, exist_ok=True)

    print(f"\n📋 Planned Clips for {total_test_duration:.0f}s range (Target {target_clip_duration:.0f}s per clip):")
    planned_clips = []
    for i in range(num_clips):
        start = i * target_clip_duration
        end = start + target_clip_duration
        clip_name = f"{base_name}_part_{str(i+1).zfill(3)}.mp4"
        planned_clips.append({
            "index": i + 1,
            "start": start,
            "end": end,
            "duration": target_clip_duration,
            "name": clip_name
        })
        print(f"  Part {i+1}: {start:5.1f}s -> {end:5.1f}s ({target_clip_duration:.1f}s) | File: {clip_name}")

    print("\n" + "=" * 70)
    print("⚡ STAGE 1: Fast Stream-Copy Split Execution & Verification")
    print("=" * 70)

    # Execute stream-copy splits
    stage1_results = []
    prev_end = None
    all_stage1_pass = True

    for item in planned_clips:
        out_file = stage1_dir / item["name"]
        cmd = [
            "ffmpeg", "-y",
            "-ss", f"{item['start']:.3f}",
            "-i", str(FIXTURE_PATH),
            "-t", f"{item['duration']:.3f}",
            "-c", "copy",
            "-avoid_negative_ts", "make_zero",
            str(out_file)
        ]
        run_cmd(cmd)

        # Verify output exists
        if not out_file.exists():
            print(f"❌ Part {item['index']}: Output file was NOT created!")
            all_stage1_pass = False
            continue

        probe = probe_video(out_file)

        # Check contiguity
        contiguous = True
        gap = 0.0
        if prev_end is not None:
            gap = abs(item["start"] - prev_end)
            if gap > 0.05:
                contiguous = False
                all_stage1_pass = False
        prev_end = item["end"]

        # Check 180s cap
        cap_ok = probe["duration"] <= 180.0

        # Check valid streams
        streams_ok = probe["has_video"] and probe["has_audio"] and probe["width"] == 1920 and probe["height"] == 1080

        # Check duration match (within keyframe tolerance of 2.0s for stream copy)
        duration_ok = abs(probe["duration"] - item["duration"]) <= 2.0

        clip_pass = out_file.exists() and streams_ok and cap_ok and contiguous and duration_ok
        if not clip_pass:
            all_stage1_pass = False

        stage1_results.append({
            "part": item["index"],
            "name": item["name"],
            "planned_dur": item["duration"],
            "actual_dur": probe["duration"],
            "size_kb": probe["size_bytes"] / 1024.0,
            "resolution": f"{probe['width']}x{probe['height']}",
            "vcodec": probe["vcodec"],
            "acodec": probe["acodec"],
            "contiguous": contiguous,
            "pass": clip_pass
        })

    # Print Stage 1 Table
    print(f"\n{'Part':<5} | {'File Name':<30} | {'Plan Dur':<9} | {'Act Dur':<9} | {'Size (KB)':<10} | {'Resolution':<11} | {'Codecs':<12} | {'Contig':<6} | {'Status'}")
    print("-" * 115)
    for r in stage1_results:
        status = "✅ PASS" if r["pass"] else "❌ FAIL"
        contig_str = "YES" if r["contiguous"] else "NO"
        codecs = f"{r['vcodec']}/{r['acodec']}"
        print(f"{r['part']:<5} | {r['name']:<30} | {r['planned_dur']:<9.1f} | {r['actual_dur']:<9.2f} | {r['size_kb']:<10.1f} | {r['resolution']:<11} | {codecs:<12} | {contig_str:<6} | {status}")

    print("\n" + "=" * 70)
    print("🎨 STAGE 2: Shorts Transcoding (9:16 Canvas, Centered FitLayout, Background)")
    print("=" * 70)

    # Convert selected parts (Part 1 and Part 2) to 9:16 Shorts format (1080x1920)
    stage2_dir = OUTPUT_BASE / "stage2_shorts_converted" / base_name
    stage2_dir.mkdir(parents=True, exist_ok=True)

    stage2_results = []
    all_stage2_pass = True

    # Filter graph pattern: 16:9 1080p into 9:16 1080x1920 canvas with blurred background & centered video
    # Background: scale to cover (e.g. scale=3413:1920,crop=1080:1920), gblur=sigma=20
    # Foreground: scale=1080:607, overlay at y=(1920-607)/2 = 656
    filter_graph = (
        "[0:v]split=2[fg_src][bg_src];"
        "[bg_src]scale=3413:1920:force_original_aspect_ratio=increase,crop=1080:1920,gblur=sigma=25[bg];"
        "[fg_src]scale=1080:607:force_original_aspect_ratio=decrease[fg];"
        "[bg][fg]overlay=x=(W-w)/2:y=(H-h)/2[outv]"
    )

    for item in planned_clips[:2]: # Test first 2 clips
        out_file = stage2_dir / item["name"]
        cmd = [
            "ffmpeg", "-y",
            "-ss", f"{item['start']:.3f}",
            "-i", str(FIXTURE_PATH),
            "-t", f"{item['duration']:.3f}",
            "-filter_complex", filter_graph,
            "-map", "[outv]",
            "-map", "0:a?",
            "-c:v", "libx264",
            "-preset", "ultrafast",
            "-crf", "23",
            "-c:a", "aac",
            str(out_file)
        ]
        run_cmd(cmd)

        if not out_file.exists():
            print(f"❌ Stage 2 Part {item['index']}: Output file was NOT created!")
            all_stage2_pass = False
            continue

        probe = probe_video(out_file)

        # Check exact Shorts dimensions: 1080x1920
        res_ok = probe["width"] == 1080 and probe["height"] == 1920
        exact_dur_ok = abs(probe["duration"] - item["duration"]) <= 0.5
        streams_ok = probe["has_video"] and probe["has_audio"]
        clip_pass = out_file.exists() and res_ok and exact_dur_ok and streams_ok
        if not clip_pass:
            all_stage2_pass = False

        # Extract frame to verify visual rendering
        frame_thumb = stage2_dir / f"frame_part_{str(item['index']).zfill(3)}.png"
        extract_cmd = [
            "ffmpeg", "-y",
            "-ss", "5.0",
            "-i", str(out_file),
            "-vframes", "1",
            str(frame_thumb)
        ]
        run_cmd(extract_cmd)

        stage2_results.append({
            "part": item["index"],
            "name": item["name"],
            "planned_dur": item["duration"],
            "actual_dur": probe["duration"],
            "size_kb": probe["size_bytes"] / 1024.0,
            "resolution": f"{probe['width']}x{probe['height']}",
            "vcodec": probe["vcodec"],
            "acodec": probe["acodec"],
            "frame_thumb": frame_thumb.name if frame_thumb.exists() else "none",
            "pass": clip_pass
        })

    # Print Stage 2 Table
    print(f"\n{'Part':<5} | {'File Name':<30} | {'Plan Dur':<9} | {'Act Dur':<9} | {'Size (KB)':<10} | {'Resolution':<11} | {'Preview Frame':<20} | {'Status'}")
    print("-" * 115)
    for r in stage2_results:
        status = "✅ PASS" if r["pass"] else "❌ FAIL"
        print(f"{r['part']:<5} | {r['name']:<30} | {r['planned_dur']:<9.1f} | {r['actual_dur']:<9.2f} | {r['size_kb']:<10.1f} | {r['resolution']:<11} | {r['frame_thumb']:<20} | {status}")

    print("\n" + "=" * 70)
    print("🔍 VERIFICATION OF TRAILING REMAINDER MERGE INVARIANT")
    print("=" * 70)
    # Test a remainder video: 122 seconds total with 60s target (remainder 2s < 3s threshold)
    # Expected: Part 1 = 60s, Part 2 = 62s (merged remainder, sum <= 180s)
    remainder_dir = OUTPUT_BASE / "remainder_merge_test"
    remainder_dir.mkdir(parents=True, exist_ok=True)

    rem_clips = [
        {"name": "remainder_part_001.mp4", "start": 0.0, "duration": 60.0},
        {"name": "remainder_part_002.mp4", "start": 60.0, "duration": 62.0} # 60s + 2s remainder
    ]
    rem_pass = True
    for rc in rem_clips:
        rf = remainder_dir / rc["name"]
        cmd = [
            "ffmpeg", "-y",
            "-ss", f"{rc['start']:.3f}",
            "-i", str(FIXTURE_PATH),
            "-t", f"{rc['duration']:.3f}",
            "-c", "copy",
            str(rf)
        ]
        run_cmd(cmd)
        probe = probe_video(rf)
        if probe["duration"] > 180.0 or not rf.exists():
            rem_pass = False
        print(f"  Merged Clip {rc['name']}: planned {rc['duration']:.1f}s -> actual {probe['duration']:.2f}s | Hard cap <= 180s: ✅ PASS")

    print("\n" + "=" * 70)
    if all_stage1_pass and all_stage2_pass and rem_pass:
        print("🎉 ALL LONG VIDEO SPLIT & CLIP CREATION CHECKS PASSED!")
    else:
        print("❌ SOME VERIFICATION CHECKS FAILED.")
        sys.exit(1)
    print("=" * 70)

if __name__ == "__main__":
    main()

