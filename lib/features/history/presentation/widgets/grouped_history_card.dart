import 'dart:io';

import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../app/theme/app_tokens.dart';
import '../../../../core/database/app_database.dart';
import '../../../../shared/services/app_messenger.dart';
import '../../domain/models/project_with_details.dart';

class GroupedHistoryCard extends StatefulWidget {
  final ProjectWithDetails item;
  final bool isSelected;
  final bool isSelectionMode;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final VoidCallback onDelete;
  final void Function(Part part)? onPlayPart;
  final void Function(Part part)? onConvertPart;
  final VoidCallback? onContinueProject;

  const GroupedHistoryCard({
    super.key,
    required this.item,
    this.isSelected = false,
    this.isSelectionMode = false,
    required this.onTap,
    this.onLongPress,
    required this.onDelete,
    this.onPlayPart,
    this.onConvertPart,
    this.onContinueProject,
  });

  @override
  State<GroupedHistoryCard> createState() => _GroupedHistoryCardState();
}

class _GroupedHistoryCardState extends State<GroupedHistoryCard> {
  bool _isExpanded = false;

  void _openFolder(BuildContext context) {
    final folderPath = widget.item.project.folderUriOrPath;
    if (folderPath.isEmpty) {
      AppMessenger.showWarning(context, 'No output location recorded.');
      return;
    }
    if (folderPath.startsWith('content://')) {
      AppMessenger.showInfo(context, 'SAF Directory: $folderPath');
      return;
    }
    OpenFilex.open(folderPath);
  }

