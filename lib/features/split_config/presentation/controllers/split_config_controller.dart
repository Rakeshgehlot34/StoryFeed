import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../app/constants.dart';
import '../../domain/models/background_spec.dart';
import '../../domain/models/canvas_spec.dart';
import '../../domain/models/overlay_spec.dart';
import '../../domain/models/split_config.dart';
import '../../domain/models/trim_range.dart';

final splitConfigControllerProvider =
    NotifierProvider<SplitConfigController, SplitConfig>(
      SplitConfigController.new,
    );

class SplitConfigController extends Notifier<SplitConfig> {
  @override
  SplitConfig build() {
    _loadPersistedPreferences();
    return const SplitConfig();
  }

  Future<void> _loadPersistedPreferences() async {
    final prefs = await SharedPreferences.getInstance();

    final savedDuration = prefs.getInt(AppConstants.prefKeyTargetDuration);
    final savedModeStr = prefs.getString(AppConstants.prefKeyPreferredMode);
    final savedMerge = prefs.getBool(AppConstants.prefKeyMergeShortClip);
    final savedCanvasStr = prefs.getString(AppConstants.prefKeyCanvasFormat);
    final savedBgStr = prefs.getString(AppConstants.prefKeyBackgroundType);
    final savedBgColor = prefs.getInt(AppConstants.prefKeyBackgroundColorHex);
    final savedAutoLabel = prefs.getBool(AppConstants.prefKeyOverlayAutoLabel);
    final savedTemplate = prefs.getString(AppConstants.prefKeyOverlayTemplate);
    final savedPosStr = prefs.getString(AppConstants.prefKeyOverlayPosition);
    final savedCrop = prefs.getBool(AppConstants.prefKeyCropToFill);

    SplitMode mode = SplitMode.fast;
    if (savedModeStr != null) {
      mode = savedModeStr == 'precise' ? SplitMode.precise : SplitMode.fast;
    }

    CanvasFormat canvasFormat = CanvasFormat.shorts916;
    if (savedCanvasStr != null) {
      canvasFormat = switch (savedCanvasStr) {
        'square11' => CanvasFormat.square11,
        'landscape169' => CanvasFormat.landscape169,
        _ => CanvasFormat.shorts916,
      };
    }

    BackgroundSpec bgSpec = const SolidColorBackgroundSpec();
    if (savedBgStr != null) {
      bgSpec = switch (savedBgStr) {
        'blur' => const BlurBackgroundSpec(),
        _ => SolidColorBackgroundSpec(colorValue: savedBgColor ?? 0xFFFFFFFF),
      };
    }

    OverlayPosition overlayPos = OverlayPosition.top;
    if (savedPosStr != null) {
      overlayPos = switch (savedPosStr) {
        'center' => OverlayPosition.center,
        'bottom' => OverlayPosition.bottom,
        _ => OverlayPosition.top,
      };
    }

    final overlay = OverlaySpec(
      autoLabel: savedAutoLabel ?? true,
      template: savedTemplate ?? 'Part {n}/{total}',
      position: overlayPos,
    );

    state = SplitConfig(
      targetDurationSeconds:
          savedDuration ?? AppConstants.defaultClipDurationSeconds,
      mode: mode,
      canvasSpec: CanvasSpec(format: canvasFormat),
      backgroundSpec: bgSpec,
      overlaySpec: overlay,
      cropToFill: savedCrop ?? false,
      mergeShortTrailingClip: savedMerge ?? true,
    );
  }

  void setTargetDuration(int seconds) {
    final clamped = seconds.clamp(
      AppConstants.minClipDurationSeconds,
      AppConstants.maxClipDurationSeconds,
    );
    state = state.copyWith(targetDurationSeconds: clamped);
    _persistInt(AppConstants.prefKeyTargetDuration, clamped);
  }

  void setMode(SplitMode mode) {
    if (mode == SplitMode.fast && state.requiresReencode) {
      state = state.copyWith(mode: SplitMode.fast);
    } else {
      state = state.copyWith(mode: mode);
    }
    _persistString(AppConstants.prefKeyPreferredMode, mode.name);
  }

  void setCanvasSpec(CanvasSpec spec) {
    state = state.copyWith(canvasSpec: spec);
    _persistString(AppConstants.prefKeyCanvasFormat, spec.format.name);
  }

  void setBackgroundSpec(BackgroundSpec spec) {
    state = state.copyWith(backgroundSpec: spec);
    _persistString(AppConstants.prefKeyBackgroundType, spec.type.name);
    if (spec is SolidColorBackgroundSpec) {
      _persistInt(AppConstants.prefKeyBackgroundColorHex, spec.colorValue);
    }
  }

  void setOverlaySpec(OverlaySpec spec) {
    state = state.copyWith(overlaySpec: spec);
    _persistBool(AppConstants.prefKeyOverlayAutoLabel, spec.autoLabel);
    _persistString(AppConstants.prefKeyOverlayTemplate, spec.template);
    _persistString(AppConstants.prefKeyOverlayPosition, spec.position.name);
  }

  void setCropToFill(bool crop) {
    state = state.copyWith(cropToFill: crop);
    _persistBool(AppConstants.prefKeyCropToFill, crop);
  }

  void setTrimRange(TrimRange? range) {
    state = state.copyWith(trimRange: range);
  }

  void setCustomBaseName(String? name) {
    state = state.copyWith(customBaseName: name);
  }

  void resetForNewVideo() {
    state = state.copyWith(trimRange: null, customBaseName: null);
  }

  TrimRange? get trimRange => state.trimRange;

  void setMergeShortTrailingClip(bool value) {
    state = state.copyWith(mergeShortTrailingClip: value);
    _persistBool(AppConstants.prefKeyMergeShortClip, value);
  }

  void setAspectRatio(AspectRatioOption aspect) {
    switch (aspect) {
      case AspectRatioOption.cropVertical:
        state = state.copyWith(
          cropToFill: true,
          canvasSpec: const CanvasSpec(format: CanvasFormat.shorts916),
          mode: SplitMode.precise,
        );
        break;
      case AspectRatioOption.blurVertical:
        state = state.copyWith(
          cropToFill: false,
          backgroundSpec: const BlurBackgroundSpec(),
          canvasSpec: const CanvasSpec(format: CanvasFormat.shorts916),
          mode: SplitMode.precise,
        );
        break;
      case AspectRatioOption.original:
        state = state.copyWith(
          cropToFill: false,
          backgroundSpec: const SolidColorBackgroundSpec(),
        );
        break;
    }
  }

  Future<void> _persistInt(String key, int value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(key, value);
  }

  Future<void> _persistString(String key, String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, value);
  }

  Future<void> _persistBool(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
  }
}
