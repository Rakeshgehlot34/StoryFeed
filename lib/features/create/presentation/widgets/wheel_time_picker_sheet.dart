import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../app/theme/app_tokens.dart';
import '../../../../core/utils/formatters.dart';

/// Modal bottom sheet providing a scrollable wheel time picker (hours/minutes/seconds/milliseconds)
/// and direct keyboard entry, with live preview seeking and range clamping.
class WheelTimePickerSheet extends StatefulWidget {
  final String title;
  final double initialSeconds;
  final double minSeconds;
  final double maxSeconds;
  final double totalDurationSeconds;
  final ValueChanged<double> onTimeChanged;
  final ValueChanged<double>? onPreviewSeek;

  const WheelTimePickerSheet({
    super.key,
    required this.title,
    required this.initialSeconds,
    required this.minSeconds,
    required this.maxSeconds,
    required this.totalDurationSeconds,
    required this.onTimeChanged,
    this.onPreviewSeek,
  });

  static Future<double?> show({
    required BuildContext context,
    required String title,
    required double initialSeconds,
    required double minSeconds,
    required double maxSeconds,
    required double totalDurationSeconds,
    ValueChanged<double>? onPreviewSeek,
  }) {
    return showModalBottomSheet<double>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => WheelTimePickerSheet(
        title: title,
        initialSeconds: initialSeconds,
        minSeconds: minSeconds,
        maxSeconds: maxSeconds,
        totalDurationSeconds: totalDurationSeconds,
        onTimeChanged: (_) {},
        onPreviewSeek: onPreviewSeek,
      ),
    );
  }

  @override
  State<WheelTimePickerSheet> createState() => _WheelTimePickerSheetState();
}

class _WheelTimePickerSheetState extends State<WheelTimePickerSheet> {
  late int _hours;
  late int _minutes;
  late int _seconds;
  late int _millis;
  bool _isManualKeyboardMode = false;
  final TextEditingController _keyboardController = TextEditingController();
  String? _manualError;

  late final FixedExtentScrollController _hourScroll;
  late final FixedExtentScrollController _minScroll;
  late final FixedExtentScrollController _secScroll;
  late final FixedExtentScrollController _milliScroll;

  bool get _hasHours => widget.totalDurationSeconds >= 3600.0;

  @override
  void initState() {
    super.initState();
    _splitTime(widget.initialSeconds);

    _hourScroll = FixedExtentScrollController(initialItem: _hours);
    _minScroll = FixedExtentScrollController(initialItem: _minutes);
    _secScroll = FixedExtentScrollController(initialItem: _seconds);
    _milliScroll = FixedExtentScrollController(initialItem: (_millis ~/ 10));

    _keyboardController.text = Formatters.formatPrecise(widget.initialSeconds);
  }

  void _splitTime(double totalSec) {
    var s = totalSec.floor();
    _millis = ((totalSec - s) * 1000).round().clamp(0, 999);
    _hours = s ~/ 3600;
    s %= 3600;
    _minutes = s ~/ 60;
    _seconds = s % 60;
  }

  double _assembleTime() {
    return (_hours * 3600.0) +
        (_minutes * 60.0) +
        _seconds +
        (_millis / 1000.0);
  }

