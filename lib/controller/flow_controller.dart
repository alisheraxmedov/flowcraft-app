import 'dart:ui';

import 'package:flutter/foundation.dart';

import 'package:flowcraft/core/enums/node_type.dart';
import 'package:flowcraft/core/models/edge_style.dart';
import 'package:flowcraft/core/models/flow_edge.dart';
import 'package:flowcraft/core/models/flow_graph.dart';
import 'package:flowcraft/core/models/flow_handle.dart';
import 'package:flowcraft/core/models/flow_node.dart';
import 'package:flowcraft/core/models/flow_viewport.dart';
import 'package:flowcraft/core/utils/graph_utils.dart';
import 'package:flowcraft/core/utils/math_utils.dart';
import 'package:flowcraft/core/utils/serializer.dart';
import 'package:flowcraft/controller/history_manager.dart';
import 'package:flowcraft/controller/selection_manager.dart';

/// The central state manager for FlowCraft.
///
/// [FlowController] holds the entire graph state (nodes, edges, viewport)
/// and exposes a clean public API for all operations. It extends
/// [ChangeNotifier] to allow reactive rebuilds.
///
/// ```dart
/// final controller = FlowController();
/// controller.addNode(position: Offset(100, 200));
/// controller.addEdge(sourceId, targetId);
/// ```
class FlowController extends ChangeNotifier {
  /// Creates a [FlowController].
  FlowController({
    FlowGraph? graph,
    FlowViewport? viewport,
    int maxHistory = 50,
  })  : _graph = graph ?? FlowGraph(),
        _viewport = viewport ?? const FlowViewport(),
        _history = HistoryManager(maxHistory: maxHistory),
        selection = SelectionManager();

  FlowGraph _graph;
  FlowViewport _viewport;
  final HistoryManager _history;

  /// The selection manager for tracking selected nodes/edges.
  final SelectionManager selection;

  // ---------------------------------------------------------------------------
  // Getters
  // ---------------------------------------------------------------------------

  /// The current graph state.
  FlowGraph get graph => _graph;

  /// All nodes in the graph (unmodifiable view).
  List<FlowNode> get nodes => List.unmodifiable(_graph.nodes);

  /// All edges in the graph (unmodifiable view).
  List<FlowEdge> get edges => List.unmodifiable(_graph.edges);

  /// The current viewport state.
  FlowViewport get viewport => _viewport;

  /// Whether undo is available.
  bool get canUndo => _history.canUndo;

  /// Whether redo is available.
  bool get canRedo => _history.canRedo;

  // ---------------------------------------------------------------------------
  // Node Operations
  // ---------------------------------------------------------------------------

  /// Adds a new node to the graph.
  ///
  /// Returns the created [FlowNode].
  FlowNode addNode({
    NodeType type = NodeType.defaultNode,
    String label = 'Node',
    Offset position = Offset.zero,
    Size size = const Size(180, 60),
    Map<String, dynamic>? data,
    List<FlowHandle>? handles,
  }) {
    _pushHistory();
    final node = FlowNode(
      type: type,
      label: label,
      position: position,
      size: size,
      data: data,
      handles: handles,
    );
    _graph.nodes.add(node);
    notifyListeners();
    return node;
  }

  /// Removes a node and all connected edges from the graph.
  void removeNode(String nodeId) {
    _pushHistory();
    GraphUtils.removeEdgesForNode(_graph, nodeId);
    _graph.nodes.removeWhere((n) => n.id == nodeId);
    selection.deselectNode(nodeId);
    notifyListeners();
  }

  /// Moves a node to a new position.
  void moveNode(String nodeId, Offset newPosition) {
    final node = _graph.nodeById(nodeId);
    if (node == null) return;
    node.position = newPosition;
    notifyListeners();
  }

