# Architecture & Layer Boundaries

Enforce these structural rules to maintain clean layer separation in `shorts_splitter`.

## 1. Dependency Flow Invariant
All dependencies must point strictly **inward**:
```
Presentation Layer (UI Screens, Widgets, Riverpod Controllers)
       │
       ▼
Domain Layer (Entities, Value Objects, Abstract VideoProcessor Interface)
       ▲
       │
Data Layer (Native Implementations, Repositories, SharedPreferences, SAF)
```
- **Presentation Layer** depends only on **Domain Layer**.
- **Data Layer** depends only on **Domain Layer** (implementing domain contracts).
- **Domain Layer** has zero dependencies on Flutter UI frameworks or third-party platform plugins.

## 2. Directory Structure Conventions
```
lib/
  app/                     # Global routing (go_router), theme, and shared constants
  core/                    # Base Result type, AppException hierarchy, logger, utils
  features/
    home/                  # Hub screen and entry point
    video_picker/          # Video asset selection, metadata extraction
    split_config/          # Splitting configuration and slice preview
    processing/            # Transcoding orchestrator and progress streaming
    output/                # Storage destination picker and result gallery
```

## 3. Strict FFmpeg Isolation Rule
- **Single Source of Media Operations:** The `ffmpeg_kit_flutter_new` package must ONLY be imported inside `lib/features/processing/data/ffmpeg_video_processor.dart`.
- **Zero Leakage:** Under no circumstances may any file in `presentation/`, `domain/`, `lib/app/`, or `lib/core/` import `ffmpeg_kit_flutter_new`.
- **Swappable Engine:** The system interacts with media processing strictly via the abstract `VideoProcessor` interface (`lib/features/processing/domain/video_processor.dart`).

## 4. State Management with Riverpod
- **Provider Location:** All Riverpod providers must reside in `lib/features/<feature>/presentation/providers/`.
- **State Types:** Use `AsyncNotifier` or `Notifier` for business state. Use `StateProvider` only for simple primitives.
- **No setState for Cross-Widget State:** Never use `setState` to communicate between screens or sibling features. Reserve `setState` strictly for transient single-widget animations or controller listeners.

## 5. Navigation via GoRouter
- **Route Constants:** All route paths must be declared in `AppRoutes` (`lib/app/constants.dart`).
- **Declarative Navigation:** Navigate exclusively via `context.go(AppRoutes.processing)` or `context.push(AppRoutes.results)`. Never use imperative `Navigator.push(context, MaterialPageRoute(...))`.

## 6. Functional Error Handling
- **No Swallowed Exceptions:** Operations that can fail must return `Result<T, AppException>` (`lib/core/result.dart`).
- **Unified Presentation:** Translate exceptions to user-facing messages strictly through `ErrorMapper.mapToMessage(exception)` (`lib/core/errors/error_mapper.dart`).