  void _onWheelUpdated() {
    final raw = _assembleTime();
    final clamped = raw.clamp(widget.minSeconds, widget.maxSeconds);

    if (raw != clamped) {
      HapticFeedback.heavyImpact();
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            raw < widget.minSeconds
                ? 'Clamped to minimum allowed: ${Formatters.formatPrecise(widget.minSeconds)}'
                : 'Clamped to maximum allowed: ${Formatters.formatPrecise(widget.maxSeconds)}',
          ),
          duration: const Duration(seconds: 2),
        ),
      );
      _splitTime(clamped);
      _syncControllers();
    } else {
      HapticFeedback.selectionClick();
    }

    _keyboardController.text = Formatters.formatPrecise(clamped);
    widget.onPreviewSeek?.call(clamped);
  }

  void _syncControllers() {
    if (_hourScroll.hasClients && _hours != _hourScroll.selectedItem) {
      _hourScroll.jumpToItem(_hours);
    }
    if (_minScroll.hasClients && _minutes != _minScroll.selectedItem) {
      _minScroll.jumpToItem(_minutes);
    }
    if (_secScroll.hasClients && _seconds != _secScroll.selectedItem) {
      _secScroll.jumpToItem(_seconds);
    }
    if (_milliScroll.hasClients &&
        (_millis ~/ 10) != _milliScroll.selectedItem) {
      _milliScroll.jumpToItem(_millis ~/ 10);
    }
  }

  void _applyManualText(String text) {
    try {
      final parsed = Formatters.parsePrecise(text.trim());
      if (parsed == null) {
        setState(() => _manualError = 'Invalid format (use mm:ss.mmm)');
        return;
      }
      final clamped = parsed.clamp(widget.minSeconds, widget.maxSeconds);
      setState(() {
        _manualError = null;
        _splitTime(clamped);
      });
      _syncControllers();
      widget.onPreviewSeek?.call(clamped);
    } catch (_) {
      setState(() => _manualError = 'Invalid timestamp value');
    }
  }

  @override
  void dispose() {
    _hourScroll.dispose();
    _minScroll.dispose();
    _secScroll.dispose();
    _milliScroll.dispose();
    _keyboardController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final currentTime = _assembleTime().clamp(
      widget.minSeconds,
      widget.maxSeconds,
    );

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        left: 20,
        right: 20,
        top: 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                widget.title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              IconButton(
                tooltip: _isManualKeyboardMode
                    ? 'Switch to Wheel Picker'
                    : 'Switch to Keyboard Input',
                icon: Icon(
                  _isManualKeyboardMode
                      ? Icons.access_time_rounded
                      : Icons.keyboard_rounded,
                  color: colorScheme.primary,
                ),
                onPressed: () {
                  setState(
                    () => _isManualKeyboardMode = !_isManualKeyboardMode,
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Live Selected Display
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                Formatters.formatPrecise(currentTime),
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  fontFamily: 'monospace',
                  color: colorScheme.onPrimaryContainer,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Wheel Picker or Keyboard Input Area
          if (_isManualKeyboardMode) ...[
            TextFormField(
              controller: _keyboardController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              autofocus: true,
              decoration: InputDecoration(
                labelText: 'Timestamp (mm:ss.mmm)',
                hintText: '01:23.450',
                errorText: _manualError,
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.edit_calendar_rounded),
              ),
              onChanged: _applyManualText,
            ),
          ] else ...[
            SizedBox(
              height: 160,
              child: Row(
                children: [
                  if (_hasHours) ...[
                    Expanded(
                      child: _buildWheel(
                        label: 'Hours',
                        count: 24,
                        controller: _hourScroll,
                        onChanged: (val) {
                          _hours = val;
                          _onWheelUpdated();
                        },
                      ),
                    ),
                    const Text(
                      ':',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                  Expanded(
                    child: _buildWheel(
                      label: 'Min',
                      count: 60,
                      controller: _minScroll,
                      onChanged: (val) {
                        _minutes = val;
                        _onWheelUpdated();
                      },
                    ),
                  ),
                  const Text(
                    ':',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  Expanded(
                    child: _buildWheel(
                      label: 'Sec',
                      count: 60,
                      controller: _secScroll,
                      onChanged: (val) {
                        _seconds = val;
                        _onWheelUpdated();
                      },
                    ),
                  ),
                  const Text(
                    '.',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  Expanded(
                    child: _buildWheel(
                      label: 'ms',
                      count: 100, // steps of 10ms (0 to 990ms)
                      multiplier: 10,
                      controller: _milliScroll,
                      onChanged: (val) {
                        _millis = val * 10;
                        _onWheelUpdated();
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 20),

          // Action Buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(
                      AppTokens.minTouchTarget,
                    ),
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(
                      AppTokens.minTouchTarget,
                    ),
                  ),
                  onPressed: () {
                    final finalSec = _assembleTime().clamp(
                      widget.minSeconds,
                      widget.maxSeconds,
                    );
                    Navigator.of(context).pop(finalSec);
                  },
                  child: const Text('Apply'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWheel({
    required String label,
    required int count,
    required FixedExtentScrollController controller,
    required ValueChanged<int> onChanged,
    int multiplier = 1,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      children: [
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Expanded(
          child: ListWheelScrollView.useDelegate(
            controller: controller,
            itemExtent: 36,
            perspective: 0.003,
            diameterRatio: 1.2,
            physics: const FixedExtentScrollPhysics(),
            onSelectedItemChanged: onChanged,
            childDelegate: ListWheelChildBuilderDelegate(
              childCount: count,
              builder: (context, index) {
                final val = index * multiplier;
                final text = multiplier == 10
                    ? val.toString().padLeft(3, '0')
                    : val.toString().padLeft(2, '0');
                return Center(
                  child: Text(
                    text,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      fontFamily: 'monospace',
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}
