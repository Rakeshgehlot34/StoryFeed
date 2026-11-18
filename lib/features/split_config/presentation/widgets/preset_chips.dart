import 'package:flutter/material.dart';

import '../../../../app/constants.dart';

class PresetChips extends StatelessWidget {
  final int selectedDurationSeconds;
  final ValueChanged<int> onSelected;

  const PresetChips({
    super.key,
    required this.selectedDurationSeconds,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final isCustom = !AppConstants.clipDurationPresets.contains(
      selectedDurationSeconds,
    );

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        ...AppConstants.clipDurationPresets.map((preset) {
          final isSelected = !isCustom && selectedDurationSeconds == preset;
          final label = preset >= 60 && preset % 60 == 0
              ? '${preset ~/ 60} min'
              : '${preset}s';

          return ChoiceChip(
            label: Text(label),
            selected: isSelected,
            onSelected: (selected) {
              if (selected) onSelected(preset);
            },
          );
        }),
        ChoiceChip(
          label: Text(
            isCustom ? 'Custom (${selectedDurationSeconds}s)' : 'Custom...',
          ),
          selected: isCustom,
          onSelected: (selected) {
            if (selected) {
              onSelected(selectedDurationSeconds);
            }
          },
        ),
      ],
    );
  }
}
