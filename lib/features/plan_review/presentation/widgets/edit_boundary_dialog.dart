import 'dart:math';

import 'package:flutter/material.dart';

import '../../../../app/constants.dart';
import '../../../../core/utils/formatters.dart';
import '../../../split_config/domain/models/clip_plan.dart';

/// Dialog to adjust the boundary between part N and part N+1.
class EditBoundaryDialog extends StatefulWidget {
  final ClipPlanItem leftPart;
  final ClipPlanItem rightPart;
  final ValueChanged<double> onSave;

  const EditBoundaryDialog({
    super.key,
    required this.leftPart,
    required this.rightPart,
    required this.onSave,
  });

  @override
  State<EditBoundaryDialog> createState() => _EditBoundaryDialogState();
}

class _EditBoundaryDialogState extends State<EditBoundaryDialog> {
  late double _currentBoundary;
  late final double _minBoundary;
  late final double _maxBoundary;
  late final TextEditingController _textController;

  @override
  void initState() {
    super.initState();
    _currentBoundary = widget.leftPart.endSeconds;

    // Boundary constraints: both parts must remain between 1s and 180s
    _minBoundary = max(
      widget.leftPart.startSeconds + AppConstants.minClipDurationSeconds,
      widget.rightPart.endSeconds - AppConstants.maxClipDurationSeconds,
    );
    _maxBoundary = min(
      widget.leftPart.startSeconds + AppConstants.maxClipDurationSeconds,
      widget.rightPart.endSeconds - AppConstants.minClipDurationSeconds,
    );

    _textController = TextEditingController(
      text: Formatters.formatPrecise(_currentBoundary),
    );
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  void _onSliderChanged(double val) {
    setState(() {
      _currentBoundary = val;
      _textController.text = Formatters.formatPrecise(val);
    });
  }

  void _onTextSubmitted(String val) {
    final parsed = Formatters.parsePrecise(val);
    if (parsed != null && parsed >= _minBoundary && parsed <= _maxBoundary) {
      setState(() {
        _currentBoundary = parsed;
      });
    } else {
      _textController.text = Formatters.formatPrecise(_currentBoundary);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final leftDur = _currentBoundary - widget.leftPart.startSeconds;
    final rightDur = widget.rightPart.endSeconds - _currentBoundary;

    return AlertDialog(
      title: Text(
        'Adjust Boundary (Part ${widget.leftPart.index} & ${widget.rightPart.index})',
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Move the cut point between both parts. Contiguity is automatically preserved.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildDurBadge(
                  context,
                  'Part ${widget.leftPart.index}',
                  leftDur,
                ),
                const Icon(Icons.arrow_forward_rounded, size: 16),
                _buildDurBadge(
                  context,
                  'Part ${widget.rightPart.index}',
                  rightDur,
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_maxBoundary > _minBoundary)
              Slider(
                value: _currentBoundary.clamp(_minBoundary, _maxBoundary),
                min: _minBoundary,
                max: _maxBoundary,
                divisions: max(1, ((_maxBoundary - _minBoundary) * 2).round()),
                onChanged: _onSliderChanged,
              )
            else
              Text(
                'Boundary is at minimum/maximum limits.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.error,
                ),
              ),
            const SizedBox(height: 8),
            TextField(
              controller: _textController,
              decoration: const InputDecoration(
                labelText: 'Boundary Time (mm:ss.mmm)',
                border: OutlineInputBorder(),
              ),
              onSubmitted: _onTextSubmitted,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            widget.onSave(_currentBoundary);
            Navigator.of(context).pop();
          },
          child: const Text('Apply'),
        ),
      ],
    );
  }

  Widget _buildDurBadge(BuildContext context, String title, double dur) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: theme.textTheme.labelSmall),
        Text(
          '${dur.toStringAsFixed(1)}s',
          style: theme.textTheme.titleSmall?.copyWith(
            color: colorScheme.primary,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
