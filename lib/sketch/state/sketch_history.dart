import 'package:flowcraft/sketch/models/sketch_element.dart';

/// Immutable snapshot of the sketch scene used for undo/redo.
class SketchSnapshot {
  const SketchSnapshot({
    required this.elements,
    required this.selectedIds,
  });

  final List<SketchElement> elements;
  final Set<String> selectedIds;
}

/// Fixed-size LIFO history stack for the sketch scene.
///
/// Snapshots are pushed before each mutation; [undo] returns the
/// previous snapshot, [redo] re-applies a popped one.
class SketchHistory {
  SketchHistory({this.maxHistory = 50});

  final int maxHistory;
  final List<SketchSnapshot> _undoStack = [];
  final List<SketchSnapshot> _redoStack = [];

  bool get canUndo => _undoStack.isNotEmpty;
  bool get canRedo => _redoStack.isNotEmpty;

  void push(SketchSnapshot snapshot) {
    _undoStack.add(snapshot);
    if (_undoStack.length > maxHistory) {
      _undoStack.removeAt(0);
    }
    _redoStack.clear();
  }

  /// Pops the most recent snapshot. The caller is expected to push the
  /// current state onto the redo stack via [pushRedo] before applying it.
  SketchSnapshot? popUndo(SketchSnapshot current) {
    if (_undoStack.isEmpty) return null;
    _redoStack.add(current);
    return _undoStack.removeLast();
  }

  SketchSnapshot? popRedo(SketchSnapshot current) {
    if (_redoStack.isEmpty) return null;
    _undoStack.add(current);
    return _redoStack.removeLast();
  }

  void clear() {
    _undoStack.clear();
    _redoStack.clear();
  }
}
