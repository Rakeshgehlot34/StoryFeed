import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/constants.dart';
import '../../../../app/constants/app_strings.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../video_picker/presentation/controllers/video_picker_controller.dart';

/// Hero card prompting user to select a video and initiate the split pipeline.
class DashboardCreateCard extends ConsumerWidget {
  const DashboardCreateCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final picker = ref.read(videoPickerControllerProvider.notifier);

    return Container(
      padding: const EdgeInsets.all(AppTokens.spaceXl),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: AppTokens.borderRadiusXl,
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: colorScheme.primaryContainer,
                child: Icon(
                  Icons.video_call_rounded,
                  size: AppTokens.iconLg,
                  color: colorScheme.primary,
                ),
              ),
              const SizedBox(width: AppTokens.spaceMd),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppStrings.dashCreatePrompt,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      AppStrings.dashCreateDesc,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTokens.spaceLg),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  icon: const Icon(Icons.photo_library_outlined, size: 18),
                  label: const Text('Pick Gallery'),
                  onPressed: () async {
                    await picker.pickFromGallery();
                    if (context.mounted &&
                        ref.read(videoPickerControllerProvider).valueOrNull !=
                            null) {
                      await context.push(AppRoutes.createTrim);
                    }
                  },
                ),
              ),
              const SizedBox(width: AppTokens.spaceSm),
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.folder_open_outlined, size: 18),
                  label: const Text('Browse Files'),
                  onPressed: () async {
                    await picker.pickFromFile();
                    if (context.mounted &&
                        ref.read(videoPickerControllerProvider).valueOrNull !=
                            null) {
                      await context.push(AppRoutes.createTrim);
                    }
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
