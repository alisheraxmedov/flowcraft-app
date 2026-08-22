import 'package:flutter/widgets.dart';

import 'package:flowcraft/models/sketch_tool.dart';

/// The vocabulary of things a keystroke (or a menu item) can ask the canvas
/// to do.
///
/// Deliberately its own set rather than Flutter's `SelectAllIntent` /
/// `CopySelectionTextIntent`: those belong to text editing, and reusing them
/// would put canvas actions and the text field's own actions in the same
/// namespace — where whichever `Actions` widget sits closer to the focused
/// node silently wins. Distinct types make that collision impossible.

/// Switches the active drawing tool.
class SelectToolIntent extends Intent {
  const SelectToolIntent(this.tool);

  final SketchTool tool;
}

/// Puts the selection on the system clipboard as a scene payload.
class CopySelectionIntent extends Intent {
  const CopySelectionIntent();
}

/// Copy, then remove.
class CutSelectionIntent extends Intent {
  const CutSelectionIntent();
}

/// Adds whatever scene payload the system clipboard holds.
class PasteSceneIntent extends Intent {
  const PasteSceneIntent();
}

class DuplicateSelectionIntent extends Intent {
  const DuplicateSelectionIntent();
}

class SelectAllElementsIntent extends Intent {
  const SelectAllElementsIntent();
}

class DeleteSelectionIntent extends Intent {
  const DeleteSelectionIntent();
}

/// Escape: drop the selection, abandoning any in-flight text edit with it.
class ClearSelectionIntent extends Intent {
  const ClearSelectionIntent();
}

class UndoCanvasIntent extends Intent {
  const UndoCanvasIntent();
}

class RedoCanvasIntent extends Intent {
  const RedoCanvasIntent();
}

/// Which way a z-order command moves the selection.
enum ZOrderShift { forward, backward, front, back }

class ReorderSelectionIntent extends Intent {
  const ReorderSelectionIntent(this.shift);

  final ZOrderShift shift;
}

class GroupSelectionIntent extends Intent {
  const GroupSelectionIntent();
}

class UngroupSelectionIntent extends Intent {
  const UngroupSelectionIntent();
}

/// Moves the selection by [delta] canvas pixels.
class NudgeSelectionIntent extends Intent {
  const NudgeSelectionIntent(this.delta);

  final Offset delta;
}

/// Opens the shortcut reference.
class ShowShortcutsIntent extends Intent {
  const ShowShortcutsIntent();
}
