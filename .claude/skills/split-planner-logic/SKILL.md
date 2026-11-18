---
name: split-planner-logic
description: Explains the algorithmic rules, edge cases, zero-padded naming, and unit test suites for calculating contiguous video slices in ShortsSplitter.
---

# Split Planner Logic & Slice Computation

This skill defines the pure mathematical calculation implemented in `ClipSegment.calculateSegments()`.

---

## 1. Domain Invariants

1. **Perfect Sequence:** Every clip is assigned an integer index $1, 2, \dots, N$.
2. **Zero-Padded Pattern:** `${sanitizedBase}_part_${index.padLeft(padWidth, '0')}.mp4`, where `padWidth = max(3, digits(totalClips))`.
3. **Contiguity Guarantee:** For any two adjacent segments $i$ and $i+1$:
   $$\text{segment}[i+1].\text{startSeconds} = \text{segment}[i].\text{endSeconds}$$
   Zero gaps, zero overlaps across the entire source video duration.
4. **Remainder Preservation & Merging:**
   - Slices shorter than the target duration are never discarded.
   - If `mergeShortTrailingClip` is `true`, remainder duration $< 3.0\text{s}$, and total full clips $\ge 1$, the remainder is appended to the penultimate clip ($N-1$).
   - Otherwise, the remainder becomes its own distinct short clip.

---

## 2. Core Algorithm Implementation

```dart
static List<ClipSegment> calculateSegments({
  required double totalDurationSeconds,
  required int targetClipDurationSeconds,
  required bool mergeShortTrailingClip,
  required String baseName,
  double trailingThresholdSeconds = 3.0,
}) {
  if (totalDurationSeconds <= 0) return const [];

  final target = targetClipDurationSeconds.toDouble();

  // Edge Case 1: Video shorter than or equal to target clip duration
  if (totalDurationSeconds <= target) {
    return [
      ClipSegment(
        index: 1,
        startSeconds: 0.0,
        durationSeconds: totalDurationSeconds,
        formattedName: Formatters.formatClipFileName(baseName, 1, 1),
      ),
    ];
  }

  final fullClipCount = (totalDurationSeconds / target).floor();
  final remainder = totalDurationSeconds - (fullClipCount * target);

  // Check if remainder is eligible for merge
  final shouldMerge = mergeShortTrailingClip &&
      remainder > 0.05 &&
      remainder < trailingThresholdSeconds &&
      fullClipCount >= 1;

  final totalClips = shouldMerge
      ? fullClipCount
      : (remainder > 0.05 ? fullClipCount + 1 : fullClipCount);

  final segments = <ClipSegment>[];

  for (int i = 0; i < fullClipCount; i++) {
    final start = i * target;
    final isLastFullClip = (i == fullClipCount - 1);

    if (isLastFullClip && shouldMerge) {
      segments.add(
        ClipSegment(
          index: i + 1,
          startSeconds: start,
          durationSeconds: target + remainder,
          formattedName: Formatters.formatClipFileName(baseName, i + 1, totalClips),
          isMergedTrailing: true,
        ),
      );
    } else {
      segments.add(
        ClipSegment(
          index: i + 1,
          startSeconds: start,
          durationSeconds: target,
          formattedName: Formatters.formatClipFileName(baseName, i + 1, totalClips),
        ),
      );
    }
  }

  // Add distinct remainder clip if not merged
  if (remainder > 0.05 && !shouldMerge) {
    segments.add(
      ClipSegment(
        index: fullClipCount + 1,
        startSeconds: fullClipCount * target,
        durationSeconds: remainder,
        formattedName: Formatters.formatClipFileName(baseName, fullClipCount + 1, totalClips),
      ),
    );
  }

  return segments;
}
```

---

## 3. Edge Cases & Unit Test Matrix

| Scenario | Input Duration | Target | Merge Setting | Resulting Clips Breakdown |
| :--- | :--- | :--- | :--- | :--- |
| **Shorter than preset** | 42.0s | 60s | true/false | 1 clip: [0.0s - 42.0s] (`part_001.mp4`) |
| **Exact multiple** | 120.0s | 60s | true | 2 clips: [0.0s-60.0s], [60.0s-120.0s] |
| **Micro-remainder (< 3s) merged** | 62.0s | 60s | `true` | 1 clip: [0.0s - 62.0s] (`isMergedTrailing: true`) |
| **Micro-remainder (< 3s) separate**| 62.0s | 60s | `false`| 2 clips: [0.0s-60.0s], [60.0s-62.0s] (2s clip) |
| **Large remainder (> 3s)** | 250.0s (4m10s)| 60s | `true` | 5 clips: 4x 60s clips + 1x 10s clip |
| **High clip count padding** | 7200.0s (2 hrs) | 60s | true | 120 clips: `part_001.mp4` ... `part_120.mp4` |

---

## 4. Test Template

```dart
test('Verifies contiguous boundary invariant for 10-clip plan', () {
  final segments = ClipSegment.calculateSegments(
    totalDurationSeconds: 605.0,
    targetClipDurationSeconds: 60,
    mergeShortTrailingClip: false,
    baseName: 'vlog',
  );

  for (int i = 0; i < segments.length - 1; i++) {
    expect(
      segments[i].endSeconds,
      equals(segments[i + 1].startSeconds),
      reason: 'Segment $i end must match Segment ${i + 1} start',
    );
  }
});
```

