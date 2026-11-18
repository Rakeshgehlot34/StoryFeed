import 'package:flutter/material.dart';

import '../../app/theme/app_tokens.dart';

/// Primary action button honoring Material 3 filled button style and min 48dp touch targets.
class PrimaryButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool isLoading;
  final bool isFullWidth;

  const PrimaryButton({
    super.key,
    required this.label,
    this.icon,
    required this.onPressed,
    this.isLoading = false,
    this.isFullWidth = true,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveOnPressed = isLoading ? null : onPressed;

    Widget child;
    if (isLoading) {
      child = const SizedBox(
        height: 20,
        width: 20,
        child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
      );
    } else if (icon != null) {
      child = Row(
        mainAxisSize: isFullWidth ? MainAxisSize.max : MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: AppTokens.iconMd),
          const SizedBox(width: AppTokens.spaceSm),
          Flexible(
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.bold),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      );
    } else {
      child = Text(label, style: const TextStyle(fontWeight: FontWeight.bold));
    }

    final button = FilledButton(
      onPressed: effectiveOnPressed,
      style: FilledButton.styleFrom(
        minimumSize: Size(
          isFullWidth ? double.infinity : 120,
          AppTokens.minTouchTarget,
        ),
      ),
      child: child,
    );

    return Semantics(
      button: true,
      enabled: effectiveOnPressed != null,
      label: label,
      child: button,
    );
  }
}
