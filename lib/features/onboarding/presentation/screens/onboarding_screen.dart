import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/constants.dart';
import '../../../../app/constants/app_strings.dart';
import '../../../../app/theme/app_tokens.dart';
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

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _finishOnboarding() async {
    await ref.read(onboardingControllerProvider.notifier).completeOnboarding();
    if (mounted) {
      context.go(AppRoutes.home);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        actions: [
          if (_currentPage < 2)
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

  Widget _buildStoragePage(ColorScheme colorScheme) {
    final outputDir = ref.watch(outputDirectoryProvider).valueOrNull ?? '';

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
            style: Theme.of(context).textTheme.headlineSmall
                ?.copyWith(fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppTokens.spaceLg),
          Text(
            AppStrings.onbPage3Desc,
            style: Theme.of(context).textTheme.bodyMedium
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
    return Padding(
      padding: const EdgeInsets.all(AppTokens.spaceLg),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: List.generate(3, (idx) {
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
              if (_currentPage < 2) {
                _pageController.nextPage(
                  duration: AppTokens.durationNormal,
                  curve: Curves.easeInOut,
                );
              } else {
                _finishOnboarding();
              }
            },
            child: Text(
              _currentPage == 2
                  ? AppStrings.onbGetStarted
                  : AppStrings.actionNext,
            ),
          ),
        ],
      ),
    );
  }
}
