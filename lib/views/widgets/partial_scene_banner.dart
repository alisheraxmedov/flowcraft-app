import 'package:flutter/material.dart';

import 'package:flowcraft/core/theme/app_radius.dart';
import 'package:flowcraft/core/theme/app_spacing.dart';
import 'package:flowcraft/core/theme/app_typography.dart';
import 'package:flowcraft/viewmodels/sketch_controller.dart';

/// Warns that the open project loaded incompletely, and that autosave is
/// therefore switched off.
///
/// This is the visible half of a data-loss guard. When a project file holds
/// elements this build can't decode, they are skipped so the rest of the
/// scene still opens — but the canvas is then *smaller* than its own file,
/// and the ~800ms autosave would write that reduced scene straight back over
/// the original within a second of opening it. `ProjectAutosave` refuses to
/// write while `SketchController.sceneIsPartial`; without this banner the
/// user would just see their edits silently failing to persist.
///
/// Renders nothing on a clean load, so it is safe to leave in the tree.
class PartialSceneBanner extends StatelessWidget {
  const PartialSceneBanner({super.key, required this.controller});

  final SketchController controller;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        if (!controller.sceneIsPartial) return const SizedBox.shrink();
        return _Banner(
          dropped: controller.droppedOnLoad,
          onAccept: controller.acknowledgePartialScene,
        );
      },
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.dropped, required this.onAccept});

  final int dropped;
  final VoidCallback onAccept;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final plural = dropped == 1 ? 'element' : 'elements';

    return Material(
      color: colorScheme.errorContainer,
      borderRadius: AppRadius.mdRadius,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.panelPadding,
          AppSpacing.toolbarGap,
          AppSpacing.toolbarGap,
          AppSpacing.toolbarGap,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.warning_amber_rounded,
              size: 20,
              color: colorScheme.onErrorContainer,
            ),
            const SizedBox(width: AppSpacing.toolbarGap),
            Flexible(
              child: Text(
                '$dropped $plural could not be read. Your changes are not '
                'being saved, so the original file stays intact.',
                style: AppTypography.bodySm.copyWith(
                  color: colorScheme.onErrorContainer,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.toolbarGap),
            // The only way out, and deliberately not a dismiss: hiding the
            // warning while autosave stays off would leave the user drawing
            // into a canvas nothing persists. Accepting the loss is what
            // re-arms the writes.
            TextButton(
              onPressed: onAccept,
              style: TextButton.styleFrom(
                foregroundColor: colorScheme.onErrorContainer,
              ),
              child: const Text('Save anyway'),
            ),
          ],
        ),
      ),
    );
  }
}
