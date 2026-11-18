import 'package:flutter/material.dart';

import '../../app/theme/app_tokens.dart';

/// Reusable color picker field with standard palette chips and custom hex dialog.
class ColorPickerField extends StatelessWidget {
  final int selectedColorValue;
  final ValueChanged<int> onColorChanged;

  static const List<int> defaultPalette = [
    0xFFFFFFFF, // Pure White
    0xFF000000, // Black
    0xFF212121, // Charcoal
    0xFFFF0033, // YouTube Red
    0xFF7C4DFF, // Electric Violet
    0xFF0288D1, // Deep Ocean
    0xFF00897B, // Teal
    0xFFFF6F00, // Sunset Orange
  ];

  const ColorPickerField({
    super.key,
    required this.selectedColorValue,
    required this.onColorChanged,
  });

  String get _hexCode {
    final hex = selectedColorValue
        .toRadixString(16)
        .padLeft(8, '0')
        .toUpperCase();
    return '#${hex.substring(2)}';
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          ...defaultPalette.map((colorVal) {
            final isSelected = selectedColorValue == colorVal;
            return Padding(
              padding: const EdgeInsets.only(right: AppTokens.spaceSm),
              child: InkWell(
                onTap: () => onColorChanged(colorVal),
                borderRadius: AppTokens.borderRadiusFull,
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
            icon: const Icon(Icons.colorize_rounded, size: AppTokens.iconSm),
            label: Text(_hexCode),
            onPressed: () => _showHexDialog(context),
          ),
        ],
      ),
    );
  }

  void _showHexDialog(BuildContext context) {
    final controller = TextEditingController(text: _hexCode);
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Enter Hex Color (#RRGGBB)'),
        content: TextField(
          controller: controller,
          autofocus: true,
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
              final raw = controller.text.replaceAll('#', '').trim();
              final parsed = int.tryParse('FF$raw', radix: 16);
              if (parsed != null) {
                onColorChanged(parsed);
              }
              Navigator.of(ctx).pop();
            },
            child: const Text('Apply'),
          ),
        ],
      ),
    );
  }
}
