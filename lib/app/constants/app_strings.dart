/// Centralized user-facing strings across all screens, preparing the app for localization.
class AppStrings {
  AppStrings._();

  // General & App
  static const String appName = 'ShortsSplitter';
  static const String appTagline =
      'Fast, Frame-Accurate Video Slicing for Shorts, Reels & TikTok';

  // Navigation Tabs
  static const String navHome = 'Dashboard';
  static const String navCreate = 'Create';
  static const String navJobs = 'Jobs';
  static const String navHistory = 'History';
  static const String navSettings = 'Settings';

  // Actions
  static const String actionCancel = 'Cancel';
  static const String actionConfirm = 'Confirm';
  static const String actionSave = 'Save';
  static const String actionDelete = 'Delete';
  static const String actionRetry = 'Retry';
  static const String actionDone = 'Done';
  static const String actionNext = 'Next';
  static const String actionSkip = 'Skip';
  static const String actionClose = 'Close';
  static const String actionContinue = 'Continue';
  static const String actionDiscard = 'Discard';
  static const String actionChange = 'Change';
  static const String actionUndo = 'Undo';
  static const String createShorts = 'Create Shorts';

  // Onboarding
  static const String onbPage1Title = 'Split Any Video in Seconds';
  static const String onbPage1Desc =
      'Transform long landscape or portrait videos into perfectly sized, contiguous clips optimized for YouTube Shorts, Reels, and TikTok.';

  static const String onbPage2Title = 'Inspect Before You Export';
  static const String onbPage2Desc =
      'Review your exact split plan. Adjust boundaries, merge short trailing fragments, split clips, and add custom part badges with full zero-gap contiguity.';

  static const String onbPage3Title = 'Choose Your Output Folder';
  static const String onbPage3Desc =
      'Select where your finished clips will be saved using Android Scoped Storage, or proceed with the recommended default location.';
  static const String onbPermissionsTitle = 'Allow Permissions';
  static const String onbPermissionsDesc =
      'ShortsSplitter requires storage access to pick and export videos, notifications for background export progress, and microphone for audio recording.';
  static const String onbGrantPermissions = 'Grant All Permissions';
  static const String onbPermissionsGranted = 'Permissions Granted';
  static const String onbGetStarted = 'Get Started';
  static const String onbChooseFolder = 'Select Output Directory';

  // Dashboard (Home)
  static const String dashGreetingMorning = 'Good morning';
  static const String dashGreetingAfternoon = 'Good afternoon';
  static const String dashGreetingEvening = 'Good evening';
  static const String dashCreatePrompt = 'Create New Shorts';
  static const String dashCreateDesc =
      'Pick a video to trim, format, and split into sequential clips.';
  static const String dashSelectVideo = 'Select Video';
  static const String dashStatsTitle = 'Your Splitting Activity';
  static const String dashStatVideos = 'Videos Processed';
  static const String dashStatShorts = 'Shorts Created';
  static const String dashStatDuration = 'Total Runtime';
  static const String dashStatStorage = 'Storage Used';
  static const String dashContinueTitle = 'Resume Unfinished Plan';
  static const String dashContinueSubtitle =
      'You have a planned split waiting to be exported.';
  static const String dashRecentTitle = 'Recent Projects';
  static const String dashRecentEmpty =
      'No projects yet. Create your first split to see it here!';
  static const String dashTipsTitle = 'Creator Tips';
  static const String dashSaveLocation = 'Current Output Destination';

  // Create Flow Steps
  static const String stepSelect = 'Select';
  static const String stepTrim = 'Trim';
  static const String stepSettings = 'Settings';
  static const String stepReview = 'Review';
  static const String stepProcess = 'Processing';
  static const String stepResults = 'Results';

  // Trim Screen
  static const String trimTitle = 'Trim Video Range';
  static const String trimInstructions =
      'Select the section of the video you want to slice into shorts.';
  static const String trimUseFull = 'Use Full Video';
  static const String trimSetStart = 'Set Start to Current';
  static const String trimSetEnd = 'Set End to Current';

