import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/constants.dart';
import '../../../../app/constants/app_strings.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../history/domain/models/project_record.dart';
import '../../../output/domain/models/exported_clip.dart';
import '../../../output/presentation/controllers/output_controller.dart';

/// List of recent projects on Dashboard.
class RecentProjectsSection extends ConsumerWidget {
  final List<ProjectRecord> projects;

  const RecentProjectsSection({super.key, required this.projects});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (projects.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(AppTokens.spaceLg),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: AppTokens.borderRadiusLg,
          border: Border.all(
            color: colorScheme.outlineVariant.withValues(alpha: 0.3),
          ),
        ),
        child: Center(
          child: Text(
            AppStrings.dashRecentEmpty,
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              AppStrings.dashRecentTitle,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            TextButton(
              onPressed: () => context.go(AppRoutes.history),
              child: const Text('View All'),
            ),
          ],
        ),
        const SizedBox(height: AppTokens.spaceSm),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: projects.length,
          separatorBuilder: (_, __) =>
              const SizedBox(height: AppTokens.spaceSm),
          itemBuilder: (context, index) {
            final p = projects[index];
            return Card(
              margin: EdgeInsets.zero,
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: colorScheme.secondaryContainer,
                  child: Icon(
                    Icons.movie_creation_outlined,
                    size: AppTokens.iconMd,
                    color: colorScheme.onSecondaryContainer,
                  ),
                ),
                title: Text(
                  p.videoName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  '${p.totalShortsCount} clips • ${p.formattedDate}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () {
                  // Populate clips in output provider and navigate to results
                  final clips = p.outputFilePaths.asMap().entries.map((e) {
                    return ExportedClip(
                      path: e.value,
                      fileName: e.value.split('/').last,
                      partIndex: e.key + 1,
                      totalParts: p.outputFilePaths.length,
                      duration: Duration.zero,
                      sizeInBytes: 0,
                      createdAt: p.createdAt,
                    );
                  }).toList();

                  ref.read(exportedClipsProvider.notifier).setClips(clips);
                  context.push(AppRoutes.results);
                },
              ),
            );
          },
        ),
      ],
    );
  }
}
