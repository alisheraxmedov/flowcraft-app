import 'package:flowcraft/core/models/flow_graph.dart';

/// Manages undo and redo operations using graph snapshots.
///
/// Uses the Command Pattern by storing deep copies of the entire
/// [FlowGraph] state at each checkpoint.
class HistoryManager {
  /// Creates a [HistoryManager] with an optional [maxHistory] limit.
  HistoryManager({this.maxHistory = 50});

  /// Maximum number of snapshots to keep in the undo stack.
  final int maxHistory;

  final List<FlowGraph> _undoStack = [];
  final List<FlowGraph> _redoStack = [];

  /// Whether an undo operation is available.
  bool get canUndo => _undoStack.isNotEmpty;

  /// Whether a redo operation is available.
  bool get canRedo => _redoStack.isNotEmpty;

  /// The number of undo steps available.
  int get undoCount => _undoStack.length;

  /// The number of redo steps available.
  int get redoCount => _redoStack.length;

  /// Pushes a snapshot of the current graph state before a mutation.
  ///
  /// This should be called **before** applying the change to the graph.
  void pushSnapshot(FlowGraph graph) {
    _undoStack.add(graph.copyWith());
    // Clear the redo stack since a new action invalidates the future history.
    _redoStack.clear();

    // Enforce the maximum history limit.
    if (_undoStack.length > maxHistory) {
      _undoStack.removeAt(0);
    }
  }

  /// Reverts to the previous graph state.
  ///
  /// [currentGraph] is the state to push onto the redo stack before reverting.
  /// Returns the previous [FlowGraph] snapshot, or `null` if nothing to undo.
  FlowGraph? undo(FlowGraph currentGraph) {
    if (!canUndo) return null;
    _redoStack.add(currentGraph.copyWith());
    return _undoStack.removeLast();
  }

  /// Reapplies the most recently undone graph state.
  ///
  /// [currentGraph] is the state to push onto the undo stack before reapplying.
  /// Returns the redone [FlowGraph] snapshot, or `null` if nothing to redo.
  FlowGraph? redo(FlowGraph currentGraph) {
    if (!canRedo) return null;
    _undoStack.add(currentGraph.copyWith());
    return _redoStack.removeLast();
  }

  /// Clears all history.
  void clear() {
    _undoStack.clear();
    _redoStack.clear();
  }
}
