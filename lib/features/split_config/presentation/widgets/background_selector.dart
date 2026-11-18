import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../domain/models/background_spec.dart';

/// Selector for canvas background fill: Solid Color, Custom Image, or Blurred Video.
class BackgroundSelector extends StatelessWidget {
  final BackgroundSpec selectedBackground;
  final ValueChanged<BackgroundSpec> onBackgroundChanged;

  const BackgroundSelector({
    super.key,
    required this.selectedBackground,
    required this.onBackgroundChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      elevation: 0,
      color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('Solid Color'),
                  selected: selectedBackground is SolidColorBackgroundSpec,
                  onSelected: (selected) {
                    if (selected) {
                      onBackgroundChanged(const SolidColorBackgroundSpec());
                    }
                  },
                ),
                ChoiceChip(
                  label: const Text('Blurred Video'),
                  selected: selectedBackground is BlurBackgroundSpec,
                  onSelected: (selected) {
                    if (selected) {
                      onBackgroundChanged(const BlurBackgroundSpec());
                    }
                  },
                ),
                ChoiceChip(
                  label: const Text('Custom Image'),
                  selected: selectedBackground is ImageBackgroundSpec,
                  onSelected: (selected) {
                    if (selected) {
                      _pickCustomImage(context);
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (selectedBackground is SolidColorBackgroundSpec)
              _buildColorOptions(
                context,
                selectedBackground as SolidColorBackgroundSpec,
              ),
            if (selectedBackground is ImageBackgroundSpec)
              _buildImageOptions(
                context,
                selectedBackground as ImageBackgroundSpec,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildColorOptions(
    BuildContext context,
    SolidColorBackgroundSpec spec,
  ) {
    const palette = [
      0xFFFFFFFF, // White (default)
      0xFF000000, // Black
      0xFF212121, // Dark Grey
      0xFFE91E63, // Pink
      0xFF3F51B5, // Indigo
      0xFF009688, // Teal
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            ...palette.map((colorVal) {
              final isSelected = spec.colorValue == colorVal;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: InkWell(
                  onTap: () => onBackgroundChanged(
                    SolidColorBackgroundSpec(colorValue: colorVal),
                  ),
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: Color(colorVal),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected ? Colors.blue : Colors.grey.shade400,
                        width: isSelected ? 3 : 1,
                      ),
                    ),
                  ),
                ),
              );
            }),
            TextButton.icon(
              icon: const Icon(Icons.colorize_rounded, size: 16),
              label: Text(spec.hexCode),
              onPressed: () => _showHexColorDialog(context, spec),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildImageOptions(BuildContext context, ImageBackgroundSpec spec) {
    final theme = Theme.of(context);
    return Row(
      children: [
        const Icon(Icons.image_outlined, size: 20),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            spec.imagePath.split('/').last,
            style: theme.textTheme.bodySmall,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        TextButton(
          onPressed: () => _pickCustomImage(context),
          child: const Text('Change Image'),
        ),
      ],
    );
  }

  Future<void> _pickCustomImage(BuildContext context) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      onBackgroundChanged(ImageBackgroundSpec(imagePath: picked.path));
    }
  }

  void _showHexColorDialog(
    BuildContext context,
    SolidColorBackgroundSpec spec,
  ) {
    final controller = TextEditingController(text: spec.hexCode);
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Enter Hex Color (#RRGGBB)'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: '#FFFFFF',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final text = controller.text.replaceAll('#', '').trim();
              final parsed = int.tryParse('FF$text', radix: 16);
              if (parsed != null) {
                onBackgroundChanged(
                  SolidColorBackgroundSpec(colorValue: parsed),
                );
              }
              Navigator.of(ctx).pop();
            },
            child: const Text('Select'),
          ),
        ],
      ),
    );
  }
}
