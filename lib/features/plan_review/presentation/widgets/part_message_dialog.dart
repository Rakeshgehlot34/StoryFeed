import 'package:flutter/material.dart';

import '../../../split_config/domain/models/clip_plan.dart';
import '../../../split_config/domain/models/overlay_spec.dart';

/// Dialog allowing the user to override text overlay message and visibility for a specific part.
class PartMessageDialog extends StatefulWidget {
  final ClipPlanItem item;
  final void Function(String? customMessage, PartLabelOverride override) onSave;

  const PartMessageDialog({
    super.key,
    required this.item,
    required this.onSave,
  });

  @override
  State<PartMessageDialog> createState() => _PartMessageDialogState();
}

class _PartMessageDialogState extends State<PartMessageDialog> {
  late final TextEditingController _controller;
  late PartLabelOverride _override;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.item.customMessage ?? '');
    _override = widget.item.partLabelOverride;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _insertToken(String token) {
    final text = _controller.text;
    final selection = _controller.selection;
    if (selection.isValid && selection.start >= 0) {
      final newText = text.replaceRange(selection.start, selection.end, token);
      _controller.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(
          offset: selection.start + token.length,
        ),
      );
    } else {
      _controller.text = '$text$token';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return AlertDialog(
      title: Text('Part ${widget.item.index} Overlay Label'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Label Visibility for this part:',
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            SegmentedButton<PartLabelOverride>(
              segments: const [
                ButtonSegment(
                  value: PartLabelOverride.useProjectDefault,
                  label: Text('Default'),
                  tooltip: 'Inherit project setting',
                ),
                ButtonSegment(
                  value: PartLabelOverride.show,
                  label: Text('Show'),
                  tooltip: 'Always show label on this part',
                ),
                ButtonSegment(
                  value: PartLabelOverride.hide,
                  label: Text('Hide'),
                  tooltip: 'Never show label on this part',
                ),
              ],
              selected: {_override},
              onSelectionChanged: (set) {
                if (set.isNotEmpty) {
                  setState(() => _override = set.first);
                }
              },
            ),
            const SizedBox(height: 16),
            Text(
              'Custom Message (optional):',
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Overrides auto label. Leave blank to use auto template ({n}/{total}).',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _controller,
              enabled: _override != PartLabelOverride.hide,
              decoration: InputDecoration(
                labelText: 'Part Message',
                hintText: 'e.g. Part {n}/{total}',
                border: const OutlineInputBorder(),
                suffixIcon: _controller.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          setState(() {
                            _controller.clear();
                          });
                        },
                      )
                    : null,
              ),
              onChanged: (_) => setState(() {}),
            ),
            if (_override != PartLabelOverride.hide) ...[
              const SizedBox(height: 12),
              Text('Quick Tokens:', style: theme.textTheme.labelSmall),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                children: [
                  ActionChip(
                    label: const Text('{n}'),
                    onPressed: () => _insertToken('{n}'),
                  ),
                  ActionChip(
                    label: const Text('{total}'),
                    onPressed: () => _insertToken('{total}'),
                  ),
                  ActionChip(
                    label: const Text('{name}'),
                    onPressed: () => _insertToken('{name}'),
                  ),
                ],
              ),
            ],
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
            final text = _controller.text.trim();
            widget.onSave(text.isEmpty ? null : text, _override);
            Navigator.of(context).pop();
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}