  void _shareAll(BuildContext context) {
    final validPaths = widget.item.parts
        .map((p) => p.outputUriOrPath)
        .where((p) => p != null && p.isNotEmpty)
        .cast<String>()
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
      text: 'Clips from ${widget.item.source.displayName} via ShortsSplitter',
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.item.isMultiPart) {
      return _buildStandaloneItem(context);
    }
    return _buildExpandableGroup(context);
  }

  Widget _buildStandaloneItem(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final singlePart =
        widget.item.parts.isNotEmpty ? widget.item.parts.first : null;
    final isConverted = singlePart?.stage == 'converted';

    return Card(
      elevation:
          widget.isSelected ? AppTokens.elevationMd : AppTokens.elevationNone,
      color: widget.isSelected
          ? colorScheme.primaryContainer.withValues(alpha: 0.3)
          : null,
      shape: RoundedRectangleBorder(
        borderRadius: AppTokens.borderRadiusLg,
        side: BorderSide(
          color: widget.isSelected
              ? colorScheme.primary
              : colorScheme.outlineVariant.withValues(alpha: 0.4),
          width: widget.isSelected ? 2 : 1,
        ),
      ),
      child: InkWell(
        onTap: widget.onTap,
        onLongPress: widget.onLongPress,
        borderRadius: AppTokens.borderRadiusLg,
        child: Padding(
          padding: const EdgeInsets.all(AppTokens.spaceMd),
          child: Row(
            children: [
              if (widget.isSelectionMode) ...[
                Checkbox(
                  value: widget.isSelected,
                  onChanged: (_) => widget.onTap(),
                ),
                const SizedBox(width: AppTokens.spaceSm),
              ],
              CircleAvatar(
                radius: 22,
                backgroundColor: colorScheme.primaryContainer,
                child: Icon(
                  isConverted
                      ? Icons.movie_filter_rounded
                      : Icons.movie_rounded,
                  color: colorScheme.primary,
                  size: 22,
                ),
              ),
              const SizedBox(width: AppTokens.spaceMd),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.item.source.displayName,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${(widget.item.source.durationSeconds).toStringAsFixed(1)}s · ${isConverted ? 'Converted Short' : 'Raw Clip'}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (singlePart?.outputUriOrPath != null)
                IconButton(
                  icon: const Icon(Icons.play_circle_outline_rounded),
                  tooltip: 'Play Clip',
                  onPressed: () => widget.onPlayPart?.call(singlePart!),
                ),
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded),
                tooltip: 'Delete project record',
                onPressed: widget.onDelete,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildExpandableGroup(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final total = widget.item.project.totalPartsCount;
    final split = widget.item.splitCount;
    final converted = widget.item.convertedCount;
    final progress = total > 0 ? (split / total) : 0.0;

    return Card(
      elevation:
          widget.isSelected ? AppTokens.elevationMd : AppTokens.elevationNone,
      color: widget.isSelected
          ? colorScheme.primaryContainer.withValues(alpha: 0.3)
          : null,
      shape: RoundedRectangleBorder(
        borderRadius: AppTokens.borderRadiusLg,
        side: BorderSide(
          color: widget.isSelected
              ? colorScheme.primary
              : colorScheme.outlineVariant.withValues(alpha: 0.4),
          width: widget.isSelected ? 2 : 1,
        ),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () {
              if (widget.isSelectionMode) {
                widget.onTap();
              } else {
                setState(() => _isExpanded = !_isExpanded);
              }
            },
            onLongPress: widget.onLongPress,
            borderRadius: AppTokens.borderRadiusLg,
            child: Padding(
              padding: const EdgeInsets.all(AppTokens.spaceMd),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (widget.isSelectionMode) ...[
                        Checkbox(
                          value: widget.isSelected,
                          onChanged: (_) => widget.onTap(),
                        ),
                        const SizedBox(width: AppTokens.spaceSm),
                      ],
                      CircleAvatar(
                        radius: 22,
                        backgroundColor: colorScheme.primaryContainer,
                        child: Icon(
                          Icons.video_collection_rounded,
                          color: colorScheme.primary,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: AppTokens.spaceMd),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.item.source.displayName,
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              widget.item.summaryBadgeText,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colorScheme.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon:
                            const Icon(Icons.delete_outline_rounded, size: 20),
                        tooltip: 'Delete project record',
                        onPressed: widget.onDelete,
                      ),
                      IconButton(
                        icon: Icon(
                          _isExpanded
                              ? Icons.expand_less_rounded
                              : Icons.expand_more_rounded,
                        ),
                        tooltip: _isExpanded ? 'Collapse' : 'Expand parts',
                        onPressed: () =>
                            setState(() => _isExpanded = !_isExpanded),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: progress.clamp(0.0, 1.0),
                      minHeight: 6,
                      backgroundColor: colorScheme.surfaceContainerHighest,
                      valueColor: AlwaysStoppedAnimation(
                        converted == total ? Colors.green : colorScheme.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_isExpanded) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  TextButton.icon(
                    icon: const Icon(Icons.folder_open_rounded, size: 18),
                    label: const Text('Open Folder'),
                    onPressed: () => _openFolder(context),
                  ),
                  const Spacer(),
                  TextButton.icon(
                    icon: const Icon(Icons.share_rounded, size: 18),
                    label: const Text('Share All'),
                    onPressed: () => _shareAll(context),
                  ),
                  if (split < total || converted < split) ...[
                    const SizedBox(width: 8),
                    FilledButton.tonalIcon(
                      icon: const Icon(Icons.play_arrow_rounded, size: 18),
                      label: const Text('Continue'),
                      onPressed: widget.onContinueProject,
                    ),
                  ],
                ],
              ),
            ),
            const Divider(height: 1),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: widget.item.parts.length,
              separatorBuilder: (_, __) => const Divider(height: 1, indent: 56),
              itemBuilder: (context, index) {
                final part = widget.item.parts[index];
                return _buildPartRow(context, part);
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPartRow(BuildContext context, Part part) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isConverted = part.stage == 'converted';
    final isSplit = part.stage == 'split' || isConverted;

    return ListTile(
      dense: true,
      leading: CircleAvatar(
        radius: 14,
        backgroundColor: isConverted
            ? Colors.green.withValues(alpha: 0.15)
            : colorScheme.surfaceContainerHighest,
        child: Text(
          '${part.partIndex}',
          style: theme.textTheme.labelSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: isConverted ? Colors.green.shade800 : colorScheme.onSurface,
          ),
        ),
      ),
      title: Text(
        'Part ${part.partIndex} · ${(part.actualDurationSeconds ?? part.plannedDurationSeconds).toStringAsFixed(1)}s',
        style: theme.textTheme.bodyMedium?.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Text(
        '${part.stage.toUpperCase()} · ${part.status}',
        style: theme.textTheme.bodySmall?.copyWith(
          color: part.hasCapViolation
              ? Colors.orange.shade800
              : colorScheme.onSurfaceVariant,
        ),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isSplit && part.outputUriOrPath != null)
            IconButton(
              icon: const Icon(Icons.play_circle_outline_rounded, size: 20),
              tooltip: 'Play',
              onPressed: () => widget.onPlayPart?.call(part),
            ),
          if (part.stage == 'split' && widget.onConvertPart != null)
            IconButton(
              icon: const Icon(Icons.auto_fix_high_rounded, size: 20),
              tooltip: 'Convert to Short',
              onPressed: () => widget.onConvertPart?.call(part),
            ),
        ],
      ),
    );
  }
}
