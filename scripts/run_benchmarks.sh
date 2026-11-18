#!/usr/bin/env bash
# ==============================================================================
# ShortsSplitter - Baseline Benchmark Runner
# Measures performance of 4 primary transcoding workloads:
#   (a) 30 clips stream-copy
#   (b) 30 clips precise re-encode (libx264 veryfast)
#   (c) 9:16 fit with white background
#   (d) 9:16 fit with blurred background (baseline full-res boxblur)
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
FIXTURE="$PROJECT_ROOT/test/fixtures/bench_10m_1080p.mp4"
BENCH_DIR="/tmp/shortssplitter_bench_$(date +%s)"

mkdir -p "$BENCH_DIR"
trap 'rm -rf "$BENCH_DIR"' EXIT

if [ ! -f "$FIXTURE" ]; then
    echo "❌ Fixture not found at $FIXTURE. Run ./scripts/make_benchmarks.sh first."
    exit 1
fi

echo "=================================================="
echo "⚡ Running Baseline Benchmarks on 10-min 1080p Video"
echo "Fixture: $FIXTURE (600.0s, 1920x1080, 30fps)"
echo "Host: $(uname -sm) ($(nproc) CPU cores)"
echo "=================================================="

# Helper function to measure execution
run_bench() {
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
        local out_file="$BENCH_DIR/clip_$(printf "%03d" "$i").mp4"
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

# (a) Stream-copy
cmd_stream_copy() {
    local start="$1"
    local out="$2"
    ffmpeg -nostdin -v error -y -ss "$start" -i "$FIXTURE" -t 20.0 -c copy -avoid_negative_ts make_zero "$out"
}

# (b) Precise re-encode (current libx264 veryfast)
cmd_precise_reencode() {
    local start="$1"
    local out="$2"
    ffmpeg -nostdin -v error -y -ss "$start" -i "$FIXTURE" -t 20.0 \
        -vf "scale=trunc(iw/2)*2:trunc(ih/2)*2,setsar=1" \
        -map 0:v -map 0:a? \
        -c:v libx264 -preset veryfast -crf 22 -r 60 -c:a aac -b:a 128k -pix_fmt yuv420p -movflags +faststart "$out"
}

# (c) 9:16 fit with white background
cmd_white_bg() {
    local start="$1"
    local out="$2"
    ffmpeg -nostdin -v error -y -ss "$start" -i "$FIXTURE" -t 20.0 \
        -vf "scale=1080:1920:force_original_aspect_ratio=decrease,pad=1080:1920:(ow-iw)/2:(oh-ih)/2:color=0xFFFFFF,setsar=1" \
        -map 0:v -map 0:a? \
        -c:v libx264 -preset veryfast -crf 22 -r 60 -c:a aac -b:a 128k -pix_fmt yuv420p -movflags +faststart "$out"
}

# (d) 9:16 fit with blurred background (baseline full-res boxblur)
cmd_blur_bg() {
    local start="$1"
    local out="$2"
    ffmpeg -nostdin -v error -y -ss "$start" -i "$FIXTURE" -t 20.0 \
        -filter_complex "[0:v]scale=1080:1920:force_original_aspect_ratio=increase,crop=1080:1920,boxblur=luma_radius=min(h\\,w)/20:luma_power=2[bg];[0:v]scale=1080:1920:force_original_aspect_ratio=decrease[fg];[bg][fg]overlay=(W-w)/2:(H-h)/2,setsar=1[v_base]" \
        -map "[v_base]" -map 0:a? \
        -c:v libx264 -preset veryfast -crf 22 -r 60 -c:a aac -b:a 128k -pix_fmt yuv420p -movflags +faststart "$out"
}

run_bench "(a) Stream-copy (30 clips)" 30 cmd_stream_copy
run_bench "(b) Precise re-encode (libx264 veryfast)" 3 cmd_precise_reencode
run_bench "(c) 9:16 White Background" 3 cmd_white_bg
run_bench "(d) 9:16 Blurred Background (Unoptimized Boxblur)" 2 cmd_blur_bg

echo ""
echo "=================================================="
echo "✅ Baseline Benchmarking Complete"
echo "=================================================="

