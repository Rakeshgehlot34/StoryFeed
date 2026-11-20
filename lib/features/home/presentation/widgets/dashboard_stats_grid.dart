import 'package:flutter/material.dart';

import '../../../../app/constants/app_strings.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../../shared/widgets/stat_tile.dart';
import '../../domain/models/dashboard_stats.dart';

/// Grid of 4 stat tiles summarizing the creator's productivity.
class DashboardStatsGrid extends StatelessWidget {
  final DashboardStats stats;

  const DashboardStatsGrid({super.key, required this.stats});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          AppStrings.dashStatsTitle,
          style: Theme.of(context)
              .textTheme
              .titleSmall
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: AppTokens.spaceSm),
        Row(
          children: [
            Expanded(
              child: StatTile(
                icon: Icons.movie_outlined,
                value: '${stats.totalVideosProcessed}',
                label: AppStrings.dashStatVideos,
              ),
            ),
            const SizedBox(width: AppTokens.spaceSm),
            Expanded(
              child: StatTile(
                icon: Icons.view_carousel_outlined,
                value: '${stats.totalShortsCreated}',
                label: AppStrings.dashStatShorts,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppTokens.spaceSm),
        Row(
          children: [
            Expanded(
              child: StatTile(
                icon: Icons.timer_outlined,
                value: stats.formattedDuration,
                label: AppStrings.dashStatDuration,
              ),
            ),
            const SizedBox(width: AppTokens.spaceSm),
            Expanded(
              child: StatTile(
                icon: Icons.storage_outlined,
                value: stats.formattedStorage,
                label: AppStrings.dashStatStorage,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
