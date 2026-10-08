import 'package:flutter/material.dart';

import 'package:flowcraft/core/theme/app_radius.dart';
import 'package:flowcraft/core/theme/app_typography.dart';
import 'package:flowcraft/core/theme/fc_tokens.dart';
import 'package:flowcraft/viewmodels/sketch_controller.dart';
import 'package:flowcraft/views/widgets/fc_menu.dart';
import 'package:flowcraft/views/widgets/glass/fc_icons.dart';
import 'package:flowcraft/views/widgets/shortcuts/canvas_intents.dart';
import 'package:flowcraft/views/widgets/shortcuts/canvas_shortcut_table.dart';
import 'package:flowcraft/views/widgets/shortcuts/shortcut_label.dart';

/// Top-right "Edit" menu -- the mouse route to everything [CanvasShortcuts]
/// binds to a key.
///
/// A keyboard-only feature is an undiscoverable one: nobody guesses that
/// `⌘⇧]` exists. The items are generated from [CanvasShortcutTable] and
/// dispatched as the same [Intent]s the keystrokes raise, so the two paths
/// cannot implement anything twice -- and each row prints its real key, which
/// is how people learn them. Undo/Redo are not here (the bottom island has
/// them); a trailing CANVAS group holds the destructive "Clear canvas".
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
    final platform = Theme.of(context).platform;
    final groups = CanvasShortcutTable.menuGroups(platform);

    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) => MenuAnchor(
        style: fcMenuStyle(context),
        alignmentOffset: const Offset(0, 6),
        menuChildren: [
          for (final (index, group) in groups.indexed) ...[
            // Canvas sits just before Help, as in the mockup.
            if (group.title == 'Help') ...[
              const FcMenuHeader('Canvas'),
              FcMenuItem(
                label: 'Clear canvas',
                danger: true,
                onPressed: controller.elements.isEmpty
                    ? null
                    : () => _clearWithUndo(host),
              ),
              const FcMenuDivider(),
            ] else if (index > 0)
              const FcMenuDivider(),
            FcMenuHeader(group.title),
            for (final shortcut in group.shortcuts)
              FcMenuItem(
                label: shortcut.label,
                hint: ShortcutLabel.of(shortcut.activator, platform),
                onPressed: _enabled(shortcut.intent)
                    ? () => Actions.maybeInvoke(host, shortcut.intent)
                    : null,
              ),
          ],
        ],
        builder: (context, menu, _) =>
            _EditPill(onTap: () => menu.isOpen ? menu.close() : menu.open()),
      ),
    );
  }

  /// Wipes the board and says so, with the way back one tap away. A single
  /// click that empties everything, silently, reads as a destructive
  /// accident; a confirm dialog would be the heavier cure. The edit was
  /// always undoable -- this just tells the user.
  void _clearWithUndo(BuildContext context) {
    final count = controller.elements.length;
    controller.clear();
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;
    messenger
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text(
            'Cleared $count ${count == 1 ? 'element' : 'elements'}',
          ),
          action: SnackBarAction(label: 'Undo', onPressed: controller.undo),
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

/// The anchor: h32, radius 10, "Edit" 13/500 + a muted 14px chevron, surface2
/// on hover. Plain hover container rather than an `InkWell`: this sits on a
/// glass island, and ink paints on the Material *under* the glass.
class _EditPill extends StatefulWidget {
  const _EditPill({required this.onTap});

  final VoidCallback onTap;

  @override
  State<_EditPill> createState() => _EditPillState();
}

class _EditPillState extends State<_EditPill> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final t = context.fc;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: Container(
          height: 32,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: _hover ? t.surface2 : null,
            borderRadius: BorderRadius.circular(AppRadius.button),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Edit',
                style: AppTypography.bodySm.copyWith(
                  fontWeight: FontWeight.w500,
                  height: 1,
                  color: t.text,
                ),
              ),
              const SizedBox(width: 4),
              FcIconGlyph(FcIcons.chevronDown, size: 14, color: t.muted),
            ],
          ),
        ),
      ),
    );
  }
}
