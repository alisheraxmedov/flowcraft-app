import 'package:flutter/foundation.dart';

/// Tracks selected node and edge IDs.
///
/// Notifies listeners on selection changes for UI updates.
class SelectionManager extends ChangeNotifier {
  final Set<String> _nodeIds = {};
  final Set<String> _edgeIds = {};

  Set<String> get selectedNodeIds => Set.unmodifiable(_nodeIds);
  Set<String> get selectedEdgeIds => Set.unmodifiable(_edgeIds);
  bool get hasSelection => _nodeIds.isNotEmpty || _edgeIds.isNotEmpty;

  bool isNodeSelected(String id) => _nodeIds.contains(id);
  bool isEdgeSelected(String id) => _edgeIds.contains(id);

  void selectNode(String nodeId, {bool clearExisting = true}) {
    if (clearExisting) {
      _nodeIds.clear();
      _edgeIds.clear();
    }
    _nodeIds.add(nodeId);
    notifyListeners();
  }

  void selectEdge(String edgeId) {
    _nodeIds.clear();
    _edgeIds
      ..clear()
      ..add(edgeId);
    notifyListeners();
  }

  void toggleNodeSelection(String nodeId) {
    _nodeIds.contains(nodeId)
        ? _nodeIds.remove(nodeId)
        : _nodeIds.add(nodeId);
    notifyListeners();
  }

  void toggleEdgeSelection(String edgeId) {
    _edgeIds.contains(edgeId)
        ? _edgeIds.remove(edgeId)
        : _edgeIds.add(edgeId);
    notifyListeners();
  }

  void selectNodes(Set<String> nodeIds, {bool addToSelection = false}) {
    if (!addToSelection) {
      _nodeIds.clear();
      _edgeIds.clear();
    }
    _nodeIds.addAll(nodeIds);
    notifyListeners();
  }

  void selectAll(Set<String> nodeIds, Set<String> edgeIds) {
    _nodeIds
      ..clear()
      ..addAll(nodeIds);
    _edgeIds
      ..clear()
      ..addAll(edgeIds);
    notifyListeners();
  }

  void clearSelection() {
    if (!hasSelection) return;
    _nodeIds.clear();
    _edgeIds.clear();
    notifyListeners();
  }

  void deselectNode(String nodeId) {
    if (_nodeIds.remove(nodeId)) notifyListeners();
  }

  void deselectEdge(String edgeId) {
    if (_edgeIds.remove(edgeId)) notifyListeners();
  }
}
