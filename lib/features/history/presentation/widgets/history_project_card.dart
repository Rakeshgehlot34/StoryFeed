import 'dart:io';

import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path/path.dart' as p;
import 'package:share_plus/share_plus.dart';

import '../../../../app/theme/app_tokens.dart';
import '../../../../shared/services/app_messenger.dart';
import '../../domain/models/project_record.dart';

/// Card representing a past split project in the History list with quick actions
/// and partial completion indicator badges.
class HistoryProjectCard extends StatelessWidget {
  final ProjectRecord project;
  final bool isSelected;
  final bool isSelectionMode;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final VoidCallback onDelete;

  const HistoryProjectCard({
    super.key,
    required this.project,
    this.isSelected = false,
    this.isSelectionMode = false,
    required this.onTap,
    this.onLongPress,
    required this.onDelete,
  });

  void _shareAll(BuildContext context) {
    final validPaths = project.outputFilePaths
        .where(
          (path) => path.startsWith('content://') || File(path).existsSync(),
        )
        .toList();

    if (validPaths.isEmpty) {
      AppMessenger.showWarning(context, 'No valid clip files to share.');
      return;
    }

    Share.shareXFiles(
      validPaths.map((path) => XFile(path)).toList(),
      text: 'Clips from ${project.videoName} via ShortsSplitter',
    );
  }

  void _openFolder(BuildContext context) {
    if (project.outputFilePaths.isEmpty) {
      AppMessenger.showWarning(context, 'No output location recorded.');
      return;
    }
    final first = project.outputFilePaths.first;
    if (first.startsWith('content://')) {
      AppMessenger.showInfo(context, 'SAF Directory: $first');
      return;
    }
    final dir = p.dirname(first);
    OpenFilex.open(dir);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final filesAvailable =
        project.isFilesAvailable ?? project.hasValidFilesOnDisk;

    return Card(
      elevation: isSelected ? AppTokens.elevationMd : AppTokens.elevationNone,
      color: isSelected
          ? colorScheme.primaryContainer.withValues(alpha: 0.3)
          : null,
      shape: RoundedRectangleBorder(
        borderRadius: AppTokens.borderRadiusLg,
        side: BorderSide(
          color: isSelected
              ? colorScheme.primary
              : colorScheme.outlineVariant.withValues(alpha: 0.4),
          width: isSelected ? 2 : 1,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: AppTokens.borderRadiusLg,
        child: Padding(
          padding: const EdgeInsets.all(AppTokens.spaceMd),
          child: Row(
            children: [
              if (isSelectionMode) ...[
                Checkbox(value: isSelected, onChanged: (_) => onTap()),
                const SizedBox(width: AppTokens.spaceSm),
              ],
              CircleAvatar(
                radius: 22,
                backgroundColor: filesAvailable
                    ? (project.isPartiallyProcessed
                        ? colorScheme.secondaryContainer
                        : colorScheme.primaryContainer)
                    : colorScheme.errorContainer.withValues(alpha: 0.6),
                child: Icon(
                  filesAvailable
                      ? (project.isPartiallyProcessed
                          ? Icons.pie_chart_outline_rounded
                          : Icons.movie_creation_outlined)
                      : Icons.broken_image_outlined,
                  color: filesAvailable
                      ? (project.isPartiallyProcessed
                          ? colorScheme.secondary
                          : colorScheme.primary)
                      : colorScheme.error,
                  size: AppTokens.iconMd,
                ),
              ),
              const SizedBox(width: AppTokens.spaceMd),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      project.videoName,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    _buildSubtitle(theme, colorScheme),
                    if (!filesAvailable) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Files moved or deleted from disk',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: colorScheme.error,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (!isSelectionMode) ...[
                IconButton(
                  icon: const Icon(Icons.delete_outline_rounded, size: 20),
                  tooltip: 'Delete project record',
                  onPressed: onDelete,
                ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert_rounded, size: 20),
                  tooltip: 'More actions',
                  onSelected: (val) {
                    if (val == 'share') _shareAll(context);
                    if (val == 'open_folder') _openFolder(context);
                  },
                  itemBuilder: (ctx) => [
                    const PopupMenuItem(
                      value: 'share',
                      child: Row(
                        children: [
                          Icon(Icons.share_outlined, size: 18),
                          SizedBox(width: 8),
                          Text('Share All'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'open_folder',
                      child: Row(
                        children: [
                          Icon(Icons.folder_open_outlined, size: 18),
                          SizedBox(width: 8),
                          Text('Open Folder'),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSubtitle(ThemeData theme, ColorScheme colorScheme) {
    if (project.isPartiallyProcessed) {
      final ratio = project.actualProcessedCount /
          (project.totalShortsCount > 0 ? project.totalShortsCount : 1);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 5,
                  vertical: 1.5,
                ),
                decoration: BoxDecoration(
                  color: colorScheme.secondaryContainer,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  project.processedBadgeText,
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSecondaryContainer,
                    fontSize: 10,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  '${project.canvasFormat} • ${project.formattedDate}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: 3,
              backgroundColor: colorScheme.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation(colorScheme.secondary),
            ),
          ),
        ],
      );
    }

    return Text(
      '${project.totalShortsCount} shorts • ${project.canvasFormat} • ${project.formattedDate}',
      style: theme.textTheme.bodySmall?.copyWith(
        color: colorScheme.onSurfaceVariant,
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}
