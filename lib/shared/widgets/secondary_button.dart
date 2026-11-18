import 'package:flutter/material.dart';

import '../../app/theme/app_tokens.dart';

/// Secondary action button using Material 3 OutlinedButton style.
class SecondaryButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool isFullWidth;

  const SecondaryButton({
    super.key,
    required this.label,
    this.icon,
    required this.onPressed,
    this.isFullWidth = true,
  });

  @override
  Widget build(BuildContext context) {
    Widget child;
    if (icon != null) {
      child = Row(
        mainAxisSize: isFullWidth ? MainAxisSize.max : MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: AppTokens.iconMd),
          const SizedBox(width: AppTokens.spaceSm),
          Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      );
    } else {
      child = Text(label, style: const TextStyle(fontWeight: FontWeight.w600));
    }

    final button = OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        minimumSize: Size(
          isFullWidth ? double.infinity : 100,
          AppTokens.minTouchTarget,
        ),
      ),
      child: child,
    );

    return Semantics(
      button: true,
      enabled: onPressed != null,
      label: label,
      child: button,
    );
  }
}
