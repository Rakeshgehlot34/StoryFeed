# AGENTS.md — ShortsSplitter Engineering Guide

ShortsSplitter is a production-grade Flutter application that splits long videos into sequentially numbered, contiguous clips optimized for YouTube Shorts, Instagram Reels, and TikTok, with Android 9 (API 28) through Android 15 (API 35+) compliance.

## Pinned Tech Stack
- **Framework & Language:** Flutter `3.47.5` (channel stable), Dart `3.13.4` (sound null-safety)
- **State Management:** `flutter_riverpod: ^2.6.1`, `riverpod_annotation: ^2.6.1`
- **Navigation:** `go_router: ^14.8.1` (`AppRoutes.planReview = '/plan-review'`)
- **Media Transcoding:** `ffmpeg_kit_flutter_new: ^4.6.8` (strictly isolated behind `VideoProcessor`)
- **Platform Storage & Picking:** `file_picker: ^8.1.7`, `shared_preferences: ^2.3.5`, `permission_handler: ^11.4.0`
- **Video Preview:** `video_player: ^2.9.2`
- **Android Target:** `compileSdk = 36`, `targetSdk = 35`, `minSdk = 28` (`com.shortssplitter.shorts_splitter`)

## Essential CLI Commands
- Fetch dependencies: `flutter pub get`
- Static analysis (strict mode): `flutter analyze`
- Formatting check: `dart format --output=none --set-exit-if-changed .`
- Auto-format code: `dart format .`
- Run test suite: `flutter test`
- Code generation: `dart run build_runner build --delete-conflicting-outputs`
- Launch app (debug): `flutter run`
- Build release APKs: `flutter build apk --release --split-per-abi`
- Build production APK: `./scripts/build_apk.sh --clean --release` (or `.\scripts\build_apk.ps1 -Clean -Release`)
- Build APK workflow: Antigravity slash command `/build-apk`
- Complete verification: `./scripts/verify.sh`

## Application Flow & Architecture
```
Select video -> Trim and settings -> PLAN REVIEW -> Processing -> Results
```
```
Presentation Layer (UI, Screens, Controllers)
       │ (depends on)
       ▼
Domain Layer (Entities, Value Objects, VideoProcessor Interface, ClipWriter, PlanCalculator)
       ▲
       │ (implements / depends on)
Data Layer (Repositories, StorageBridge, FFmpegVideoProcessor, OverlayRenderer)
```
- Core layers: `lib/app/` (router, theme, constants), `lib/core/` (errors, result, logger, utils).
- Features: `lib/features/{home,video_picker,split_config,plan_review,processing,output,history,settings,onboarding,player,utility}/`.
- Rule: Presentation depends on Domain; Data depends on Domain. Domain depends on NOTHING external.

## Strict Coding Rules
- **Sound Null-Safety:** Never use `dynamic`. Never use bang operator `!` unless accompanied by a clarifying inline comment justifying non-null assertion.
- **Riverpod Only:** Use Riverpod for shared/cross-widget state (`Notifier` / `AsyncNotifier`). Providers live exclusively in `lib/features/<feature>/presentation/controllers/`.
- **Navigation:** Navigate exclusively via `GoRouter` using route names defined in `AppRoutes` (`lib/app/constants.dart`).
- **FFmpeg Isolation:** All FFmpeg packages (`ffmpeg_kit_flutter_new`) must ONLY be imported inside `lib/features/processing/data/ffmpeg_video_processor.dart`.
- **Text Overlay Rendering:** Rendered to transparent PNG via `dart:ui` in `OverlayRenderer` for zero-font-dependency universal Unicode & emoji support.
- **Error Handling:** Operations returning fallible outcomes must return `Result<T, AppException>` or throw typed `AppException`. Map errors strictly via `ErrorMapper.mapToUserMessage(exception)`.
- **UI Hygiene:** No hardcoded strings, colors, or durations in widgets. Use `AppTokens`, `AppStrings`, `AppTheme`, and `Theme.of(context)`. Files under 300 lines; `build()` under 100 lines.
- **Android Version Guarding:** Any Android API-specific code must be version-guarded (`Build.VERSION.SDK_INT`) and covered by the compat checklist (`docs/ANDROID_COMPAT.md`).
- **Documentation Synchronization:** Any change to features, commands, routes, permissions, or dependencies must update the matching doc in `/docs` in the same change; run `/docs-sync` before finishing.
- **Job Ownership:** Export jobs are owned exclusively by `ExportJobController` and never by a widget or `autoDispose` provider; disposing screens must never cancel active background exports.
- **Single Player Invariant:** Exactly one active `VideoPlayerController` managed via `PlayerService`; pause on route cover/pop and on app background; release on export start.
- **Foreground Service Guarding:** Foreground service types must be verified per API level (`mediaProcessing` on API 34/35+, `dataSync` fallback, wake lock held).
- **Keystore & Artifact Security:** Never commit keystores, signing configs, or APK binaries (`android/key.properties`, `*.jks`, `build/`, `dist/`, and `*.apk` are strictly ignored via `.gitignore`).

