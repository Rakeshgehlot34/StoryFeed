import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/constants.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../../shared/widgets/error_state.dart';
import '../../../../shared/widgets/secondary_button.dart';

/// Full-page error screen for unhandled application-level routing or state exceptions.
class GlobalErrorScreen extends StatelessWidget {
  final String? errorMessage;
  final VoidCallback? onRetry;

  const GlobalErrorScreen({super.key, this.errorMessage, this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Something Went Wrong')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppTokens.spaceLg),
          child: Column(
            children: [
              Expanded(
                child: ErrorState(
                  message: errorMessage ?? 'An unexpected system error occurred. Your clips and preferences are safe.',
                  onRetry: onRetry,
                ),
              ),
              SecondaryButton(
                label: 'Return to Home',
                icon: Icons.home_outlined,
                onPressed: () => context.go(AppRoutes.home),
              ),
              const SizedBox(height: AppTokens.spaceMd),
            ],
          ),
        ),
      ),
    );
  }
}
