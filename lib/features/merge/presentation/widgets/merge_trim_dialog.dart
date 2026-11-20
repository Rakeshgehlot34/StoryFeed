import 'package:flutter/material.dart';

import '../../../../app/theme/app_tokens.dart';
import '../../../../shared/widgets/primary_button.dart';
import '../../../../shared/widgets/secondary_button.dart';
import '../../domain/models/merge_project.dart';

/// Modal dialog for inspecting and adjusting trim boundaries of a merge clip item.
class MergeTrimDialog extends StatefulWidget {
  final MergeClipItem clip;
  final void Function(double start, double? end) onSave;

  const MergeTrimDialog({super.key, required this.clip, required this.onSave});

  @override
  State<MergeTrimDialog> createState() => _MergeTrimDialogState();
}

class _MergeTrimDialogState extends State<MergeTrimDialog> {
  late double _start;
  late double _end;

  @override
  void initState() {
    super.initState();
    _start = widget.clip.startTrimSeconds;
    _end = widget.clip.endTrimSeconds ?? widget.clip.durationSeconds;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final maxDur =
        widget.clip.durationSeconds > 0.1 ? widget.clip.durationSeconds : 1.0;

    return AlertDialog(
      title: Text('Trim: ${widget.clip.fileName}'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Range: ${_start.toStringAsFixed(2)}s - ${_end.toStringAsFixed(2)}s (Duration: ${(_end - _start).toStringAsFixed(2)}s)',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppTokens.spaceMd),
            Text(
              'Start Cut (${_start.toStringAsFixed(2)}s)',
              style: theme.textTheme.labelMedium,
            ),
            Slider(
              value: _start.clamp(0.0, _end - 0.1),
              min: 0.0,
              max: maxDur,
              onChanged: (val) {
                setState(() {
                  _start = val;
                  if (_start >= _end) {
                    _start = _end - 0.1;
                  }
                });
              },
            ),
            const SizedBox(height: AppTokens.spaceSm),
            Text(
              'End Cut (${_end.toStringAsFixed(2)}s)',
              style: theme.textTheme.labelMedium,
            ),
            Slider(
              value: _end.clamp(_start + 0.1, maxDur),
              min: 0.0,
              max: maxDur,
              onChanged: (val) {
                setState(() {
                  _end = val;
                  if (_end <= _start) {
                    _end = _start + 0.1;
                  }
                });
              },
            ),
            const SizedBox(height: AppTokens.spaceSm),
            SecondaryButton(
              label: 'Reset to Full Video',
              icon: Icons.refresh_rounded,
              onPressed: () {
                setState(() {
                  _start = 0.0;
                  _end = widget.clip.durationSeconds;
                });
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        PrimaryButton(
          label: 'Apply',
          onPressed: () {
            widget.onSave(_start, _end >= maxDur ? null : _end);
            Navigator.of(context).pop();
          },
        ),
      ],
    );
  }
}
