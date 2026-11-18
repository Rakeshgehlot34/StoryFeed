import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/constants.dart';
import '../../../../app/constants/app_strings.dart';
import '../../../../app/theme.dart';
import '../../../../app/theme/app_tokens.dart';

/// Top header on Dashboard with dynamic greeting and theme mode toggle.
class GreetingHeader extends ConsumerWidget {
  const GreetingHeader({super.key});

  String get _greeting {
    final hour = DateTime.now().hour;
    if (hour < 12) return AppStrings.dashGreetingMorning;
    if (hour < 17) return AppStrings.dashGreetingAfternoon;
    return AppStrings.dashGreetingEvening;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final themeMode = ref.watch(themeModeProvider);
    final themeNotifier = ref.read(themeModeProvider.notifier);

    return Row(
      children: [
        CircleAvatar(
          radius: 20,
          backgroundColor: colorScheme.primary,
          child: const Icon(
            Icons.content_cut_rounded,
            color: Colors.white,
            size: AppTokens.iconMd,
          ),
        ),
        const SizedBox(width: AppTokens.spaceMd),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _greeting,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              Text(
                AppConstants.appName,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          icon: Icon(
            themeMode == ThemeMode.dark
                ? Icons.light_mode_outlined
                : Icons.dark_mode_outlined,
          ),
          tooltip: 'Toggle Theme',
          onPressed: () => themeNotifier.toggleTheme(),
        ),
      ],
    );
  }
}