  // History
  static const String historyTitle = 'Project History';
  static const String historySearchHint = 'Search projects by name...';
  static const String historyEmpty = 'No history records found.';
  static const String historyDeletedSnackbar = 'Project deleted from history';
  static const String historyMissingFiles = 'Files moved or deleted from disk';

  // Player
  static const String playerTitle = 'Video Preview';
  static const String playerSpeed = 'Speed';

  // Settings
  static const String settingsTitle = 'Settings';
  static const String setSectionOutput = 'Output & Storage';
  static const String setSaveLocation = 'Output Folder';
  static const String setNamingPattern = 'File Naming Pattern';
  static const String setDuplicateHandling = 'Duplicate File Handling';

  static const String setSectionDefaults = 'Splitting Defaults';
  static const String setDefaultDuration = 'Default Clip Duration';
  static const String setDefaultCanvas = 'Default Canvas Format';
  static const String setDefaultBackground = 'Default Background Fill';
  static const String setDefaultMode = 'Default Processing Mode';

  static const String setSectionAppearance = 'Appearance';
  static const String setThemeMode = 'Theme Mode';
  static const String setAccentColor = 'Accent Color';

  static const String setSectionProcessing = 'Processing & Performance';
  static const String setKeepScreenAwake = 'Keep Screen Awake During Export';
  static const String setShowNotification = 'Foreground Notification Progress';
  static const String setClearCache = 'Clear Temporary Files & Thumbnails';

  static const String setSectionAbout = 'About & Privacy';
  static const String setVersion = 'Version';
  static const String setPrivacy =
      'Privacy Notice: All video processing occurs strictly on your local device. No media or telemetry is ever uploaded to external servers.';
  static const String setResetAll = 'Reset All Settings to Default';
  static const String setResetConfirm =
      'Are you sure you want to reset all preferences? This action cannot be undone.';

  // Central Validation Messages
  static const String valSelectVideoFirst = 'Select a video first';
  static const String valVideoUnreadable =
      'This video format is not supported or cannot be read';
  static const String valVideoZeroDuration =
      'Video duration is invalid or zero';
  static const String valStartBeforeEnd = 'Start time must be before end time';
  static const String valRangeMin1s =
      'Selected range must be at least 1 second';
  static const String valClipDurationShortsMax =
      'Clip length cannot be more than 3:00 for Shorts';
  static const String valEnterClipDuration = 'Enter a clip length';
  static const String valClipDurationMin =
      'Clip length must be at least 1 second';
  static const String valChooseBackgroundImage =
      'Choose a background image or pick another background';
  static const String valInvalidHexColor = 'Invalid hex color (use #RRGGBB)';
  static const String valEnterOverlayMessage =
      'Enter the text for your message';
  static const String valChooseLogoImage = 'Choose a logo image file';
  static const String valChooseMusicOrSwitch =
      'Choose a music file or switch audio mode';
  static const String valVoiceoverRequired =
      'Record or select a voice-over file';
  static const String valMicPermissionRequired =
      'Microphone permission is required for voice-over';
  static const String valChooseSaveLocation =
      'Choose where to save your shorts';
  static const String valFolderAccessLost =
      'Folder access was lost. Choose the folder again';
  static const String valExportAlreadyRunning = 'An export is already running';
  static const String valCustomPointsEmpty =
      'Add at least one custom split point';
  static const String valCustomPointDuplicate =
      'This split point has already been added';
  static const String valCustomPointTooClose =
      'Split points must be at least 1 second apart';
  static const String valPartCountExceeded =
      'Part count exceeds safe maximum (500 clips max)';
  static const String valSelectAtLeastOnePart = 'Select at least one part';
  static const String valPartAlreadyProcessed = 'Part is already processed';
  static const String valNotificationPermissionWarning =
      'Notification permission is disabled. Progress will not appear in status bar.';
}
