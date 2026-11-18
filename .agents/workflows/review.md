# /review Workflow

Numbered execution steps for auditing code changes against `AGENTS.md` and domain invariants. This workflow is strictly **read-only** (make no file edits).

## Execution Steps

1. **Inspect Working Tree & Diff:**
   Fetch git status and git diff:
   ```bash
   git status --short
   git diff HEAD
   ```

2. **Audit Against Domain Invariants:**
   Verify each domain invariant against the diff:
   - Are clip names strictly formatted as `{originalName}_part_{NNN}.mp4` with correct zero-padding?
   - Are segment boundaries strictly contiguous ($e_k == s_{k+1}$)?
   - Is trailing remainder logic intact (kept, or merged if $< 3\text{s}$)?
   - Is memory safety respected (one clip at a time, no RAM buffering)?
   - Are temp files safely cleaned up?
   - Is target clip duration bounded $\le 180$ seconds?

3. **Audit Against Architectural & Style Rules:**
   - Are any FFmpeg imports introduced outside `lib/features/processing/data/`?
   - Are there any `dynamic` types or unannotated `!` bang operators?
   - Are there any hardcoded colors or strings in widget trees?
   - Are build methods kept under 100 lines and files under 300 lines?
   - Did any secrets (`.jks`, `key.properties`, `.env`) get modified or staged?

4. **Classify & Report Findings by Severity:**
   Output findings structured strictly as:
   - **🔴 Blocker:** Invariant violations, FFmpeg leaks into presentation/domain, unhandled exceptions, committed secrets.
   - **🟠 Major:** Missing unit tests for split logic, memory buffering risks, Riverpod architecture violations.
   - **🟡 Minor:** Code formatting, missing const modifiers, hardcoded color/padding values, missing trailing commas.
   - **✅ Clean:** If no issues are found, state that the diff is ready for merge.

