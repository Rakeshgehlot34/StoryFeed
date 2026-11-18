import 'package:flutter/material.dart';

import '../../app/theme/app_tokens.dart';

enum InfoBannerType { info, warning, error }

/// Status banner supporting info, warning, and error styles.
class InfoBanner extends StatelessWidget {
  final String message;
  final InfoBannerType type;
  final Widget? trailing;

  const InfoBanner({
    super.key,
    required this.message,
    this.type = InfoBannerType.info,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final (bgColor, fgColor, icon) = switch (type) {
      InfoBannerType.info => (
        colorScheme.primaryContainer.withValues(alpha: 0.6),
        colorScheme.onPrimaryContainer,
        Icons.info_outline_rounded,
      ),
      InfoBannerType.warning => (
        colorScheme.errorContainer.withValues(alpha: 0.4),
        colorScheme.onErrorContainer,
        Icons.warning_amber_rounded,
      ),
      InfoBannerType.error => (
        colorScheme.errorContainer,
        colorScheme.onErrorContainer,
        Icons.error_outline_rounded,
      ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTokens.spaceMd,
        vertical: AppTokens.spaceSm,
      ),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: AppTokens.borderRadiusMd,
      ),
      child: Row(
        children: [
          Icon(icon, size: AppTokens.iconMd, color: fgColor),
          const SizedBox(width: AppTokens.spaceSm),
          Expanded(
            child: Text(
              message,
              style: theme.textTheme.bodySmall?.copyWith(
                color: fgColor,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}
