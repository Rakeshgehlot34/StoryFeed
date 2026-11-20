import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/audio_studio/presentation/screens/audio_studio_screen.dart';
import '../features/convert/presentation/screens/convert_screen.dart';
import '../features/create/presentation/screens/select_video_screen.dart';
import '../features/create/presentation/screens/trim_screen.dart';
import '../features/custom_split/presentation/screens/custom_split_plan_review_screen.dart';
import '../features/custom_split/presentation/screens/custom_split_screen.dart';
import '../features/editor/presentation/screens/editor_screen.dart';
import '../features/history/presentation/screens/history_screen.dart';
import '../features/home/presentation/screens/dashboard_screen.dart';
import '../features/jobs/presentation/screens/jobs_screen.dart';
import '../features/merge/presentation/screens/merge_screen.dart';
import '../features/onboarding/presentation/controllers/onboarding_controller.dart';
import '../features/onboarding/presentation/screens/onboarding_screen.dart';
import '../features/output/domain/models/exported_clip.dart';
import '../features/output/presentation/screens/results_screen.dart';
import '../features/plan_review/presentation/screens/plan_review_screen.dart';
import '../features/player/presentation/screens/video_player_screen.dart';
import '../features/processing/presentation/screens/processing_screen.dart';
import '../features/screenshot/presentation/screens/screenshot_screen.dart';
import '../features/settings/presentation/screens/settings_screen.dart';
import '../features/split_config/presentation/screens/split_config_screen.dart';
import '../features/utility/presentation/screens/global_error_screen.dart';
import '../features/utility/presentation/screens/unsupported_video_screen.dart';
import '../shared/widgets/app_scaffold.dart';
import 'constants.dart';

/// Route observer for monitoring route push/pop to enforce media playback lifecycles.
final appRouteObserver = RouteObserver<ModalRoute<void>>();

/// A [ChangeNotifier] that notifies GoRouter to re-evaluate redirects whenever
/// a Riverpod [ProviderListenable] emits a new value.
class _ProviderChangeNotifier<T> extends ChangeNotifier {
  _ProviderChangeNotifier(ProviderSubscription<T> subscription)
      : _subscription = subscription;

  final ProviderSubscription<T> _subscription;

  static _ProviderChangeNotifier<T> watch<T>(
    Ref ref,
    ProviderListenable<T> provider,
  ) {
    late _ProviderChangeNotifier<T> notifier;
    final sub = ref.listen(provider, (_, __) => notifier.notifyListeners());
    notifier = _ProviderChangeNotifier<T>(sub);
    return notifier;
  }

  @override
  void dispose() {
    _subscription.close();
    super.dispose();
  }
}

