import 'package:flutter/material.dart';

import '../../../../app/theme/app_tokens.dart';
import '../../../../shared/widgets/info_banner.dart';
import '../../../../shared/widgets/stat_tile.dart';
import '../controllers/merge_controller.dart';

/// Summary card displaying aggregate metrics and compatibility status for a merge project.
class MergeSummaryCard extends StatelessWidget {
  final MergeState state;

  const MergeSummaryCard({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final config = state.config;
    final isFast = config.effectiveMethod.name == 'fast';

    final totalMs = (state.totalDurationSeconds * 1000).round();
    final minutes = totalMs ~/ 60000;
    final seconds = (totalMs % 60000) ~/ 1000;
    final millis = totalMs % 1000;
    final formattedTotal =
        '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}.${(millis ~/ 100).toString()}s';

    final sizeMb = (state.estimatedSizeBytes / (1024 * 1024)).toStringAsFixed(
      1,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: StatTile(
                icon: Icons.video_collection_outlined,
                value: '${state.clipCount}',
                label: 'Total Clips',
              ),
            ),
            const SizedBox(width: AppTokens.spaceSm),
            Expanded(
              child: StatTile(
                icon: Icons.timer_outlined,
                value: formattedTotal,
                label: 'Duration',
                color: colorScheme.secondary,
              ),
            ),
            const SizedBox(width: AppTokens.spaceSm),
            Expanded(
              child: StatTile(
                icon: Icons.data_usage_rounded,
                value: '$sizeMb MB',
                label: 'Est. Size',
                color: colorScheme.tertiary,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppTokens.spaceSm),
        InfoBanner(
          message: isFast
              ? 'Fast Stream Copy mode active: Inputs share codecs and dimensions; concatenation will be lossless and ultra-fast.'
              : 'Precise Re-encode mode active: Clips will be normalized to ${config.resolvedWidth}x${config.resolvedHeight} with ${config.fitMode.label}.',
          type: isFast ? InfoBannerType.info : InfoBannerType.warning,
        ),
      ],
    );
  }
}