## UI/UX & Design System Rules
- **Design Tokens:** Use `AppTokens` (`lib/app/theme/app_tokens.dart`) for spacing (4..32), radii, elevations, and durations. Zero magic numbers.
- **14 Reusable Widgets:** Always use shared primitives in `lib/shared/widgets/` (`AppScaffold`, `SectionCard`, `PrimaryButton`, `SecondaryButton`, `StatTile`, `EmptyState`, `ErrorState`, `LoadingSkeleton`, `ProgressRing`, `InfoBanner`, `ClipTile`, `ColorPickerField`, `SettingsTile`, `ConfirmDialog`).
- **4 Screen States:** Every screen must implement `loading` (`LoadingSkeleton`), `empty` (`EmptyState`), `error` (`ErrorState` with retry), and `content`.
- **Adaptive Layout:** Switch between `NavigationBar` (compact mobile < 600dp) and `NavigationRail` (tablets/landscape >= 600dp) via `AppScaffold`.
- **Accessibility & Motion:** Min 48dp touch targets, WCAG AA contrast, semantic labels, and disable repeating animations when `MediaQuery.disableAnimationsOf(context)` is true.

## Domain Invariants (NEVER Violate)
1. **Hard 180s Cap:** No generated clip may exceed 180 seconds (3 minutes max). Enforced across UI (inputs clamp), domain (`PlanValidator`), and processor assertion.
2. **Boundary Contiguity:** Zero gaps, zero overlaps. `items[i].endSeconds == items[i+1].startSeconds`.
3. **Clip Naming:** `{originalName}_part_{NNN}.mp4`, zero-padded to `max(3, digits(totalClips))`.
4. **Overlay Fallback Hierarchy:** Specific part override > All parts message > Auto label (`Part {n}/{total}`) > none.
5. **Canvas & Fit:** Never auto-crop unless explicit "Crop to fill" toggle is enabled. Default is scale to fit with solid color, blur, or image background.
6. **Trailing Remainder:** Never discard short remainder clips. If $< 3.0\text{s}$ and merge enabled and sum $\le 180\text{s}$, merge into penultimate clip; otherwise keep independent.
7. **Memory Safety:** Process strictly one clip at a time. Never load whole video files into RAM (`Uint8List`). Stream `content://` source videos via 64KB chunks.
8. **Temp File Lifecycle:** FFmpeg writes to app-private temp file first; verifies copy into destination, then deletes temp file on success, failure, and cancel.

## 4-Tier Storage Strategy (API 28–35+)
1. **PRIMARY (API 28+):** SAF tree URI. Persist tree URI with `takePersistableUriPermission`. On launch, validate permission and folder existence; prompt re-pick if revoked.
2. **FALLBACK (API 28 only):** Direct file writes to `Movies/ShortsSplitter`, guarded by `WRITE_EXTERNAL_STORAGE` (`maxSdkVersion="28"`). Never used on API 29+.
3. **FALLBACK (API 29+):** MediaStore Video collection with `RELATIVE_PATH = "Movies/ShortsSplitter"` and `IS_PENDING`. Never use `RELATIVE_PATH` on API 28.
4. **FINAL FALLBACK:** App-specific external storage (`/Android/data/.../files/ShortsSplitter/`). Zero permissions needed.

## Testing Rules
- Every modification to `PlanCalculator`, `FilterGraphBuilder`, or `ClipWriter` requires accompanying unit tests in `test/`.
- Maintain mocks/fakes using `FakeVideoProcessor` and `FakeClipWriter`.
- Maintain widget tests covering Dashboard, Plan Review, History, and Settings.
- Before completing any task, execute `./scripts/verify.sh` (`analyze` + `test` + `format`).

## Definition of Done (DoD)
- [ ] Code formatted with `dart format .`
- [ ] Static analysis passes with zero warnings (`flutter analyze`)
- [ ] Automated tests pass (`flutter test`)
- [ ] Design tokens and 14 shared widgets utilized across all screens
- [ ] Domain invariants preserved (naming, contiguity, 180s max, memory safety)
- [ ] No FFmpeg leaks outside `lib/features/processing/data/`
- [ ] Error handling wrapped in `Result<T, AppException>` or typed `AppException`
- [ ] Android version guards verified for API 28 through API 35+
- [ ] Documentation updated in `/docs` and verified via `./scripts/docs_check.sh`

## "Ask Before" Mandatory Confirmations
1. Adding, updating, or removing dependencies in `pubspec.yaml`.
2. Altering architecture boundaries or cross-feature imports.
3. Modifying Android `minSdk`, `targetSdk`, or Gradle build configurations.
4. Creating or modifying release signing configurations or ProGuard rules.
