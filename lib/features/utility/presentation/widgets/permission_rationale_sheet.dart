import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../../app/theme/app_tokens.dart';
import '../../../../shared/widgets/primary_button.dart';
import '../../../../shared/widgets/secondary_button.dart';

/// Bottom sheet explaining why device storage or notifications permissions are requested.
class PermissionRationaleSheet extends StatelessWidget {
  final String title;
  final String message;
  final IconData icon;

  const PermissionRationaleSheet({
    super.key,
    required this.title,
    required this.message,
    this.icon = Icons.folder_special_rounded,
  });

  static Future<void> show({
    required BuildContext context,
    required String title,
    required String message,
    IconData icon = Icons.folder_special_rounded,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) =>
          PermissionRationaleSheet(title: title, message: message, icon: icon),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppTokens.spaceXl,
          vertical: AppTokens.spaceLg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: AppTokens.spaceLg),
            Icon(icon, size: 48, color: colorScheme.primary),
            const SizedBox(height: AppTokens.spaceMd),
            Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppTokens.spaceSm),
            Text(
              message,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppTokens.spaceXl),
            PrimaryButton(
              label: 'Open Settings',
              icon: Icons.settings_outlined,
              onPressed: () async {
                Navigator.of(context).pop();
                await openAppSettings();
              },
            ),
            const SizedBox(height: AppTokens.spaceSm),
            SecondaryButton(
              label: 'Maybe Later',
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ),
    );
  }
}
