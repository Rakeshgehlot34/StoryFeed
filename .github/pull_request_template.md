## Description
<!-- Provide a brief summary of changes made in this Pull Request. -->

## Type of Change
- [ ] `feat`: New feature or capability
- [ ] `fix`: Bug fix
- [ ] `refactor`: Code change that neither fixes a bug nor adds a feature
- [ ] `test`: Adding or correcting tests
- [ ] `docs`: Documentation updates
- [ ] `chore`: Tooling, build config, or dependency update

---

## Domain Invariants Checklist (Mandatory for Merge)
Before requesting review, verify that the changes strictly uphold all domain invariants:

- [ ] **Sequential Naming:** Clip filenames follow `{originalName}_part_{NNN}.mp4`, zero-padded to `max(3, digits(totalClips))`.
- [ ] **Contiguous Boundary Invariant:** Clips have zero gaps and zero overlaps (`segment[i].endSeconds == segment[i+1].startSeconds`).
- [ ] **Trailing Remainder Preservation:** Leftover clips are never discarded (merged into previous clip only if $< 3.0\text{s}$ and setting is enabled).
- [ ] **Memory Safety:** Input videos are never loaded entirely into memory as byte buffers (`Uint8List`). Slicing processes strictly one clip at a time.
- [ ] **Temp File Cleanliness:** Any temporary files (`.tmp`, `.probe_`) are cleaned up on success, failure, or cancellation.
- [ ] **Clip Duration Bound:** Clip target length is bounded between 1s and 180s (3 minutes max).
- [ ] **FFmpeg Isolation:** No direct imports of FFmpeg libraries inside UI widgets or pure domain models.

---

## Quality & Verification
- [ ] Ran `dart format .` and verified no formatting diffs.
- [ ] Ran `flutter analyze` and resolved all warnings and infos.
- [ ] Ran `flutter test` and all automated tests passed.
- [ ] Tested on a physical device or emulator.
- [ ] No secrets, keystores (`*.jks`), or `local.properties` committed.

