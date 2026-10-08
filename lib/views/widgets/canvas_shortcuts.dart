import 'package:flutter/material.dart';

import 'package:flowcraft/services/canvas_exporter.dart';
import 'package:flowcraft/viewmodels/sketch_controller.dart';
import 'package:flowcraft/views/widgets/shortcuts/canvas_clipboard.dart';
import 'package:flowcraft/views/widgets/shortcuts/canvas_intents.dart';
import 'package:flowcraft/views/widgets/shortcuts/canvas_shortcut_manager.dart';
import 'package:flowcraft/views/widgets/shortcuts/canvas_shortcut_table.dart';
import 'package:flowcraft/views/widgets/shortcuts/nudge_session.dart';
import 'package:flowcraft/views/widgets/shortcuts_help_dialog.dart';

/// The whiteboard's single keyboard layer: wrap the screen in it once.
///
/// It replaces the per-widget key handler `WhiteboardCanvas` used to own.
/// That handler hung off the canvas's own [FocusNode], so touching a toolbar
/// popover or a properties field moved focus out of it and every shortcut
/// went dead until the user clicked back on the canvas — a failure with no
/// visible cause. Living above the whole screen, this layer keeps working
/// wherever focus is, and [CanvasShortcutManager] is what keeps it from
/// firing while that focus is in a text field.
///
/// The bindings themselves are not written here; they come from
/// [CanvasShortcutTable], which the `?` reference sheet reads too.
class CanvasShortcuts extends StatefulWidget {
  const CanvasShortcuts({
    super.key,
    required this.controller,
    required this.child,
  });

  final SketchController controller;
  final Widget child;

  @override
  State<CanvasShortcuts> createState() => _CanvasShortcutsState();
}

class _CanvasShortcutsState extends State<CanvasShortcuts> {
  /// Built once and mutated in place: it is a [ChangeNotifier], so minting a
  /// fresh one per build would leak a listener registration each time.
  final CanvasShortcutManager _manager = CanvasShortcutManager();

  /// The one piece of state pinned to a specific controller — every action
  /// below reads `widget.controller` live, so only this needs re-making
  /// when the controller is swapped.
  late NudgeSession _nudge = NudgeSession(widget.controller);

  late final Map<Type, Action<Intent>> _actions = _buildActions();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // `Theme.of(...).platform`, not `defaultTargetPlatform`: it is what the
    // rest of the app's Material chrome obeys, so the modifier the user sees
    // in the reference sheet is the one that actually works.
    _manager.shortcuts = CanvasShortcutTable.bindings(
      Theme.of(context).platform,
    );
  }

  @override
  void didUpdateWidget(CanvasShortcuts old) {
    super.didUpdateWidget(old);
    if (old.controller != widget.controller) {
      _nudge.dispose();
      _nudge = NudgeSession(widget.controller);
    }
  }

  @override
  void dispose() {
    _nudge.dispose();
    _manager.dispose();
    super.dispose();
  }

  SketchController get _ctrl => widget.controller;

  ScaffoldMessengerState get _messenger => ScaffoldMessenger.of(context);

  /// Every action is a one-liner delegating to [SketchController]; the
  /// canvas verbs live there, and duplicating any of their rules here is
  /// how a keyboard path and a menu path start disagreeing.
  Map<Type, Action<Intent>> _buildActions() {
    return <Type, Action<Intent>>{
      SelectToolIntent: _run<SelectToolIntent>(
        (i) => _ctrl.currentTool = i.tool,
      ),
      CopySelectionIntent: _run<CopySelectionIntent>(
        (_) => CanvasClipboard.copy(_ctrl, _messenger),
      ),
      CutSelectionIntent: _run<CutSelectionIntent>(
        (_) => CanvasClipboard.cut(_ctrl, _messenger),
      ),
      PasteSceneIntent: _run<PasteSceneIntent>(
        (_) => CanvasClipboard.paste(_ctrl, _messenger),
      ),
      DuplicateSelectionIntent: _run<DuplicateSelectionIntent>(
        (_) => _ctrl.duplicateSelected(),
      ),
      SelectAllElementsIntent: _run<SelectAllElementsIntent>(
        (_) => _ctrl.selectMany([for (final el in _ctrl.elements) el.id]),
      ),
      DeleteSelectionIntent: _run<DeleteSelectionIntent>(
        (_) => _ctrl.removeSelected(),
      ),
      // Cancel before clearing: an edit the editor no longer holds focus
      // for (Tab moved it away) would otherwise stay open with nothing left
      // that can close it, which is what the intent's doc promises against.
      ClearSelectionIntent: _run<ClearSelectionIntent>(
        (_) => _ctrl
          ..cancelTextEdit()
          ..clearSelection(),
      ),
      UndoCanvasIntent: _run<UndoCanvasIntent>((_) => _ctrl.undo()),
      RedoCanvasIntent: _run<RedoCanvasIntent>((_) => _ctrl.redo()),
      ReorderSelectionIntent: _run<ReorderSelectionIntent>(
        (i) => _reorder(i.shift),
      ),
      GroupSelectionIntent: _run<GroupSelectionIntent>(
        (_) => _ctrl.groupSelected(),
      ),
      UngroupSelectionIntent: _run<UngroupSelectionIntent>(
        (_) => _ctrl.ungroupSelected(),
      ),
      NudgeSelectionIntent: _run<NudgeSelectionIntent>(
        (i) => _nudge.nudge(i.delta),
      ),
      FitToContentIntent: _run<FitToContentIntent>((_) {
        if (_ctrl.elements.isEmpty) return;
        _ctrl.requestFrame(CanvasExporter.contentBounds(_ctrl.elements));
      }),
      AlignSelectionIntent: _run<AlignSelectionIntent>(
        (i) => _ctrl.alignSelected(i.edge),
      ),
      DistributeSelectionIntent: _run<DistributeSelectionIntent>(
        (i) => _ctrl.distributeSelected(i.axis),
      ),
      ShowShortcutsIntent: _run<ShowShortcutsIntent>(
        (_) => ShortcutsHelpDialog.show(context),
      ),
    };
  }

  /// Wraps a void callback as an [Action]. `CallbackAction.onInvoke` is
  /// typed `Object? Function(T)`, which a `void`-returning expression body
  /// can't satisfy — this keeps that ceremony in one place instead of at
  /// fifteen call sites.
  CallbackAction<T> _run<T extends Intent>(void Function(T intent) body) {
    return CallbackAction<T>(
      onInvoke: (intent) {
        body(intent);
        return null;
      },
    );
  }

  void _reorder(ZOrderShift shift) {
    switch (shift) {
      case ZOrderShift.forward:
        _ctrl.bringForward();
      case ZOrderShift.backward:
        _ctrl.sendBackward();
      case ZOrderShift.front:
        _ctrl.bringToFront();
      case ZOrderShift.back:
        _ctrl.sendToBack();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Shortcuts.manager(
      manager: _manager,
      child: Actions(
        actions: _actions,
        // The layer's own scope, so that `FocusNode.unfocus()` — which every
        // text field calls on Enter/Escape, and the inline editor on commit —
        // parks focus *here* rather than on the route's scope above this
        // widget. Key events start at the primary focus and walk up; landing
        // above `Shortcuts` left every canvas key dead after any edit until
        // the canvas was clicked again.
        child: FocusScope(child: widget.child),
      ),
    );
  }
}
