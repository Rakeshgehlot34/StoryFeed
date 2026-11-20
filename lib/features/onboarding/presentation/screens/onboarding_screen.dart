import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/constants.dart';
import '../../../../app/constants/app_strings.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../../core/utils/permission_utils.dart';
import '../../../output/presentation/controllers/output_controller.dart';
import '../controllers/onboarding_controller.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  bool _isFinishing = false;
  bool _permissionsRequested = false;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _finishOnboarding() async {
    if (_isFinishing) return;
    _isFinishing = true;
    try {
      // Prompt all app permissions on initial completion if not yet requested
      if (!_permissionsRequested) {
        await PermissionUtils.requestAllAppPermissions(context: context);
      }
      await ref
          .read(onboardingControllerProvider.notifier)
          .completeOnboarding();
      if (mounted) {
        context.go(AppRoutes.home);
      }
    } finally {
      if (mounted) {
        _isFinishing = false;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Back',
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              _finishOnboarding();
            }
          },
        ),
        actions: [
          TextButton(
            onPressed: _finishOnboarding,
            child: const Text(AppStrings.actionSkip),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: (idx) => setState(() => _currentPage = idx),
                children: [
                  _buildPage(
                    icon: Icons.movie_filter_rounded,
                    title: AppStrings.onbPage1Title,
                    description: AppStrings.onbPage1Desc,
                  ),
                  _buildPermissionsPage(colorScheme),
                  _buildPage(
                    icon: Icons.checklist_rounded,
                    title: AppStrings.onbPage2Title,
                    description: AppStrings.onbPage2Desc,
                  ),
                  _buildStoragePage(colorScheme),
                ],
              ),
            ),
            _buildBottomControls(colorScheme),
          ],
        ),
      ),
    );
  }

  Widget _buildPage({
    required IconData icon,
    required String title,
    required String description,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppTokens.spaceXxl),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircleAvatar(
            radius: 54,
            backgroundColor: colorScheme.primaryContainer,
            child: Icon(icon, size: 54, color: colorScheme.primary),
          ),
          const SizedBox(height: AppTokens.spaceXxl),
          Text(
            title,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppTokens.spaceLg),
          Text(
            description,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildPermissionsPage(ColorScheme colorScheme) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppTokens.spaceXxl),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircleAvatar(
            radius: 54,
            backgroundColor: colorScheme.tertiaryContainer,
            child: Icon(
              Icons.verified_user_rounded,
              size: 54,
              color: colorScheme.onTertiaryContainer,
            ),
          ),
          const SizedBox(height: AppTokens.spaceXxl),
          Text(
            AppStrings.onbPermissionsTitle,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppTokens.spaceMd),
          Text(
            AppStrings.onbPermissionsDesc,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppTokens.spaceLg),
          _buildPermissionItem(
            icon: Icons.video_library_rounded,
            title: 'Photos & Videos',
            subtitle: 'Read source videos to trim & split',
            colorScheme: colorScheme,
          ),
          const SizedBox(height: AppTokens.spaceSm),
          _buildPermissionItem(
            icon: Icons.notifications_active_rounded,
            title: 'Notifications',
            subtitle: 'Show progress during exports',
            colorScheme: colorScheme,
          ),
          const SizedBox(height: AppTokens.spaceSm),
          _buildPermissionItem(
            icon: Icons.mic_rounded,
            title: 'Microphone',
            subtitle: 'Audio Studio voiceover recording',
            colorScheme: colorScheme,
          ),
          const SizedBox(height: AppTokens.spaceLg),
          FilledButton.icon(
            icon: Icon(
              _permissionsRequested
                  ? Icons.check_circle_rounded
                  : Icons.security_rounded,
            ),
            label: Text(
              _permissionsRequested
                  ? AppStrings.onbPermissionsGranted
                  : AppStrings.onbGrantPermissions,
            ),
            onPressed: () async {
              await PermissionUtils.requestAllAppPermissions(context: context);
              if (mounted) {
                setState(() => _permissionsRequested = true);
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPermissionItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required ColorScheme colorScheme,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(AppTokens.spaceSm),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(AppTokens.radiusMd),
          ),
          child: Icon(icon, size: 20, color: colorScheme.primary),
        ),
        const SizedBox(width: AppTokens.spaceMd),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style:
                    const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              ),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 11,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStoragePage(ColorScheme colorScheme) {
    // Safely unwrap — provider may still be loading or in error state on first
    // render; fall back to empty string so the page never shows a blank screen.
    final outputDirAsync = ref.watch(outputDirectoryProvider);
    final outputDir = outputDirAsync.valueOrNull ?? '';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppTokens.spaceXxl),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircleAvatar(
            radius: 54,
            backgroundColor: colorScheme.secondaryContainer,
            child: Icon(
              Icons.folder_shared_rounded,
              size: 54,
              color: colorScheme.onSecondaryContainer,
            ),
          ),
          const SizedBox(height: AppTokens.spaceXxl),
          Text(
            AppStrings.onbPage3Title,
            style: Theme.of(context)
                .textTheme
                .headlineSmall
                ?.copyWith(fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppTokens.spaceLg),
          Text(
            AppStrings.onbPage3Desc,
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: colorScheme.onSurfaceVariant, height: 1.5),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppTokens.spaceLg),
          OutlinedButton.icon(
            icon: const Icon(Icons.folder_open_rounded),
            label: const Text(AppStrings.onbChooseFolder),
            onPressed: () {
              ref.read(outputDirectoryProvider.notifier).pickAndSetDirectory();
            },
          ),
          if (outputDir.isNotEmpty) ...[
            const SizedBox(height: AppTokens.spaceSm),
            Text(
              outputDir,
              style: TextStyle(
                fontSize: 11,
                fontFamily: 'monospace',
                color: colorScheme.outline,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBottomControls(ColorScheme colorScheme) {
    const totalPages = 4;

    return Padding(
      padding: const EdgeInsets.all(AppTokens.spaceLg),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: List.generate(totalPages, (idx) {
              return Container(
                width: _currentPage == idx ? 20 : 8,
                height: 8,
                margin: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  color: _currentPage == idx
                      ? colorScheme.primary
                      : colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(4),
                ),
              );
            }),
          ),
          FilledButton(
            onPressed: () {
              if (_currentPage < totalPages - 1) {
                _pageController.nextPage(
                  duration: AppTokens.durationNormal,
                  curve: Curves.easeInOut,
                );
              } else {
                _finishOnboarding();
              }
            },
            child: Text(
              _currentPage == totalPages - 1
                  ? AppStrings.onbGetStarted
                  : AppStrings.actionNext,
            ),
          ),
        ],
      ),
    );
  }
}
