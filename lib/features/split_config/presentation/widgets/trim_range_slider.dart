import 'package:flutter/material.dart';

import '../../../../app/constants.dart';
import '../../../../core/utils/formatters.dart';
import '../../domain/models/trim_range.dart';

/// Range slider and precise time fields for video timeline trimming.
class TrimRangeSlider extends StatefulWidget {
  final double totalDurationSeconds;
  final TrimRange? currentRange;
  final ValueChanged<TrimRange> onChanged;

  const TrimRangeSlider({
    super.key,
    required this.totalDurationSeconds,
    required this.currentRange,
    required this.onChanged,
  });

  @override
  State<TrimRangeSlider> createState() => _TrimRangeSliderState();
}

class _TrimRangeSliderState extends State<TrimRangeSlider> {
  late double _start;
  late double _end;
  late final TextEditingController _startController;
  late final TextEditingController _endController;
  late final FocusNode _startFocus;
  late final FocusNode _endFocus;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _start = widget.currentRange?.startSeconds ?? 0.0;
    _end = widget.currentRange?.endSeconds ?? widget.totalDurationSeconds;
    _startController = TextEditingController(
      text: Formatters.formatPrecise(_start),
    );
    _endController = TextEditingController(
      text: Formatters.formatPrecise(_end),
    );
    _startFocus = FocusNode()..addListener(_onFocusChange);
    _endFocus = FocusNode()..addListener(_onFocusChange);
  }

  void _onFocusChange() {
    if (!_startFocus.hasFocus && !_endFocus.hasFocus) {
      _onTimeFieldSubmitted();
    }
  }

  @override
  void didUpdateWidget(covariant TrimRangeSlider oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.currentRange != null &&
        widget.currentRange != oldWidget.currentRange &&
        !_startFocus.hasFocus &&
        !_endFocus.hasFocus) {
      _start = widget.currentRange!.startSeconds;
      _end = widget.currentRange!.endSeconds;
      _startController.text = Formatters.formatPrecise(_start);
      _endController.text = Formatters.formatPrecise(_end);
    }
  }

  @override
  void dispose() {
    _startFocus.removeListener(_onFocusChange);
    _endFocus.removeListener(_onFocusChange);
    _startFocus.dispose();
    _endFocus.dispose();
    _startController.dispose();
    _endController.dispose();
    super.dispose();
  }

  void _onRangeChanged(RangeValues values) {
    if (values.end - values.start < AppConstants.minClipDurationSeconds) return;

    setState(() {
      _start = values.start;
      _end = values.end;
      _startController.text = Formatters.formatPrecise(_start);
      _endController.text = Formatters.formatPrecise(_end);
      _errorMessage = null;
    });

    widget.onChanged(TrimRange(startSeconds: _start, endSeconds: _end));
  }

  void _onTimeFieldSubmitted() {
    final parsedStart = Formatters.parsePrecise(_startController.text);
    final parsedEnd = Formatters.parsePrecise(_endController.text);

    if (parsedStart == null || parsedEnd == null) {
      setState(
        () => _errorMessage = 'Invalid timestamp format (use mm:ss.mmm).',
      );
      return;
    }

    if (parsedStart < 0 || parsedEnd > widget.totalDurationSeconds) {
      setState(
        () => _errorMessage = 'Timestamps must stay within video duration.',
      );
      return;
    }

    if (parsedEnd - parsedStart < AppConstants.minClipDurationSeconds) {
      setState(
        () => _errorMessage = 'Trim duration must be at least 1.0 second.',
      );
      return;
    }

    setState(() {
      _start = parsedStart;
      _end = parsedEnd;
      _errorMessage = null;
    });

    widget.onChanged(TrimRange(startSeconds: _start, endSeconds: _end));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final maxSec =
        widget.totalDurationSeconds > 0 ? widget.totalDurationSeconds : 1.0;

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
            _buildHeader(theme, colorScheme),
            const SizedBox(height: 12),
            RangeSlider(
              values: RangeValues(
                _start.clamp(0.0, maxSec),
                _end.clamp(0.0, maxSec),
              ),
              min: 0.0,
              max: maxSec,
              onChanged: _onRangeChanged,
            ),
            const SizedBox(height: 8),
            _buildHandleBadges(theme, colorScheme),
            const SizedBox(height: 12),
            _buildPreciseTimeFields(theme),
            if (_errorMessage != null) ...[
              const SizedBox(height: 8),
              Text(
                _errorMessage!,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: colorScheme.error,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeData theme, ColorScheme colorScheme) {
    final dur = (_end - _start).clamp(0.0, widget.totalDurationSeconds);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Selected Trim Range',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              '${Formatters.formatPrecise(_start)} - ${Formatters.formatPrecise(_end)} (${dur.toStringAsFixed(1)}s)',
              style: theme.textTheme.labelSmall?.copyWith(
                color: colorScheme.primary,
                fontWeight: FontWeight.w600,
                fontFamily: 'monospace',
              ),
            ),
          ],
        ),
        TextButton(
          onPressed: () {
            _onRangeChanged(RangeValues(0.0, widget.totalDurationSeconds));
          },
          child: const Text('Reset Full'),
        ),
      ],
    );
  }

  Widget _buildHandleBadges(ThemeData theme, ColorScheme colorScheme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            'Start: ${Formatters.formatSeconds(_start)}',
            style: theme.textTheme.labelSmall?.copyWith(
              color: colorScheme.onPrimaryContainer,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: colorScheme.secondaryContainer,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            'End: ${Formatters.formatSeconds(_end)}',
            style: theme.textTheme.labelSmall?.copyWith(
              color: colorScheme.onSecondaryContainer,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPreciseTimeFields(ThemeData theme) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _startController,
            focusNode: _startFocus,
            decoration: const InputDecoration(
              labelText: 'Start (mm:ss.mmm)',
              isDense: true,
              border: OutlineInputBorder(),
            ),
            onTapOutside: (_) => _onTimeFieldSubmitted(),
            onEditingComplete: _onTimeFieldSubmitted,
            onSubmitted: (_) => _onTimeFieldSubmitted(),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: TextField(
            controller: _endController,
            focusNode: _endFocus,
            decoration: const InputDecoration(
              labelText: 'End (mm:ss.mmm)',
              isDense: true,
              border: OutlineInputBorder(),
            ),
            onTapOutside: (_) => _onTimeFieldSubmitted(),
            onEditingComplete: _onTimeFieldSubmitted,
            onSubmitted: (_) => _onTimeFieldSubmitted(),
          ),
        ),
        const SizedBox(width: 8),
        IconButton.filledTonal(
          icon: const Icon(Icons.check_rounded, size: 20),
          tooltip: 'Apply Timestamps',
          onPressed: _onTimeFieldSubmitted,
        ),
      ],
    );
  }
}
