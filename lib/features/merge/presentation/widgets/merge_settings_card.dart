import 'package:flutter/material.dart';

import '../../../../app/theme/app_tokens.dart';
import '../../../../shared/widgets/section_card.dart';
import '../../domain/models/merge_project.dart';
import '../controllers/merge_controller.dart';

/// Configuration panels for canvas normalization, transitions, and encoding method.
class MergeSettingsCard extends StatelessWidget {
  final MergeState state;
  final MergeController controller;

  const MergeSettingsCard({
    super.key,
    required this.state,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final config = state.config;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionCard(
          title: 'Canvas & Aspect Ratio',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Adapt disparate video ratios into a unified canvas',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppTokens.spaceSm),
              Text(
                'Target Ratio Preset',
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: AppTokens.spaceXs),
              Wrap(
                spacing: AppTokens.spaceXs,
                runSpacing: AppTokens.spaceXs,
                children: CanvasAspectRatioPreset.values.map((preset) {
                  final isSelected = config.canvasPreset == preset;
                  return ChoiceChip(
                    label: Text(preset.label),
                    selected: isSelected,
                    onSelected: (selected) {
                      if (selected) controller.setCanvasPreset(preset);
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: AppTokens.spaceMd),
              Text(
                'Fit Mode (Letterbox / Background)',
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: AppTokens.spaceXs),
              Wrap(
                spacing: AppTokens.spaceXs,
                runSpacing: AppTokens.spaceXs,
                children: CanvasFitMode.values.map((mode) {
                  final isSelected = config.fitMode == mode;
                  return ChoiceChip(
                    label: Text(mode.label),
                    selected: isSelected,
                    onSelected: (selected) {
                      if (selected) controller.setFitMode(mode);
                    },
                  );
                }).toList(),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppTokens.spaceMd),
        SectionCard(
          title: 'Transitions',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Visual dissolve or wipe transitions between clips',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppTokens.spaceSm),
              Wrap(
                spacing: AppTokens.spaceXs,
                runSpacing: AppTokens.spaceXs,
                children: MergeTransition.values.map((trans) {
                  final isSelected = config.transition == trans;
                  return ChoiceChip(
                    label: Text(trans.label),
                    selected: isSelected,
                    onSelected: (selected) {
                      if (selected) controller.setTransition(trans);
                    },
                  );
                }).toList(),
              ),
              if (!config.transition.isNone) ...[
                const SizedBox(height: AppTokens.spaceMd),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Transition Duration',
                      style: theme.textTheme.labelMedium,
                    ),
                    Text(
                      '${config.transitionDurationSeconds.toStringAsFixed(2)}s',
                      style: theme.textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: colorScheme.primary,
                      ),
                    ),
                  ],
                ),
                Slider(
                  value: config.transitionDurationSeconds,
                  min: 0.2,
                  max: 2.0,
                  divisions: 18,
                  label:
                      '${config.transitionDurationSeconds.toStringAsFixed(1)}s',
                  onChanged: (val) => controller.setTransitionDuration(val),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: AppTokens.spaceMd),
        SectionCard(
          title: 'Output & Encoding Method',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Choose between stream copy and re-encoding',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppTokens.spaceSm),
              Wrap(
                spacing: AppTokens.spaceXs,
                runSpacing: AppTokens.spaceXs,
                children: MergeMethod.values.map((method) {
                  final isSelected = config.method == method;
                  return ChoiceChip(
                    label: Text(method.label),
                    selected: isSelected,
                    onSelected: (selected) {
                      if (selected) controller.setMethod(method);
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: AppTokens.spaceMd),
              TextFormField(
                initialValue: config.customBaseName ?? '',
                decoration: const InputDecoration(
                  labelText: 'Output Video Name (optional)',
                  hintText: 'e.g., vacation_vlog_final',
                  prefixIcon: Icon(Icons.drive_file_rename_outline_rounded),
                ),
                onChanged: (val) => controller.setCustomBaseName(val),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
