# ShortsSplitter — Developer Guide & Engineering Standards

ShortsSplitter is a production-grade Flutter application that splits long videos into sequentially numbered, contiguous clips optimized for YouTube Shorts, Reels, and TikTok, with Android Scoped Storage compliance.

## Tech Stack & Pinned Versions
- **Framework:** Flutter 3.47.5 (Channel stable), Dart 3.13.4 (Null-safe)
- **State Management:** `flutter_riverpod: ^2.6.1`, `riverpod_annotation: ^2.6.1`
- **Navigation:** `go_router: ^14.8.1` with route constants (`AppRoutes`)
- **Video Engine:** `ffmpeg_kit_flutter_new: ^4.6.8` (abstracted behind `VideoProcessor`)
- **Media & File Access:** `image_picker: ^1.1.2`, `file_picker: ^8.1.7`
- **Storage & State Cache:** `shared_preferences: ^2.3.5`, `path_provider: ^2.1.5`, `path: ^1.9.1`
- **Video Preview:** `video_player: ^2.9.2` | **Permissions:** `permission_handler: ^11.4.0`

## Essential Commands
```bash
flutter pub get                          # Install dependencies
dart format --output=none --set-exit-if-changed . # Verify formatting
dart format .                            # Format code in-place
flutter analyze                          # Run static analyzer
flutter test                             # Run all unit/widget tests
dart run build_runner build --delete-conflicting-outputs # Code-gen
flutter run                              # Run in debug mode on connected device
flutter build apk --release              # Universal release APK
flutter build apk --split-per-abi --release # Optimized per-ABI APKs (arm64-v8a: 64MB)
```

## Architecture & Dependency Flow
Feature-first layout where dependencies strictly point inward:
`presentation` -> `domain` <- `data`
- `core/`: Cross-cutting primitives (`Result<T, E>`, `AppException`, `ErrorMapper`, `AppLogger`, `StorageUtils`).
- `features/`: Isolated business capabilities (`video_picker`, `split_config`, `processing`, `output`, `home`).
  - `domain/`: Pure Dart models, invariants, repository interfaces, and `VideoProcessor` contract. Zero Flutter/FFmpeg imports.
  - `data/`: Implementations of repositories and external engines (`FFmpegVideoProcessor`, `OutputRepository`).
  - `presentation/`: Widgets, screens, and Riverpod controllers/notifiers.

## Strict Coding Rules
1. **Null Safety & Types:** Sound null-safety everywhere. Never use `dynamic`. Never use the bang operator `!` unless accompanied by an explanatory assertion comment.
2. **State Management:** Riverpod exclusively. No `setState` for shared/business state. Controllers/notifiers reside in `presentation/controllers`.
3. **Routing:** Exclusively `go_router` via named paths in `lib/app/constants.dart` (`AppRoutes`). No raw string navigation.
4. **Engine Abstraction:** ALL FFmpeg/FFprobe invocations are restricted to `features/processing/data/ffmpeg_video_processor.dart`. Never import FFmpeg in UI, controllers, or domain models.
5. **Errors & Results:** Return `Result<T, E>` or throw typed `AppException` subclasses. No swallowed exceptions (`catch (_) {}` without logging). All UI error messages route through `ErrorMapper.mapToUserMessage()`.
6. **Design System:** Zero hardcoded colors, dimensions, or strings in widgets. Use `Theme.of(context).colorScheme`, `AppTheme`, and `AppConstants`.
7. **File & Widget Budgets:** Maximum 300 lines per file. Maximum 100 lines for any `build()` method. Extract sub-widgets.

## Domain Invariants (NEVER Violate)
- **Sequence Naming:** `{originalName}_part_{NNN}.mp4`, zero-padded to `max(3, digits(totalClips))` (e.g., `_part_001.mp4`).
- **Contiguity:** Zero gaps, zero overlaps. Clip $N+1$ start time MUST equal Clip $N$ end time: `segments[i].endSeconds == segments[i+1].startSeconds`.
- **Trailing Remainder:** Trailing clips are always preserved. If remainder duration is $< 3.0$ seconds and `mergeShortTrailingClip` is enabled, merge into penultimate clip.
- **Memory Safety:** Never buffer video files into RAM. Process strictly one clip at a time using native stream seeking (`-ss` and `-t`).
- **Disk Cleanliness:** Clean up temporary `.tmp` or partial `.probe` files on success, failure, or cancellation.
- **Duration Limit:** Maximum clip length is 180 seconds (3 minutes, YouTube Shorts specification).

## Storage & Scoped Storage Rules
- User-selected directories are persisted in `SharedPreferences` via `AppConstants.prefKeyOutputDirectory`.
- Output paths are verified for write permissions using `StorageUtils.testDirectoryWritable()` before execution.
- If SAF custom folder permissions fail on Android 10-15+, transparently fall back to the app-specific external storage directory (`/Android/data/com.shortssplitter.shorts_splitter/files/ShortsSplitter/`).

## Testing Rules
- Any modification to `ClipSegment.calculateSegments()` or split math requires automated unit tests.
- Always run `flutter analyze && flutter test` before committing or declaring work complete.

## Git Workflow
- Conventional Commits (`feat:`, `fix:`, `refactor:`, `test:`, `docs:`, `chore:`).
- Small, single-purpose commits.
- Never commit `.env*`, `*.jks`, `*.keystore`, `key.properties`, or `local.properties`.

## Definition of Done (DoD)
- [ ] `flutter analyze` reports zero issues.
- [ ] `flutter test` passes 100% of test cases.
- [ ] `dart format --set-exit-if-changed .` passes cleanly.
- [ ] All domain invariants satisfied (naming, contiguity, memory bounds).
- [ ] Tested on Android / emulator with both Fast (stream copy) and Precise (re-encode) modes.

## Ask Before Doing
1. Adding or upgrading dependencies in `pubspec.yaml`.
2. Altering architecture boundaries or moving domain models.
3. Changing `minSdk` (fixed at 24) or target SDK levels.
4. Modifying Gradle signing configurations or release build keys.

