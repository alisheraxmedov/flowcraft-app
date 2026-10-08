import 'package:flutter/material.dart';

import 'package:flowcraft/core/theme/fc_tokens.dart';
import 'package:flowcraft/core/theme/app_spacing.dart';
import 'package:flowcraft/core/theme/app_typography.dart';
import 'package:flowcraft/views/widgets/fc_dialog.dart';
import 'package:flowcraft/views/widgets/shortcuts/canvas_shortcut_table.dart';
import 'package:flowcraft/views/widgets/shortcuts/shortcut_label.dart';

/// The `?` reference sheet.
///
/// Rendered from [CanvasShortcutTable] rather than a hand-written list, so
/// it cannot drift from the bindings that are actually live — a stale
/// shortcut sheet is worse than no sheet, because people believe it.
class ShortcutsHelpDialog extends StatelessWidget {
  const ShortcutsHelpDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog<void>(
      context: context,
      builder: (_) => const ShortcutsHelpDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final platform = Theme.of(context).platform;

    return FcDialog(
      title: 'Keyboard shortcuts',
      content: SizedBox(
        width: 560,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final group in CanvasShortcutTable.groups(platform))
                _Group(
                  title: group.title,
                  rows: ShortcutLabel.merge(group.shortcuts, platform),
                ),
              // Modifier behaviour and the editor's own keys — display
              // only, same rows, so the sheet reads as one list.
              for (final group in CanvasShortcutTable.modifierGroups(platform))
                _Group(
                  title: group.title,
                  rows: [
                    for (final hint in group.hints)
                      (label: hint.label, keys: hint.keys),
                  ],
                ),
            ],
          ),
        ),
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }
}

class _Group extends StatelessWidget {
  const _Group({required this.title, required this.rows});

  final String title;
  final List<({String label, String keys})> rows;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.panelPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title.toUpperCase(),
            style: AppTypography.caption.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.toolbarGap),
          for (final row in rows) _Row(label: row.label, keys: row.keys),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.keys});

  final String label;
  final String keys;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: AppTypography.bodySm.copyWith(
                color: colorScheme.onSurface,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: context.fc.surface2,
              borderRadius: BorderRadius.circular(5),
            ),
            child: Text(
              keys,
              style: AppTypography.labelMono.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