  /// Moves a node by a delta offset (for drag operations).
  void moveNodeBy(String nodeId, Offset delta) {
    final node = _graph.nodeById(nodeId);
    if (node == null) return;
    node.position = Offset(
      node.position.dx + delta.dx,
      node.position.dy + delta.dy,
    );
    notifyListeners();
  }

  /// Saves a snapshot before starting a drag (for undo).
  void startNodeDrag(String nodeId) {
    _pushHistory();
  }

  /// Renames a node.
  void renameNode(String nodeId, String newLabel) {
    _pushHistory();
    final node = _graph.nodeById(nodeId);
    if (node == null) return;
    node.label = newLabel;
    notifyListeners();
  }

  /// Sets the type of a node.
  void setNodeType(String nodeId, NodeType newType) {
    _pushHistory();
    final node = _graph.nodeById(nodeId);
    if (node == null) return;
    node.type = newType;
    notifyListeners();
  }

  /// Resizes a node.
  void resizeNode(String nodeId, Size newSize) {
    _pushHistory();
    final node = _graph.nodeById(nodeId);
    if (node == null) return;
    node.size = newSize;
    notifyListeners();
  }

  /// Adds or updates a data field on a node.
  void addNodeField(String nodeId, {required String key, dynamic value}) {
    _pushHistory();
    final node = _graph.nodeById(nodeId);
    if (node == null) return;
    node.data[key] = value;
    notifyListeners();
  }

