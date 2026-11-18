---
name: split-planner-logic
description: Pure mathematical algorithm for calculating contiguous clip ranges, trailing remainder merge rules, and zero-padded sequence names.
---

# Split Planner Logic & Slice Algorithm

## Trigger Conditions
Use this skill when:
- Modifying or extending `PlanCalculator` or `PlanValidator` in `lib/features/split_config/domain/models/`.
- Updating split preview calculations in `lib/features/split_config/presentation/` or `lib/features/plan_review/`.
- Adding unit test cases for video segmentation in `test/features/split_config/`.

---

## 1. Mathematical Segmentation Algorithm

### Objective
Given a `TrimRange` $[T_{start}, T_{end}]$ (seconds), a target clip length $L \in [1, 180]$ (seconds), and a merge policy flag $M$ (`mergeShortTrailingClip`):
1. Compute the sequence of non-overlapping, contiguous intervals $[s_0, e_0], [s_1, e_1], \dots, [s_{N-1}, e_{N-1}]$.
2. Ensure $e_{k-1} == s_k$ for all $k \in [1, N-1]$ (zero gaps, zero overlaps).
3. Ensure $s_0 == T_{start}$ and $e_{N-1} == T_{end}$.
4. Ensure $1.0 \le (e_k - s_k) \le 180.0$ for all $k \in [0, N-1]$.

### Trailing Remainder Merge Invariant
Remainder $R = (T_{end} - T_{start}) \pmod L$.
If $0.05 < R < 3.0\text{s}$ and $M == \text{true}$ and $(L + R) \le 180.0\text{s}$:
- Absorb remainder into penultimate clip $[s_{N-1}, T_{end}]$ with duration $L + R$.
- If $L + R > 180.0\text{s}$, remainder CANNOT be merged and must remain an independent clip to satisfy the hard YouTube Shorts 180s cap.

---

## 2. Interactive Editing Invariants
1. **Boundary Adjustment (`adjustBoundary`):**
   - Adjusting boundary $B$ between clip $i$ and $i+1$ updates both neighbors:
     $$\text{clip}_i.endSeconds = B \quad\text{and}\quad \text{clip}_{i+1}.startSeconds = B$$
   - Reject with `PlanValidationException` if either $(B - \text{clip}_i.startSeconds) < 1.0\text{s}$ or $> 180.0\text{s}$.
   - Reject if $(\text{clip}_{i+1}.endSeconds - B) < 1.0\text{s}$ or $> 180.0\text{s}$.
2. **Merge Parts (`mergeWithNext`):**
   - Merging clip $i$ and $i+1$ yields single clip $[s_i, e_{i+1}]$.
   - Reject with `PlanValidationException` if combined duration $> 180.0\text{s}$.
3. **Split Part (`splitPart`):**
   - Split at timestamp $t$ produces $[s_i, t]$ and $[t, e_i]$.
   - Reject with `PlanValidationException` if either half is $< 1.0\text{s}$.

---

## 3. Overlay Message Resolution Hierarchy
1. **Specific Part Override:** `item.customMessage` (if non-empty)
2. **All Parts Message:** `overlaySpec.allPartsMessage` (if non-empty)
3. **Auto Label Template:** `overlaySpec.template` (`Part {n}/{total}` if `autoLabel == true`)
4. **None:** `null` (no text overlay generated)

**Supported Tokens:**
- `{n}`: 1-based part index
- `{total}`: Total planned clip count
- `{name}`: Sanitized base video filename

---

## 4. Zero-Padding Rules
$$\text{padWidth} = \max(3, \lfloor\log_{10}(\text{totalClips})\rfloor + 1)$$
Example: `{name}_part_001.mp4` through `{name}_part_012.mp4`.
