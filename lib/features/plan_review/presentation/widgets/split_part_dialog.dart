import 'dart:math';

import 'package:flutter/material.dart';

import '../../../../app/constants.dart';
import '../../../../core/utils/formatters.dart';
import '../../../split_config/domain/models/clip_plan.dart';

/// Dialog to split an existing part into two separate clips.
class SplitPartDialog extends StatefulWidget {
  final ClipPlanItem part;
  final ValueChanged<double> onSplit;

  const SplitPartDialog({super.key, required this.part, required this.onSplit});

  @override
  State<SplitPartDialog> createState() => _SplitPartDialogState();
}

class _SplitPartDialogState extends State<SplitPartDialog> {
  late double _splitTime;
  late final double _minSplit;
  late final double _maxSplit;
  late final TextEditingController _textController;

  @override
  void initState() {
    super.initState();
    _minSplit = widget.part.startSeconds + AppConstants.minClipDurationSeconds;
    _maxSplit = widget.part.endSeconds - AppConstants.minClipDurationSeconds;
    _splitTime = (widget.part.startSeconds + widget.part.endSeconds) / 2.0;

    _textController = TextEditingController(
      text: Formatters.formatPrecise(_splitTime),
    );
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  void _onSliderChanged(double val) {
    setState(() {
      _splitTime = val;
      _textController.text = Formatters.formatPrecise(val);
    });
  }

  void _onTextSubmitted(String val) {
    final parsed = Formatters.parsePrecise(val);
    if (parsed != null && parsed >= _minSplit && parsed <= _maxSplit) {
      setState(() {
        _splitTime = parsed;
      });
    } else {
      _textController.text = Formatters.formatPrecise(_splitTime);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final leftDur = _splitTime - widget.part.startSeconds;
    final rightDur = widget.part.endSeconds - _splitTime;

    return AlertDialog(
      title: Text('Split Part ${widget.part.index} into Two'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Select the timestamp where you want to split this clip.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildDurBadge('First Half', leftDur, colorScheme.primary),
                const Icon(Icons.call_split_rounded, size: 18),
                _buildDurBadge('Second Half', rightDur, colorScheme.secondary),
              ],
            ),
            const SizedBox(height: 16),
            if (_maxSplit > _minSplit)
              Slider(
                value: _splitTime.clamp(_minSplit, _maxSplit),
                min: _minSplit,
                max: _maxSplit,
                divisions: max(1, ((_maxSplit - _minSplit) * 2).round()),
                onChanged: _onSliderChanged,
              )
            else
              Text(
                'Clip duration is too short to split into two 1-second clips.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.error,
                ),
              ),
            const SizedBox(height: 8),
            TextField(
              controller: _textController,
              decoration: const InputDecoration(
                labelText: 'Split Timestamp (mm:ss.mmm)',
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
          onPressed: _maxSplit > _minSplit
              ? () {
                  widget.onSplit(_splitTime);
                  Navigator.of(context).pop();
                }
              : null,
          child: const Text('Split Part'),
        ),
      ],
    );
  }

  Widget _buildDurBadge(String title, double dur, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontSize: 12)),
        Text(
          '${dur.toStringAsFixed(1)}s',
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
      ],
    );
  }
}