  /// Removes a data field from a node.
  void removeNodeField(String nodeId, String key) {
    _pushHistory();
    final node = _graph.nodeById(nodeId);
    if (node == null) return;
    node.data.remove(key);
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Edge Operations
  // ---------------------------------------------------------------------------

  /// Adds a new edge between two handles.
  ///
  /// Returns the created [FlowEdge], or `null` if validation fails.
  FlowEdge? addEdge({
    required String sourceNodeId,
    required String targetNodeId,
    required String sourceHandleId,
    required String targetHandleId,
    EdgeStyle? style,
  }) {
    final error = GraphUtils.validateEdge(
      _graph,
      sourceNodeId: sourceNodeId,
      targetNodeId: targetNodeId,
      sourceHandleId: sourceHandleId,
      targetHandleId: targetHandleId,
    );
    if (error != null) return null;

    _pushHistory();
    final edge = FlowEdge(
      sourceNodeId: sourceNodeId,
      targetNodeId: targetNodeId,
      sourceHandleId: sourceHandleId,
      targetHandleId: targetHandleId,
      style: style,
    );
    _graph.edges.add(edge);
    notifyListeners();
    return edge;
  }

  /// Removes an edge by its ID.
  void removeEdge(String edgeId) {
    _pushHistory();
    _graph.edges.removeWhere((e) => e.id == edgeId);
    selection.deselectEdge(edgeId);
    notifyListeners();
  }

  /// Updates the style of an edge.
  void updateEdgeStyle(String edgeId, EdgeStyle newStyle) {
    _pushHistory();
    final edge = _graph.edgeById(edgeId);
    if (edge == null) return;
    edge.style = newStyle;
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Viewport Operations
  // ---------------------------------------------------------------------------

  /// Sets the viewport pan offset.
  void pan(Offset newOffset) {
    _viewport = _viewport.copyWith(offset: newOffset);
    notifyListeners();
  }

  /// Adds a delta to the current pan offset.
  void panBy(Offset delta) {
    _viewport = _viewport.copyWith(
      offset: Offset(
        _viewport.offset.dx + delta.dx,
        _viewport.offset.dy + delta.dy,
      ),
    );
    notifyListeners();
  }

  /// Sets the zoom level.
  void setZoom(double zoom) {
    _viewport = _viewport.copyWith(zoom: zoom);
    notifyListeners();
  }

  /// Sets both pan offset and zoom level in a single update.
  ///
  /// Use this instead of calling [pan] + [setZoom] separately to avoid
  /// triggering two rebuilds.
  void setViewport({Offset? offset, double? zoom}) {
    _viewport = _viewport.copyWith(offset: offset, zoom: zoom);
    notifyListeners();
  }

  /// Zooms in by a factor.
  void zoomIn({double factor = 0.1}) {
    setZoom(_viewport.zoom + factor);
  }

  /// Zooms out by a factor.
  void zoomOut({double factor = 0.1}) {
    setZoom(_viewport.zoom - factor);
  }

  /// Fits the viewport to show all nodes.
  void fitView(Size canvasSize) {
    if (_graph.nodes.isEmpty) return;

    final allPositions =
        _graph.nodes.map((n) => n.position).toList();
    final allBottomRights = _graph.nodes
        .map((n) => Offset(
              n.position.dx + n.size.width,
              n.position.dy + n.size.height,
            ))
        .toList();

    final bounds = MathUtils.boundingRect(
      [...allPositions, ...allBottomRights],
      padding: 50,
    );

    final scaleX = canvasSize.width / bounds.width;
    final scaleY = canvasSize.height / bounds.height;
    final zoom = MathUtils.clampDouble(
      scaleX < scaleY ? scaleX : scaleY,
      _viewport.minZoom,
      _viewport.maxZoom,
    );

    _viewport = _viewport.copyWith(
      zoom: zoom,
      offset: Offset(-bounds.left * zoom, -bounds.top * zoom),
    );
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Selection
  // ---------------------------------------------------------------------------

  /// Selects all nodes and edges.
  void selectAll() {
    selection.selectAll(
      _graph.nodes.map((n) => n.id).toSet(),
      _graph.edges.map((e) => e.id).toSet(),
    );
  }

  /// Removes all currently selected nodes and edges.
  void deleteSelection() {
    _pushHistory();
    // Copy the sets to avoid concurrent modification
    final edgeIds = Set<String>.of(selection.selectedEdgeIds);
    final nodeIds = Set<String>.of(selection.selectedNodeIds);
    for (final edgeId in edgeIds) {
      _graph.edges.removeWhere((e) => e.id == edgeId);
    }
    for (final nodeId in nodeIds) {
      GraphUtils.removeEdgesForNode(_graph, nodeId);
      _graph.nodes.removeWhere((n) => n.id == nodeId);
    }
    selection.clearSelection();
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // History
  // ---------------------------------------------------------------------------

  /// Undoes the last action.
  void undo() {
    final previous = _history.undo(_graph);
    if (previous != null) {
      _graph = previous;
      notifyListeners();
    }
  }

  /// Redoes the last undone action.
  void redo() {
    final next = _history.redo(_graph);
    if (next != null) {
      _graph = next;
      notifyListeners();
    }
  }

  void _pushHistory() {
    _history.pushSnapshot(_graph);
  }

  // ---------------------------------------------------------------------------
  // Serialization
  // ---------------------------------------------------------------------------

  /// Serializes the entire state to a JSON string.
  String toJson() {
    return Serializer.serialize(graph: _graph, viewport: _viewport);
  }

  /// Loads state from a JSON string.
  void fromJson(String jsonString) {
    _pushHistory();
    final result = Serializer.deserialize(jsonString);
    _graph = result.graph;
    _viewport = result.viewport;
    notifyListeners();
  }

  /// Serializes state to a JSON map.
  Map<String, dynamic> toMap() {
    return Serializer.toMap(graph: _graph, viewport: _viewport);
  }

  /// Loads state from a JSON map.
  void fromMap(Map<String, dynamic> map) {
    _pushHistory();
    final result = Serializer.fromMap(map);
    _graph = result.graph;
    _viewport = result.viewport;
    notifyListeners();
  }

  /// Clears all nodes, edges, viewport, history, and selection.
  void clear() {
    _pushHistory();
    _graph = FlowGraph();
    _viewport = const FlowViewport();
    selection.clearSelection();
    _history.clear();
    notifyListeners();
  }

  @override
  void dispose() {
    selection.dispose();
    super.dispose();
  }
}
