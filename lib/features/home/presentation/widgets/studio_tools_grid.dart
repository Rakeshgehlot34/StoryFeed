import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/constants.dart';
import '../../../../app/theme/app_tokens.dart';

/// Representation of a creative studio tool available on the Home Hub.
class StudioToolItem {
  final String id;
  final String title;
  final String description;
  final IconData icon;
  final String route;
  final String tag;
  final Color? color;

  const StudioToolItem({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.route,
    required this.tag,
    this.color,
  });
}

/// 7-tool Studio Grid displaying on-device video production capabilities.
class StudioToolsGrid extends StatelessWidget {
  const StudioToolsGrid({super.key});

  static const List<StudioToolItem> tools = [
    StudioToolItem(
      id: 'shorts',
      title: 'Shorts Maker',
      description: 'Split into contiguous 9:16 clips with 3-min cap',
      icon: Icons.movie_filter_rounded,
      route: AppRoutes.create,
      tag: 'YouTube/Reels',
    ),
    StudioToolItem(
      id: 'split',
      title: 'Custom Split',
      description: 'Split by duration, parts, or points without 3m cap',
      icon: Icons.call_split_rounded,
      route: AppRoutes.customSplit,
      tag: 'Flexible Cut',
    ),
    StudioToolItem(
      id: 'editor',
      title: 'Studio Editor',
      description: 'Trim, crop, rotate, filters, speed & text overlays',
      icon: Icons.auto_fix_high_rounded,
      route: AppRoutes.editor,
      tag: '1-Pass FX',
    ),
    StudioToolItem(
      id: 'convert',
      title: 'Convert & Compress',
      description: 'Convert to MP4, WebM, MKV, animated GIF & compress',
      icon: Icons.transform_rounded,
      route: AppRoutes.convert,
      tag: 'Transcoder',
    ),
    StudioToolItem(
      id: 'audio',
      title: 'Audio Studio',
      description: 'Mute, replace music, voice-over recording & extract',
      icon: Icons.graphic_eq_rounded,
      route: AppRoutes.audioStudio,
      tag: 'Audio Mixer',
    ),
    StudioToolItem(
      id: 'screenshot',
      title: 'Screenshot Tool',
      description: 'Capture exact frames at timestamps or intervals',
      icon: Icons.camera_alt_rounded,
      route: AppRoutes.screenshot,
      tag: 'High-Res Grab',
    ),
    StudioToolItem(
      id: 'merge',
      title: 'Video Merge',
      description: 'Combine 2+ clips with canvas normalization & fades',
      icon: Icons.merge_type_rounded,
      route: AppRoutes.merge,
      tag: 'Multi-Joiner',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final width = MediaQuery.sizeOf(context).width;
    final crossAxisCount = width >= AppTokens.breakpointCompact ? 3 : 2;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Studio Tools',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              '7 On-Device Tools',
              style: theme.textTheme.labelMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppTokens.spaceMd),
        GridView.builder(
          physics: const NeverScrollableScrollPhysics(),
          shrinkWrap: true,
          itemCount: tools.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: AppTokens.spaceMd,
            mainAxisSpacing: AppTokens.spaceMd,
            childAspectRatio: 1.25,
          ),
          itemBuilder: (context, index) {
            final tool = tools[index];
            return _buildToolCard(context, tool, colorScheme, theme);
          },
        ),
      ],
    );
  }

  Widget _buildToolCard(
    BuildContext context,
    StudioToolItem tool,
    ColorScheme colorScheme,
    ThemeData theme,
  ) {
    final isPrimary = tool.id == 'shorts';

    return Card(
      elevation: 0,
      color: isPrimary
          ? colorScheme.primaryContainer.withValues(alpha: 0.7)
          : colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
      shape: RoundedRectangleBorder(
        borderRadius: AppTokens.borderRadiusLg,
        side: BorderSide(
          color: isPrimary
              ? colorScheme.primary.withValues(alpha: 0.4)
              : colorScheme.outlineVariant.withValues(alpha: 0.4),
        ),
      ),
      child: InkWell(
        borderRadius: AppTokens.borderRadiusLg,
        onTap: () => context.push(tool.route),
        child: Padding(
          padding: const EdgeInsets.all(AppTokens.spaceMd),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: isPrimary
                        ? colorScheme.primary
                        : colorScheme.surfaceContainerHighest,
                    foregroundColor: isPrimary
                        ? colorScheme.onPrimary
                        : colorScheme.primary,
                    child: Icon(tool.icon, size: 20),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: isPrimary
                          ? colorScheme.primary.withValues(alpha: 0.15)
                          : colorScheme.outlineVariant.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      tool.tag,
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: isPrimary
                            ? colorScheme.primary
                            : colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tool.title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    tool.description,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontSize: 11,
                      color: colorScheme.onSurfaceVariant,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
