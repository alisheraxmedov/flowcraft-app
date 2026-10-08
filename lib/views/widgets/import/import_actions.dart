import 'package:flutter/material.dart';

import 'package:flowcraft/core/theme/app_spacing.dart';
import 'package:flowcraft/core/theme/app_typography.dart';
import 'package:flowcraft/viewmodels/scene_importer.dart';
import 'package:flowcraft/views/widgets/glass/fc_icons.dart';

/// The choice both import dialogs end on, plus their in-place error line.
///
/// Add and Replace are two buttons rather than a mode toggle followed by one
/// Import button: the difference between them is whether the board the user
/// is looking at survives, and burying that in a control they have to notice
/// is how someone loses a diagram to a mis-click.
class ImportActions extends StatelessWidget {
  const ImportActions({
    super.key,
    required this.onImport,
    this.enabled = true,
    this.busy = false,
    this.error,
  });

  final void Function(SceneImportMode mode) onImport;
  final bool enabled;
  final bool busy;

  /// Shown above the buttons, so a bad file can be swapped for another one
  /// without reopening the dialog.
  final String? error;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final message = error;
    final ready = enabled && !busy;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (message != null)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.toolbarGap),
            child: Row(
              children: [
                FcIconGlyph(
                  FcIcons.circleAlert,
                  size: 16,
                  color: colorScheme.error,
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    message,
                    style: AppTypography.bodySm.copyWith(
                      color: colorScheme.error,
                    ),
                  ),
                ),
              ],
            ),
          ),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton(
              onPressed: busy ? null : () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            const SizedBox(width: AppSpacing.toolbarGap),
            // Destructive, and coloured as such — it throws away whatever is
            // on the canvas (recoverably: the import is one undo entry).
            TextButton(
              onPressed: ready ? () => onImport(SceneImportMode.replace) : null,
              style: TextButton.styleFrom(foregroundColor: colorScheme.error),
              child: const Text('Replace canvas'),
            ),
            const SizedBox(width: AppSpacing.toolbarGap),
            FilledButton(
              onPressed: ready ? () => onImport(SceneImportMode.add) : null,
              child: Text(busy ? 'Importing…' : 'Add to canvas'),
            ),
          ],
        ),
      ],
    );
  }
}
