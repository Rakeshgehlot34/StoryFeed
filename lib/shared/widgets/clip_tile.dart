import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:share_plus/share_plus.dart';

import '../../app/theme/app_tokens.dart';
import '../../features/output/domain/models/exported_clip.dart';

/// List tile representing an exported video clip with preview, share, and open actions.
class ClipTile extends StatelessWidget {
  final ExportedClip clip;
  final VoidCallback? onPreview;
  final VoidCallback? onConvert;
  final VoidCallback? onDelete;

  const ClipTile({
    super.key,
    required this.clip,
    this.onPreview,
    this.onConvert,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      margin: const EdgeInsets.only(bottom: AppTokens.spaceSm),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppTokens.spaceMd,
          vertical: AppTokens.spaceSm,
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: colorScheme.primaryContainer,
              child: Text(
                '#${clip.partIndex}',
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onPrimaryContainer,
                ),
              ),
            ),
            const SizedBox(width: AppTokens.spaceMd),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    clip.fileName,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${clip.formattedDuration} • ${clip.formattedSize}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            if (onPreview != null)
              IconButton(
                icon: const Icon(Icons.play_circle_outline),
                tooltip: 'Preview clip',
                onPressed: onPreview,
              ),
            if (onConvert != null)
              IconButton(
                icon: const Icon(Icons.auto_awesome_rounded),
                tooltip: 'Convert to 9:16 Short',
                color: colorScheme.primary,
                onPressed: onConvert,
              ),
            IconButton(
              icon: const Icon(Icons.share_outlined),
              tooltip: 'Share clip',
              onPressed: () {
                Share.shareXFiles([XFile(clip.path)], text: clip.fileName);
              },
            ),
            IconButton(
              icon: const Icon(Icons.folder_open_outlined),
              tooltip: 'Open in system player',
              onPressed: () => OpenFilex.open(clip.path),
            ),
            if (onDelete != null)
              IconButton(
                icon: const Icon(Icons.delete_outline),
                tooltip: 'Delete clip',
                onPressed: onDelete,
              ),
          ],
        ),
      ),
    );
  }
}
