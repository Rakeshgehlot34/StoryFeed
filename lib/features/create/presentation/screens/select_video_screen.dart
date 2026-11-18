import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/constants.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../../core/validation/validators/select_video_validator.dart';
import '../../../../shared/services/app_messenger.dart';
import '../../../../shared/widgets/error_state.dart';
import '../../../../shared/widgets/info_banner.dart';
import '../../../../shared/widgets/primary_button.dart';
import '../../../video_picker/presentation/controllers/video_picker_controller.dart';
import '../../../video_picker/presentation/widgets/video_preview_card.dart';

/// Step 1 of Create Flow: Select video from device storage and inspect metadata.
class SelectVideoScreen extends ConsumerStatefulWidget {
  const SelectVideoScreen({super.key});

  @override
  ConsumerState<SelectVideoScreen> createState() => _SelectVideoScreenState();
}

class _SelectVideoScreenState extends ConsumerState<SelectVideoScreen> {
  final GlobalKey _pickerCardKey = GlobalKey();
  String? _inlineError;

  static const _validator = SelectVideoValidator();

  void _onProceed() {
    final video = ref.read(videoPickerControllerProvider).valueOrNull;
    final result = _validator.validate(video);

    if (!result.isValid) {
      final issue = result.firstError!;
      AppMessenger.showIssue(context, issue);
      setState(() => _inlineError = issue.message);
      if (_pickerCardKey.currentContext != null) {
        Scrollable.ensureVisible(
          _pickerCardKey.currentContext!,
          duration: AppTokens.durationNormal,
          curve: Curves.easeOut,
        );
      }
      return;
    }

    setState(() => _inlineError = null);
    context.push(AppRoutes.createTrim);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final pickedAsync = ref.watch(videoPickerControllerProvider);
    final picker = ref.read(videoPickerControllerProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('Step 1: Select Video')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppTokens.spaceLg),
          children: [
            _buildStepIndicator(colorScheme, 1),
            const SizedBox(height: AppTokens.spaceLg),
            if (_inlineError != null) ...[
              InfoBanner(message: _inlineError!, type: InfoBannerType.error),
              const SizedBox(height: AppTokens.spaceMd),
            ],
            pickedAsync.when(
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(40),
                  child: CircularProgressIndicator(),
                ),
              ),
              error: (err, _) => ErrorState(
                message: err.toString(),
                onRetry: () => picker.clear(),
              ),
              data: (video) {
                if (video == null) {
                  return KeyedSubtree(
                    key: _pickerCardKey,
                    child: Column(
                      children: [
                        _buildEmptyPickerCard(
                          context,
                          picker,
                          colorScheme,
                          theme,
                        ),
                        const SizedBox(height: AppTokens.spaceXl),
                        PrimaryButton(
                          label: 'Proceed to Trim',
                          icon: Icons.arrow_forward_rounded,
                          onPressed: _onProceed,
                        ),
                      ],
                    ),
                  );
                }
                return Column(
                  children: [
                    VideoPreviewCard(
                      video: video,
                      onClear: () {
                        setState(() => _inlineError = null);
                        picker.clear();
                      },
                    ),
                    const SizedBox(height: AppTokens.spaceXl),
                    PrimaryButton(
                      label: 'Proceed to Trim',
                      icon: Icons.arrow_forward_rounded,
                      onPressed: _onProceed,
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepIndicator(ColorScheme colorScheme, int currentStep) {
    return Row(
      children: [
        _buildStepBadge('1', 'Select', true, colorScheme),
        Expanded(
          child: Container(height: 2, color: colorScheme.outlineVariant),
        ),
        _buildStepBadge('2', 'Trim', false, colorScheme),
        Expanded(
          child: Container(height: 2, color: colorScheme.outlineVariant),
        ),
        _buildStepBadge('3', 'Settings', false, colorScheme),
        Expanded(
          child: Container(height: 2, color: colorScheme.outlineVariant),
        ),
        _buildStepBadge('4', 'Review', false, colorScheme),
      ],
    );
  }

  Widget _buildStepBadge(
    String number,
    String label,
    bool isActive,
    ColorScheme colorScheme,
  ) {
    return Column(
      children: [
        CircleAvatar(
          radius: 12,
          backgroundColor: isActive
              ? colorScheme.primary
              : colorScheme.surfaceContainerHighest,
          child: Text(
            number,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: isActive ? Colors.white : colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyPickerCard(
    BuildContext context,
    VideoPickerController picker,
    ColorScheme colorScheme,
    ThemeData theme,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(
        vertical: AppTokens.spaceXxl,
        horizontal: AppTokens.spaceLg,
      ),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: AppTokens.borderRadiusXl,
        border: Border.all(
          color: _inlineError != null
              ? colorScheme.error
              : colorScheme.outlineVariant.withValues(alpha: 0.4),
          width: _inlineError != null ? 2.0 : 1.0,
        ),
      ),
      child: Column(
        children: [
          CircleAvatar(
            radius: 36,
            backgroundColor: colorScheme.primaryContainer,
            child: Icon(
              Icons.video_library_rounded,
              size: 40,
              color: colorScheme.primary,
            ),
          ),
          const SizedBox(height: AppTokens.spaceLg),
          Text(
            'Choose Video to Split',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: AppTokens.spaceSm),
          Text(
            'Select an MP4, MOV, or standard video file from your device.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppTokens.spaceXl),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  icon: const Icon(Icons.photo_library_outlined),
                  label: const Text('Gallery'),
                  onPressed: () {
                    setState(() => _inlineError = null);
                    picker.pickFromGallery();
                  },
                ),
              ),
              const SizedBox(width: AppTokens.spaceSm),
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.folder_open_outlined),
                  label: const Text('Files'),
                  onPressed: () {
                    setState(() => _inlineError = null);
                    picker.pickFromFile();
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
