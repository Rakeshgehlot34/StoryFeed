# Domain Invariants (Non-Negotiable)

These six core invariants define the business rules and safety guarantees of `shorts_splitter`. They must NEVER be violated or compromised by any PR or refactoring.

## Invariant 1: Sequential Clip Naming
- **Pattern:** `{originalName}_part_{NNN}.mp4`
- **Zero-Padding Rule:** Zero-padded to `max(3, digits(totalClips))`.
  - For 1 to 999 clips: `_part_001.mp4`, `_part_002.mp4`, ..., `_part_010.mp4`.
  - For 1000+ clips: `_part_0001.mp4`, `_part_0002.mp4`, etc.
- **Base Name Cleansing:** Strip file extension from original video name before appending sequence suffix.

## Invariant 2: Perfect Boundary Contiguity
- **Zero Gaps, Zero Overlaps:** Every intermediate segment boundary must be contiguous:
  $$\text{segment}[i].\text{endSeconds} == \text{segment}[i+1].\text{startSeconds}$$
- **Start & End:** The first segment must start at `0.0`. The last segment must terminate exactly at `videoDuration.inSeconds` (or total duration in seconds).
- **No Fractional Drops:** Precision cuts must honor exact floating-point or integer timestamps without clipping dropped frames.

## Invariant 3: Trailing Remainder Handling
- **Preservation:** Trailing video footage shorter than the target clip length must NEVER be discarded.
- **Conditional Merge:**
  - If the final clip duration is $< 3.0$ seconds AND `mergeShortTrailingClip` is `true`:
    Merge the remainder duration into the immediately preceding (penultimate) clip.
  - If `mergeShortTrailingClip` is `false` OR there is only one clip in total:
    Retain the remainder as a standalone, short final clip.

## Invariant 4: Sequential Processing & Memory Safety
- **One Clip at a Time:** Transcode and export clips strictly one by one in sequential order ($1, 2, \dots, N$).
- **No In-Memory Video Buffering:** Never load whole video files or large segments into RAM as `Uint8List` or `List<int>`. Video data must stream from disk to disk via native FFmpeg process pipes.

## Invariant 5: Temp File Lifecycle & Cleanliness
- **Guaranteed Cleanup:** Temporary files (`.tmp`, `.probe_*`, intermediate re-encodes) must be cleaned up across all execution branches:
  - On **Success**: Intermediate files deleted; final output retained.
  - On **Failure**: Partial/corrupted segment files and temp probes deleted.
  - On **Cancellation**: Active segment file and temp probes deleted immediately.

## Invariant 6: Clip Duration Bounds
- **Boundaries:** The target clip duration must be bounded:
  $$1\text{ second} \le \text{targetClipSeconds} \le 180\text{ seconds (3 minutes)}$$
- **Shorts Compliance:** Durations exceeding 180 seconds are disallowed to adhere to YouTube Shorts, Instagram Reels, and TikTok upload specifications.

