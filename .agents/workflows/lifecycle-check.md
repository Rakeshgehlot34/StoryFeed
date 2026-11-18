# /lifecycle-check — Media Playback & Export Lifecycle Verification

Run this workflow to audit video player lifecycles, background export job decoupling, and Android foreground service compatibility across the codebase.

## 1. Scan for VideoPlayerController Leaks
Verify that no Flutter widget or feature code instantiates `VideoPlayerController` directly outside `PlayerService`:
```bash
grep -rn "VideoPlayerController\." lib/ | grep -v "player_service.dart"
```
**Assertion:** The output must be empty. All playback instances must be brokered through `PlayerService.instance` or `ref.watch(playerServiceProvider)`.

## 2. Verify Single Controller Invariant
Ensure `PlayerService` asserts that at most 1 live controller exists in memory:
```bash
grep -rn "liveControllersCount" lib/features/player/data/player_service.dart
```

## 3. Audit Background Export Job Decoupling
Ensure export jobs are managed by domain-layer `ExportJobController` and never cancelled on UI disposal:
```bash
# Check that no export controller uses autoDispose
grep -rn "exportJobControllerProvider" lib/ | grep "autoDispose"

# Check that ProcessingController does not cancel jobs in onDispose
grep -rn "onDispose" lib/features/processing/presentation/controllers/processing_controller.dart
```
**Assertion:** No `autoDispose` on `exportJobControllerProvider`. `ProcessingController` merely observes progress.

## 4. Verify Route & App Lifecycle Hooks
Verify that screens presenting video implement route awareness and pause on cover/background:
```bash
grep -rn "appRouteObserver" lib/features/
```
**Assertion:** `TrimScreen` and `VideoPlayerScreen` subscribe to `appRouteObserver` and pause on `didPushNext()` and stop on `didPop()`.

## 5. Audit Android Foreground Service Types
Ensure Android 14 (API 34) and Android 15 (API 35+) foreground service types are declared:
```bash
grep -rn "android:foregroundServiceType" android/app/src/main/AndroidManifest.xml
```
**Assertion:** Must declare `mediaProcessing|dataSync`.

## 6. Run Complete Test Suite
```bash
flutter analyze
flutter test test/features/player/player_service_test.dart test/features/processing/export_job_controller_test.dart test/features/create/trim_screen_test.dart
```

