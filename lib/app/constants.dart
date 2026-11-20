/// Global application constants and configuration defaults.
class AppConstants {
  AppConstants._();

  static const String appName = 'ShortsSplitter';
  static const String appVersion = '1.0.0';

  // Video duration bounds (YouTube Shorts allows up to 3 minutes / 180 seconds)
  static const int minClipDurationSeconds = 1;
  static const int maxClipDurationSeconds = 180;
  static const int defaultClipDurationSeconds = 60;

  // Short clip merge threshold (default: 3 seconds)
  static const double trailingClipMergeThresholdSeconds = 3.0;

  // Presets in seconds: 15s, 30s, 45s, 60s, 90s, 2 min (120s), 3 min (180s)
  static const List<int> clipDurationPresets = [15, 30, 45, 60, 90, 120, 180];

  // SharedPreferences Keys
  static const String prefKeyOnboardingCompleted = 'pref_onboarding_completed';
  static const String prefKeyOutputDirectory = 'pref_output_directory';
  static const String prefKeyThemeMode = 'pref_theme_mode';
  static const String prefKeyAccentColor = 'pref_accent_color';
  static const String prefKeyPreferredMode = 'pref_preferred_mode';
  static const String prefKeyPreferredAspectRatio =
      'pref_preferred_aspect_ratio';
  static const String prefKeyMergeShortClip = 'pref_merge_short_clip';
  static const String prefKeyTargetDuration = 'pref_target_duration';
  static const String prefKeyDuplicateHandling = 'pref_duplicate_handling';
  static const String prefKeyCanvasFormat = 'pref_canvas_format';
  static const String prefKeyBackgroundType = 'pref_background_type';
  static const String prefKeyBackgroundColorHex = 'pref_background_color_hex';
  static const String prefKeyOverlayAutoLabel = 'pref_overlay_auto_label';
  static const String prefKeyOverlayPartLabelMode =
      'pref_overlay_part_label_mode';
  static const String prefKeyOverlayTemplate = 'pref_overlay_template';
  static const String prefKeyOverlayPosition = 'pref_overlay_position';
  static const String prefKeyVerticalPosition = 'pref_vertical_position';
  static const String prefKeyVerticalOffsetFraction =
      'pref_vertical_offset_fraction';
  static const String prefKeySinglePartFileNameMode =
      'pref_single_part_file_name_mode';
  static const String prefKeyCropToFill = 'pref_crop_to_fill';
  static const String prefKeyKeepScreenAwake = 'pref_keep_screen_awake';
  static const String prefKeyShowNotification = 'pref_show_notification';
  static const String prefKeyLowStorageThreshold = 'pref_low_storage_threshold';
  static const String prefKeyProjectsHistory = 'pref_projects_history';
}

/// Route paths and route names for GoRouter declarative navigation.
class AppRoutes {
  AppRoutes._();

  // Primary Shell Tabs
  static const String home = '/';
  static const String homeName = 'home';

  static const String create = '/create';
  static const String createName = 'create';

  static const String jobs = '/jobs';
  static const String jobsName = 'jobs';

  static const String history = '/history';
  static const String historyName = 'history';

  static const String settings = '/settings';
  static const String settingsName = 'settings';

  // Studio Tools
  static const String shorts = '/shorts';
  static const String shortsName = 'shorts';

  static const String customSplit = '/split';
  static const String customSplitName = 'custom-split';
  static const String customSplitReview = '/split/review';
  static const String customSplitReviewName = 'custom-split-review';

  static const String editor = '/editor';
  static const String editorName = 'editor';

  static const String convert = '/convert';
  static const String convertName = 'convert';

  static const String audioStudio = '/audio';
  static const String audioStudioName = 'audio-studio';

  static const String screenshot = '/screenshot';
  static const String screenshotName = 'screenshot';

  static const String merge = '/merge';
  static const String mergeName = 'merge';

  // Onboarding
  static const String onboarding = '/onboarding';
  static const String onboardingName = 'onboarding';

  // Create Flow Steps
  static const String createTrim = '/create/trim';
  static const String createTrimName = 'create-trim';

  static const String splitConfig = '/split-config';
  static const String splitConfigName = 'split-config';

  static const String planReview = '/plan-review';
  static const String planReviewName = 'plan-review';

  static const String processing = '/processing';
  static const String processingName = 'processing';

  static const String results = '/results';
  static const String resultsName = 'results';

  // Dedicated Video Player
  static const String player = '/player';
  static const String playerName = 'player';

  // Utility Error Routes
  static const String error = '/error';
  static const String errorName = 'error';

  static const String unsupported = '/unsupported';
  static const String unsupportedName = 'unsupported';
}
