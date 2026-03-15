import 'package:flutter/foundation.dart';

/// Manages the selection state of nodes and edges.
///
/// Tracks which node/edge IDs are currently selected and
/// notifies listeners on changes.
class SelectionManager extends ChangeNotifier {
  final Set<String> _selectedNodeIds = {};
  final Set<String> _selectedEdgeIds = {};

  /// The set of currently selected node IDs.
  Set<String> get selectedNodeIds => Set.unmodifiable(_selectedNodeIds);

  /// The set of currently selected edge IDs.
  Set<String> get selectedEdgeIds => Set.unmodifiable(_selectedEdgeIds);

  /// Whether any nodes or edges are selected.
  bool get hasSelection =>
      _selectedNodeIds.isNotEmpty || _selectedEdgeIds.isNotEmpty;

  /// Whether the given [nodeId] is currently selected.
  bool isNodeSelected(String nodeId) => _selectedNodeIds.contains(nodeId);

  /// Whether the given [edgeId] is currently selected.
  bool isEdgeSelected(String edgeId) => _selectedEdgeIds.contains(edgeId);

  /// Selects a single node, clearing any previous selection.
  void selectNode(String nodeId) {
    _selectedNodeIds.clear();
    _selectedEdgeIds.clear();
    _selectedNodeIds.add(nodeId);
    notifyListeners();
  }

  /// Selects a single edge, clearing any previous selection.
  void selectEdge(String edgeId) {
    _selectedNodeIds.clear();
    _selectedEdgeIds.clear();
    _selectedEdgeIds.add(edgeId);
    notifyListeners();
  }

  /// Toggles the selection state of a node (for multi-select).
  void toggleNodeSelection(String nodeId) {
    if (_selectedNodeIds.contains(nodeId)) {
      _selectedNodeIds.remove(nodeId);
    } else {
      _selectedNodeIds.add(nodeId);
    }
    notifyListeners();
  }

  /// Toggles the selection state of an edge.
  void toggleEdgeSelection(String edgeId) {
    if (_selectedEdgeIds.contains(edgeId)) {
      _selectedEdgeIds.remove(edgeId);
    } else {
      _selectedEdgeIds.add(edgeId);
    }
    notifyListeners();
  }

  /// Selects multiple nodes, optionally adding to existing selection.
  void selectNodes(Set<String> nodeIds, {bool addToSelection = false}) {
    if (!addToSelection) {
      _selectedNodeIds.clear();
      _selectedEdgeIds.clear();
    }
    _selectedNodeIds.addAll(nodeIds);
    notifyListeners();
  }

  /// Selects all given node and edge IDs.
  void selectAll(Set<String> nodeIds, Set<String> edgeIds) {
    _selectedNodeIds
      ..clear()
      ..addAll(nodeIds);
    _selectedEdgeIds
      ..clear()
      ..addAll(edgeIds);
    notifyListeners();
  }

  /// Clears all selection.
  void clearSelection() {
    if (!hasSelection) return;
    _selectedNodeIds.clear();
    _selectedEdgeIds.clear();
    notifyListeners();
  }

  /// Removes a node from selection (e.g., when a node is deleted).
  void deselectNode(String nodeId) {
    if (_selectedNodeIds.remove(nodeId)) {
      notifyListeners();
    }
  }

  /// Removes an edge from selection.
  void deselectEdge(String edgeId) {
    if (_selectedEdgeIds.remove(edgeId)) {
      notifyListeners();
    }
  }
}
