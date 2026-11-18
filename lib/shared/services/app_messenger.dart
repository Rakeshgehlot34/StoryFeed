import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../../app/theme/app_tokens.dart';
import '../../core/validation/validation_issue.dart';

/// Centralized notification and messaging service enforcing deduplication,
/// severity styling, auto-dismiss durations, accessibility semantics,
/// and route-change cleanup.
class AppMessenger {
  AppMessenger._();

  static final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey =
      GlobalKey<ScaffoldMessengerState>();

  static String? _lastMessage;
  static DateTime? _lastMessageTime;

  /// Shows a structured [ValidationIssue].
  static void showIssue(
    BuildContext context,
    ValidationIssue issue, {
    VoidCallback? onAction,
  }) {
    show(
      context,
      message: issue.message,
      severity: issue.severity,
      actionLabel: issue.actionLabel,
      onAction: onAction,
    );
  }

  /// Displays an actionable snackbar message with deduplication.
  static void show(
    BuildContext context, {
    required String message,
    ValidationSeverity severity = ValidationSeverity.info,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    final now = DateTime.now();
    if (_lastMessage == message &&
        _lastMessageTime != null &&
        now.difference(_lastMessageTime!) <
            const Duration(milliseconds: 1500)) {
      return; // Deduplicate rapid-fire identical messages
    }
    _lastMessage = message;
    _lastMessageTime = now;

    // Announce to screen readers for accessibility
    try {
      // ignore: deprecated_member_use
      SemanticsService.announce(message, TextDirection.ltr);
    } catch (_) {}

    final messenger =
        ScaffoldMessenger.maybeOf(context) ?? scaffoldMessengerKey.currentState;
    if (messenger == null) return;

    messenger.clearSnackBars();

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final Duration duration;
    final Color backgroundColor;
    final Color foregroundColor;
    final IconData icon;

    switch (severity) {
      case ValidationSeverity.error:
        duration = const Duration(seconds: 4);
        backgroundColor = colorScheme.errorContainer;
        foregroundColor = colorScheme.onErrorContainer;
        icon = Icons.error_outline_rounded;
        break;
      case ValidationSeverity.warning:
        duration = const Duration(seconds: 3);
        backgroundColor = Colors.amber.shade900;
        foregroundColor = Colors.white;
        icon = Icons.warning_amber_rounded;
        break;
      case ValidationSeverity.success:
        duration = const Duration(seconds: 2);
        backgroundColor = Colors.green.shade800;
        foregroundColor = Colors.white;
        icon = Icons.check_circle_outline_rounded;
        break;
      case ValidationSeverity.info:
        duration = const Duration(seconds: 2);
        backgroundColor = colorScheme.inverseSurface;
        foregroundColor = colorScheme.onInverseSurface;
        icon = Icons.info_outline_rounded;
        break;
    }

    messenger.showSnackBar(
      SnackBar(
        duration: duration,
        backgroundColor: backgroundColor,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(AppTokens.spaceMd),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusMd),
        ),
        content: Row(
          children: [
            Icon(icon, color: foregroundColor, size: 20),
            const SizedBox(width: AppTokens.spaceSm),
            Expanded(
              child: Text(
                message,
                style: TextStyle(
                  color: foregroundColor,
                  fontWeight: FontWeight.w500,
                  fontSize: 13,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        action: actionLabel != null && onAction != null
            ? SnackBarAction(
                label: actionLabel,
                textColor: foregroundColor,
                onPressed: onAction,
              )
            : null,
      ),
    );
  }

  static void showError(
    BuildContext context,
    String message, {
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    show(
      context,
      message: message,
      severity: ValidationSeverity.error,
      actionLabel: actionLabel,
      onAction: onAction,
    );
  }

  static void showWarning(
    BuildContext context,
    String message, {
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    show(
      context,
      message: message,
      severity: ValidationSeverity.warning,
      actionLabel: actionLabel,
      onAction: onAction,
    );
  }

  static void showSuccess(
    BuildContext context,
    String message, {
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    show(
      context,
      message: message,
      severity: ValidationSeverity.success,
      actionLabel: actionLabel,
      onAction: onAction,
    );
  }

  static void showInfo(
    BuildContext context,
    String message, {
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    show(
      context,
      message: message,
      severity: ValidationSeverity.info,
      actionLabel: actionLabel,
      onAction: onAction,
    );
  }

  /// Clears any currently active or pending snackbars.
  static void clear({BuildContext? context}) {
    if (context != null) {
      ScaffoldMessenger.maybeOf(context)?.clearSnackBars();
    } else {
      scaffoldMessengerKey.currentState?.clearSnackBars();
    }
  }
}
