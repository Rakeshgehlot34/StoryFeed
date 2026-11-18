import 'package:flutter/material.dart';

import '../../../split_config/domain/models/clip_plan.dart';

/// Dialog allowing the user to override text overlay message for a specific part.
class PartMessageDialog extends StatefulWidget {
  final ClipPlanItem item;
  final ValueChanged<String?> onSave;

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

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.item.customMessage ?? '');
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
      title: Text('Part ${widget.item.index} Overlay Message'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Enter a custom overlay message for this part. Leave blank to inherit default auto label.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _controller,
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
            widget.onSave(text.isEmpty ? null : text);
            Navigator.of(context).pop();
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}
