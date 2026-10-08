import 'package:flutter/material.dart';

import 'package:flowcraft/core/theme/app_radius.dart';
import 'package:flowcraft/core/theme/app_spacing.dart';
import 'package:flowcraft/core/theme/app_typography.dart';
import 'package:flowcraft/viewmodels/sketch_controller.dart';
import 'package:flowcraft/views/widgets/shortcuts/canvas_intents.dart';
import 'package:flowcraft/views/widgets/shortcuts/canvas_shortcut_table.dart';

/// Top-bar "Edit" menu — the mouse route to everything [CanvasShortcuts]
/// binds to a key.
///
/// A keyboard-only feature is an undiscoverable one: nobody guesses that
/// `⌘⇧]` exists. The items are generated from [CanvasShortcutTable] and
/// dispatched as the same [Intent]s the keystrokes raise, so the two paths
/// cannot implement anything twice — and `MenuItemButton.shortcut` prints
/// each item's real key beside it, which is how people learn them.
///
/// Must be mounted inside the `CanvasShortcuts` subtree, since that is what
/// provides the [Actions] these items invoke.
class EditMenuButton extends StatelessWidget {
  const EditMenuButton({super.key, required this.controller});

  final SketchController controller;

  @override
  Widget build(BuildContext context) {
    // Captured here rather than inside the menu builders: this context is
    // provably under `CanvasShortcuts`, while a menu child's lives in an
    // overlay.
    final host = context;
    final groups = CanvasShortcutTable.menuGroups(Theme.of(context).platform);

    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) => MenuAnchor(
        alignmentOffset: const Offset(0, AppSpacing.toolbarGap),
        menuChildren: [
          for (final (index, group) in groups.indexed) ...[
            if (index > 0) const Divider(height: 1),
            for (final shortcut in group.shortcuts)
              MenuItemButton(
                shortcut: shortcut.activator is MenuSerializableShortcut
                    ? shortcut.activator as MenuSerializableShortcut
                    : null,
                onPressed: _enabled(shortcut.intent)
                    ? () => Actions.maybeInvoke(host, shortcut.intent)
                    : null,
                child: Text(shortcut.label),
              ),
          ],
        ],
        builder: (context, menu, _) =>
            _EditPill(onTap: () => menu.isOpen ? menu.close() : menu.open()),
      ),
    );
  }

  /// Whether an item would do anything if tapped.
  ///
  /// The controller no-ops on every one of these without a selection, so
  /// this changes nothing functionally — it exists so the menu tells the
  /// truth about what is available instead of offering eight commands that
  /// silently do nothing.
  bool _enabled(Intent intent) {
    return switch (intent) {
      CopySelectionIntent() ||
      CutSelectionIntent() ||
      DuplicateSelectionIntent() ||
      DeleteSelectionIntent() ||
      ClearSelectionIntent() ||
      ReorderSelectionIntent() ||
      GroupSelectionIntent() ||
      UngroupSelectionIntent() => controller.hasSelection,
      UndoCanvasIntent() => controller.canUndo,
      RedoCanvasIntent() => controller.canRedo,
      SelectAllElementsIntent() ||
      FitToContentIntent() => controller.elements.isNotEmpty,
      AlignSelectionIntent() => controller.selectedIds.length >= 2,
      DistributeSelectionIntent() => controller.selectedIds.length >= 3,
      _ => true,
    };
  }
}

/// The anchor itself, matching the top bar's other text control (the
/// click-to-rename project name) rather than arriving as a stock
/// [TextButton] in the middle of a row of custom chrome.
class _EditPill extends StatelessWidget {
  const _EditPill({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: AppRadius.xsRadius,
      hoverColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.toolbarGap,
          vertical: 6,
        ),
        child: Text(
          'Edit',
          style: AppTypography.bodySm.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}
