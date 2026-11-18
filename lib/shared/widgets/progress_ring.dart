import 'package:flutter/material.dart';

import '../../app/theme/app_tokens.dart';

/// Circular progress ring displaying percentage text and status message.
class ProgressRing extends StatelessWidget {
  final double progress; // 0.0 to 1.0
  final double size;
  final String? statusText;

  const ProgressRing({
    super.key,
    required this.progress,
    this.size = 140,
    this.statusText,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final clamped = progress.clamp(0.0, 1.0);
    final percent = (clamped * 100).round();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: size,
          height: size,
          child: Stack(
            fit: StackFit.expand,
            children: [
              CircularProgressIndicator(
                value: clamped,
                strokeWidth: 8,
                backgroundColor: colorScheme.surfaceContainerHighest,
                valueColor: AlwaysStoppedAnimation<Color>(colorScheme.primary),
              ),
              Center(
                child: Text(
                  '$percent%',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (statusText != null) ...[
          const SizedBox(height: AppTokens.spaceMd),
          Text(
            statusText!,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }
}
