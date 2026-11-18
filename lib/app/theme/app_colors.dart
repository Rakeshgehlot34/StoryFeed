import 'package:flutter/material.dart';

/// Available accent colors that the user can choose in Settings.
enum AppAccentColor {
  red(Color(0xFFFF0033), 'YouTube Red'),
  violet(Color(0xFF7C4DFF), 'Electric Violet'),
  ocean(Color(0xFF0288D1), 'Deep Ocean'),
  emerald(Color(0xFF00897B), 'Emerald Green'),
  orange(Color(0xFFFF6F00), 'Sunset Orange');

  final Color seedColor;
  final String label;

  const AppAccentColor(this.seedColor, this.label);
}
