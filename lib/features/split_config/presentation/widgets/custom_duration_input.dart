import 'package:flutter/material.dart';

import '../../../../app/constants.dart';

class CustomDurationInput extends StatefulWidget {
  final int currentDurationSeconds;
  final ValueChanged<int> onChanged;

  const CustomDurationInput({
    super.key,
    required this.currentDurationSeconds,
    required this.onChanged,
  });

  @override
  State<CustomDurationInput> createState() => _CustomDurationInputState();
}

class _CustomDurationInputState extends State<CustomDurationInput> {
  late TextEditingController _controller;
  String? _clampMessage;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: widget.currentDurationSeconds.toString(),
    );
  }

  @override
  void didUpdateWidget(covariant CustomDurationInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentDurationSeconds != widget.currentDurationSeconds) {
      if (_controller.text != widget.currentDurationSeconds.toString()) {
        _controller.text = widget.currentDurationSeconds.toString();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleInput(String value) {
    final val = int.tryParse(value);
    if (val == null) return;

    if (val > AppConstants.maxClipDurationSeconds) {
      setState(() {
        _clampMessage = 'Clamped to 180s (3:00) — YouTube Shorts hard limit.';
      });
      widget.onChanged(AppConstants.maxClipDurationSeconds);
      _controller.text = AppConstants.maxClipDurationSeconds.toString();
    } else if (val < AppConstants.minClipDurationSeconds) {
      setState(() {
        _clampMessage = 'Clamped to 1s minimum.';
      });
      widget.onChanged(AppConstants.minClipDurationSeconds);
      _controller.text = AppConstants.minClipDurationSeconds.toString();
    } else {
      setState(() {
        _clampMessage = null;
      });
      widget.onChanged(val);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Custom Clip Duration (Max 3:00)',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                SizedBox(
                  width: 80,
                  child: TextField(
                    controller: _controller,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    decoration: InputDecoration(
                      isDense: true,
                      suffixText: 's',
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 8,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onSubmitted: _handleInput,
                  ),
                ),
              ],
            ),
            if (_clampMessage != null) ...[
              const SizedBox(height: 6),
              Text(
                _clampMessage!,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: colorScheme.error,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
            const SizedBox(height: 8),
            Slider(
              value: widget.currentDurationSeconds.toDouble().clamp(
                AppConstants.minClipDurationSeconds.toDouble(),
                AppConstants.maxClipDurationSeconds.toDouble(),
              ),
              min: AppConstants.minClipDurationSeconds.toDouble(),
              max: AppConstants.maxClipDurationSeconds.toDouble(),
              divisions: 179,
              label: '${widget.currentDurationSeconds}s',
              onChanged: (value) {
                setState(() => _clampMessage = null);
                widget.onChanged(value.round());
              },
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '1 second',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: colorScheme.outline,
                  ),
                ),
                Text(
                  'Max 180s (3:00)',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: colorScheme.outline,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
