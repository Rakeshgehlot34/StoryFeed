import 'package:flutter/material.dart';

import '../../../../app/constants/app_strings.dart';
import '../../../../app/theme/app_tokens.dart';

/// Dismissible carousel providing helpful tips for Shorts creators.
class CreatorTipsCarousel extends StatefulWidget {
  final VoidCallback onDismiss;

  const CreatorTipsCarousel({super.key, required this.onDismiss});

  @override
  State<CreatorTipsCarousel> createState() => _CreatorTipsCarouselState();
}

class _CreatorTipsCarouselState extends State<CreatorTipsCarousel> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  static const _tips = [
    (
      'Safe Area Margins',
      'Keep part numbers inside the top or bottom safe zone to prevent YouTube action buttons from obscuring your text.',
      Icons.crop_free_rounded,
    ),
    (
      'Optimal Clip Length',
      '60-second clips balance storytelling and viewer retention, while 15s clips are perfect for high-energy hooks.',
      Icons.speed_rounded,
    ),
    (
      'Seamless Contiguity',
      'ShortsSplitter ensures zero gaps between clips. Trailing fragments under 3s are automatically merged.',
      Icons.auto_awesome_rounded,
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(AppTokens.spaceMd),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: AppTokens.borderRadiusLg,
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.lightbulb_outline_rounded,
                size: 18,
                color: colorScheme.primary,
              ),
              const SizedBox(width: AppTokens.spaceSm),
              Text(
                AppStrings.dashTipsTitle,
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close_rounded, size: 18),
                tooltip: 'Dismiss Tips',
                onPressed: widget.onDismiss,
              ),
            ],
          ),
          const SizedBox(height: AppTokens.spaceSm),
          SizedBox(
            height: 70,
            child: PageView.builder(
              controller: _pageController,
              itemCount: _tips.length,
              onPageChanged: (idx) => setState(() => _currentPage = idx),
              itemBuilder: (context, index) {
                final tip = _tips[index];
                return Row(
                  children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: colorScheme.primary.withValues(
                        alpha: 0.1,
                      ),
                      child: Icon(tip.$3, size: 18, color: colorScheme.primary),
                    ),
                    const SizedBox(width: AppTokens.spaceMd),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            tip.$1,
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            tip.$2,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(_tips.length, (idx) {
              return Container(
                width: _currentPage == idx ? 16 : 6,
                height: 4,
                margin: const EdgeInsets.symmetric(horizontal: 2),
                decoration: BoxDecoration(
                  color: _currentPage == idx
                      ? colorScheme.primary
                      : colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}