/// Centralized GoRouter provider for declarative navigation using AppRoutes constants.
final routerProvider = Provider<GoRouter>((ref) {
  final refreshNotifier = _ProviderChangeNotifier.watch(
    ref,
    onboardingControllerProvider,
  );
  ref.onDispose(refreshNotifier.dispose);

  return GoRouter(
    initialLocation: AppRoutes.home,
    refreshListenable: refreshNotifier,
    observers: [appRouteObserver],
    redirect: (context, state) {
      final onboardingAsync = ref.read(onboardingControllerProvider);

      // While the onboarding state is still loading, do not redirect — wait
      // for it to resolve so we never land on onboarding without a back stack.
      if (onboardingAsync.isLoading) return null;

      // On error, treat as not completed so the user sees onboarding.
      final isOnboardingCompleted = onboardingAsync.valueOrNull ?? false;
      final isOnboardingRoute = state.uri.path == AppRoutes.onboarding;

      if (!isOnboardingCompleted && !isOnboardingRoute) {
        return AppRoutes.onboarding;
      }
      if (isOnboardingCompleted && isOnboardingRoute) {
        return AppRoutes.home;
      }
      return null;
    },
    routes: [
      // Primary 5-Tab Adaptive Shell with preserved branch state
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return AppScaffold(
            selectedIndex: navigationShell.currentIndex,
            body: navigationShell,
            onDestinationSelected: (index) {
              navigationShell.goBranch(
                index,
                initialLocation: index == navigationShell.currentIndex,
              );
            },
          );
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.home,
                name: AppRoutes.homeName,
                builder: (context, state) => const DashboardScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.create,
                name: AppRoutes.createName,
                builder: (context, state) => const SelectVideoScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.jobs,
                name: AppRoutes.jobsName,
                builder: (context, state) => const JobsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.history,
                name: AppRoutes.historyName,
                builder: (context, state) => const HistoryScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.settings,
                name: AppRoutes.settingsName,
                builder: (context, state) => const SettingsScreen(),
              ),
            ],
          ),
        ],
      ),

      // Studio Tools Entry Points
      GoRoute(
        path: AppRoutes.shorts,
        name: AppRoutes.shortsName,
        builder: (context, state) => const SelectVideoScreen(),
      ),
      GoRoute(
        path: AppRoutes.customSplit,
        name: AppRoutes.customSplitName,
        builder: (context, state) => const CustomSplitScreen(),
      ),
      GoRoute(
        path: AppRoutes.customSplitReview,
        name: AppRoutes.customSplitReviewName,
        builder: (context, state) => const CustomSplitPlanReviewScreen(),
      ),
      GoRoute(
        path: AppRoutes.editor,
        name: AppRoutes.editorName,
        builder: (context, state) => const EditorScreen(),
      ),
      GoRoute(
        path: AppRoutes.convert,
        name: AppRoutes.convertName,
        builder: (context, state) => const ConvertScreen(),
      ),
      GoRoute(
        path: AppRoutes.audioStudio,
        name: AppRoutes.audioStudioName,
        builder: (context, state) => const AudioStudioScreen(),
      ),
      GoRoute(
        path: AppRoutes.screenshot,
        name: AppRoutes.screenshotName,
        builder: (context, state) => const ScreenshotScreen(),
      ),
      GoRoute(
        path: AppRoutes.merge,
        name: AppRoutes.mergeName,
        builder: (context, state) => const MergeScreen(),
      ),

      // Standalone Routes
      GoRoute(
        path: AppRoutes.onboarding,
        name: AppRoutes.onboardingName,
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: AppRoutes.createTrim,
        name: AppRoutes.createTrimName,
        builder: (context, state) => const TrimScreen(),
      ),
      GoRoute(
        path: AppRoutes.splitConfig,
        name: AppRoutes.splitConfigName,
        builder: (context, state) => const SplitConfigScreen(),
      ),
      GoRoute(
        path: AppRoutes.planReview,
        name: AppRoutes.planReviewName,
        builder: (context, state) => const PlanReviewScreen(),
      ),
      GoRoute(
        path: AppRoutes.processing,
        name: AppRoutes.processingName,
        builder: (context, state) => const ProcessingScreen(),
      ),
      GoRoute(
        path: AppRoutes.results,
        name: AppRoutes.resultsName,
        builder: (context, state) => const ResultsScreen(),
      ),
      GoRoute(
        path: AppRoutes.player,
        name: AppRoutes.playerName,
        builder: (context, state) {
          final extra = state.extra;
          if (extra is Map<String, dynamic>) {
            final clips = (extra['clips'] as List<dynamic>?)
                    ?.whereType<ExportedClip>()
                    .toList() ??
                const [];
            final initialIndex = (extra['initialIndex'] as int?) ?? 0;
            return VideoPlayerScreen(clips: clips, initialIndex: initialIndex);
          }
          return const VideoPlayerScreen(clips: []);
        },
      ),
      GoRoute(
        path: AppRoutes.error,
        name: AppRoutes.errorName,
        builder: (context, state) {
          final message = state.extra as String?;
          return GlobalErrorScreen(errorMessage: message);
        },
      ),
      GoRoute(
        path: AppRoutes.unsupported,
        name: AppRoutes.unsupportedName,
        builder: (context, state) {
          final reason = state.extra as String?;
          return UnsupportedVideoScreen(reason: reason);
        },
      ),
    ],
  );
});
