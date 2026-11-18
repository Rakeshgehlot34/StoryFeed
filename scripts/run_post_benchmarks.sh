#!/usr/bin/env bash
# ==============================================================================
# ShortsSplitter - Post-Optimization Benchmark Runner (Part B)
# Measures performance of 4 optimized workloads:
#   (a) 30 clips single-pass stream-copy segment muxer
#   (b) 30 clips precise re-encode (libx264 ultrafast, no framerate doubling)
#   (c) 9:16 fit with white background (libx264 ultrafast)
#   (d) 9:16 fit with downscaled blurred background (10% scale -> boxblur -> upscale)
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
FIXTURE="$PROJECT_ROOT/test/fixtures/bench_10m_1080p.mp4"
BENCH_DIR="/tmp/shortssplitter_after_$(date +%s)"

mkdir -p "$BENCH_DIR"
trap 'rm -rf "$BENCH_DIR"' EXIT

if [ ! -f "$FIXTURE" ]; then
    echo "❌ Fixture not found at $FIXTURE."
    exit 1
fi

echo "=================================================="
echo "⚡ Running Post-Optimization Benchmarks (Part B)"
echo "Fixture: $FIXTURE (600.0s, 1920x1080, 30fps)"
echo "Host: $(uname -sm) ($(nproc) CPU cores)"
echo "=================================================="

# (a) Single-Pass Segment Muxer (all 30 clips in 1 pass)
run_single_pass_stream_copy() {
    echo ""
    echo "▶ Scenario: (a) Single-Pass Stream-Copy (All 30 clips in 1 FFmpeg process)..."
    local start_time
    start_time=$(date +%s%N)

    ffmpeg -nostdin -v error -y -ss 0.0 -i "$FIXTURE" -t 600.0 \
        -c copy -map 0:v? -map 0:a? \
        -f segment -segment_time 20.0 -reset_timestamps 1 \
        "$BENCH_DIR/clip_%03d.mp4"

    local end_time
    end_time=$(date +%s%N)
    local elapsed_ms=$(( (end_time - start_time) / 1000000 ))
    local elapsed_sec
    elapsed_sec=$(awk -v ms="$elapsed_ms" 'BEGIN { printf "%.3f", ms / 1000 }')
    local per_clip_sec
    per_clip_sec=$(awk -v ms="$elapsed_ms" 'BEGIN { printf "%.3f", (ms / 1000) / 30 }')
    local speed_mult
    speed_mult=$(awk -v vid="600" -v elap="$elapsed_sec" 'BEGIN { printf "%.1f", vid / elap }')

    echo "  ⏱ Total Elapsed for all 30 clips: ${elapsed_sec}s"
    echo "  ⚡ Avg per 20s clip: ${per_clip_sec}s (${speed_mult}x realtime)"
    echo "  📊 30-clip total: ${elapsed_sec}s"
}

run_per_clip() {
    local name="$1"
    local count="$2"
    shift 2
    local cmd_func="$1"

    echo ""
    echo "▶ Scenario: $name ($count sample clips of 20.0s)..."
    local start_time
    start_time=$(date +%s%N)

    for ((i=0; i<count; i++)); do
        local start_sec
        start_sec=$(awk -v idx="$i" 'BEGIN { printf "%.3f", idx * 20.0 }')
        local out_file="$BENCH_DIR/opt_clip_$(printf "%03d" "$i").mp4"
        "$cmd_func" "$start_sec" "$out_file"
    done

    local end_time
    end_time=$(date +%s%N)
    local elapsed_ms=$(( (end_time - start_time) / 1000000 ))
    local elapsed_sec
    elapsed_sec=$(awk -v ms="$elapsed_ms" 'BEGIN { printf "%.3f", ms / 1000 }')
    local per_clip_sec
    per_clip_sec=$(awk -v ms="$elapsed_ms" -v cnt="$count" 'BEGIN { printf "%.3f", (ms / 1000) / cnt }')
    local processed_video_sec=$(( count * 20 ))
    local speed_mult
    speed_mult=$(awk -v vid="$processed_video_sec" -v elap="$elapsed_sec" 'BEGIN { printf "%.2f", vid / elap }')
    local projected_30_clip_sec
    projected_30_clip_sec=$(awk -v pc="$per_clip_sec" 'BEGIN { printf "%.1f", pc * 30 }')

    echo "  ⏱ Elapsed for $count clips: ${elapsed_sec}s"
    echo "  ⚡ Avg per 20s clip: ${per_clip_sec}s (${speed_mult}x realtime)"
    echo "  📊 Projected 30-clip total: ${projected_30_clip_sec}s ($(awk -v s="$projected_30_clip_sec" 'BEGIN { printf "%.1f min", s / 60 }'))"
}

# (b) Optimized Precise Re-encode (libx264 ultrafast, native fps)
cmd_opt_reencode() {
    local start="$1"
    local out="$2"
    ffmpeg -nostdin -v error -y -ss "$start" -i "$FIXTURE" -t 20.0 \
        -vf "scale=trunc(iw/2)*2:trunc(ih/2)*2,setsar=1" \
        -map 0:v -map 0:a? \
        -c:v libx264 -preset ultrafast -crf 22 -c:a aac -b:a 128k -pix_fmt yuv420p -movflags +faststart "$out"
}

# (c) Optimized 9:16 White Background (libx264 ultrafast, native fps)
cmd_opt_white_bg() {
    local start="$1"
    local out="$2"
    ffmpeg -nostdin -v error -y -ss "$start" -i "$FIXTURE" -t 20.0 \
        -vf "scale=1080:1920:force_original_aspect_ratio=decrease,pad=1080:1920:(ow-iw)/2:(oh-ih)/2:color=0xFFFFFF,setsar=1" \
        -map 0:v -map 0:a? \
        -c:v libx264 -preset ultrafast -crf 22 -c:a aac -b:a 128k -pix_fmt yuv420p -movflags +faststart "$out"
}

# (d) Optimized 9:16 Blurred Background (downscale 10% -> boxblur -> upscale bicubic)
cmd_opt_blur_bg() {
    local start="$1"
    local out="$2"
    ffmpeg -nostdin -v error -y -ss "$start" -i "$FIXTURE" -t 20.0 \
        -filter_complex "[0:v]scale=108:192:force_original_aspect_ratio=increase,crop=108:192,boxblur=5:1,scale=1080:1920:flags=bicubic[bg];[0:v]scale=1080:1920:force_original_aspect_ratio=decrease[fg];[bg][fg]overlay=(W-w)/2:(H-h)/2,setsar=1[v_base]" \
        -map "[v_base]" -map 0:a? \
        -c:v libx264 -preset ultrafast -crf 22 -c:a aac -b:a 128k -pix_fmt yuv420p -movflags +faststart "$out"
}

run_single_pass_stream_copy
run_per_clip "(b) Optimized Precise Re-encode" 3 cmd_opt_reencode
run_per_clip "(c) Optimized 9:16 White Background" 3 cmd_opt_white_bg
run_per_clip "(d) Optimized 9:16 Blurred Background" 3 cmd_opt_blur_bg

echo ""
echo "=================================================="
echo "✅ Post-Optimization Benchmarks Complete"
echo "=================================================="

