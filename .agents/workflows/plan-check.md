# Split Plan Verification Workflow

Run this workflow whenever modifying video splitting logic, `PlanCalculator`, `PlanValidator`, or `PlanReviewScreen`.

---

## 1. Domain Planning & Invariants Check
- [ ] **Hard 180s Cap:** Verify no clip can exceed 180.0 seconds under any circumstance:
  - Preset duration chips (15s, 30s, 45s, 60s, 90s, 120s, 180s)
  - Custom duration input clamps at 180 with a clear message
  - `PlanValidator.validatePlanItems()` throws `PlanValidationException` if duration $> 180.0\text{s}$
  - `FFmpegVideoProcessor` asserts duration $\le 180.0\text{s}$ before transcoding
- [ ] **Boundary Contiguity:** Verify zero gaps and zero overlaps across all generated clips:
  - `items[i].endSeconds == items[i+1].startSeconds`
  - Boundary edits update both left and right neighbors simultaneously
  - Splits generate contiguous segments
  - Merges combine contiguous neighbors
- [ ] **Trailing Remainder Merge Rule:**
  - If remainder $< 3.0\text{s}$ and merge enabled and $(target + remainder) \le 180\text{s}$, merge into penultimate clip
  - If $(target + remainder) > 180\text{s}$, remain independent clip to protect the 180s cap
- [ ] **Overlay Message Hierarchy:**
  - Specific part override > All parts message > Auto label (`Part {n}/{total}`) > None
  - Tokens `{n}`, `{total}`, and `{name}` correctly substituted

---

## 2. Video Transcoding & Canvas Transform Check
- [ ] **Fit Without Cropping:** Default behavior preserves entire video frame scaled down and centered.
- [ ] **Background Options:**
  - Solid Color: `pad` filter with hex color string
  - Blurred Background: 2-stream complex filter with `boxblur`
  - Custom Image: `-loop 1 -i image` composite
- [ ] **Crop to Fill:** Only active when user explicitly toggles "Crop to fill".
- [ ] **Safe Area Text Overlay:** Rendered to transparent PNG via `dart:ui` and composited without host font dependencies.
- [ ] **Audio Safety:** `-map 0:a?` included so videos without audio tracks transcode cleanly without failing.

---

## 3. Automated Verification Execution
Execute the full test and quality suite:
```bash
dart format --output=none --set-exit-if-changed .
flutter analyze
flutter test
./scripts/verify.sh
```

