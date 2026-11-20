import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/constants.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../../shared/widgets/primary_button.dart';
import '../../../../shared/widgets/secondary_button.dart';
import '../../../../shared/widgets/section_card.dart';

/// Screen displayed when an imported video cannot be decoded or processed.
class UnsupportedVideoScreen extends StatelessWidget {
  final String? reason;

  const UnsupportedVideoScreen({super.key, this.reason});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Unsupported Media'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go(AppRoutes.home),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppTokens.spaceXl),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: colorScheme.errorContainer.withValues(alpha: 0.6),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.videocam_off_rounded,
                  size: 44,
                  color: colorScheme.error,
                ),
              ),
              const SizedBox(height: AppTokens.spaceLg),
              Text(
                'Video Cannot Be Processed',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppTokens.spaceSm),
              Text(
                reason ??
                    'The selected video format or codec is not supported by the hardware decoder on this device.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppTokens.spaceXl),
              SectionCard(
                title: 'Recommended Solutions',
                child: Column(
                  children: [
                    _buildTipRow(
                      Icons.movie_creation_outlined,
                      'Ensure container is MP4 or MOV with H.264/AVC or H.265/HEVC video codec.',
                    ),
                    const SizedBox(height: AppTokens.spaceSm),
                    _buildTipRow(
                      Icons.audiotrack_outlined,
                      'Verify audio is AAC or MP3 encoded.',
                    ),
                    const SizedBox(height: AppTokens.spaceSm),
                    _buildTipRow(
                      Icons.sd_card_alert_outlined,
                      'Make sure the video file is not 0 bytes or corrupted.',
                    ),
                  ],
                ),
              ),
              const Spacer(),
              PrimaryButton(
                label: 'Choose Another Video',
                icon: Icons.video_library_outlined,
                onPressed: () => context.go(AppRoutes.create),
              ),
              const SizedBox(height: AppTokens.spaceSm),
              SecondaryButton(
                label: 'Return to Dashboard',
                icon: Icons.home_outlined,
                onPressed: () => context.go(AppRoutes.home),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTipRow(IconData icon, String message) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18),
        const SizedBox(width: AppTokens.spaceSm),
        Expanded(child: Text(message, style: const TextStyle(fontSize: 13))),
      ],
    );
  }
}
