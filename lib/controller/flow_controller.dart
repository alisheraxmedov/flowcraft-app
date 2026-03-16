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

/// Central state manager for FlowCraft.
///
/// Holds the graph (nodes + edges), viewport, selection, and history.
/// Extends [ChangeNotifier] for reactive UI updates.
class FlowController extends ChangeNotifier {
  FlowController({
    FlowGraph? graph,
    FlowViewport? viewport,
    int maxHistory = 50,
    this.snapToGrid = false,
    this.gridSnap = 20.0,
  })  : _graph = graph ?? FlowGraph(),
        _viewport = viewport ?? const FlowViewport(),
        _history = HistoryManager(maxHistory: maxHistory),
        selection = SelectionManager() {
    selection.addListener(notifyListeners);
  }

  FlowGraph _graph;
  FlowViewport _viewport;
  final HistoryManager _history;
  final SelectionManager selection;

  /// Whether node positions snap to grid during drag.
  bool snapToGrid;

  /// Grid snap interval in logical pixels.
  double gridSnap;

  /// Whether a node is currently being dragged.
  /// Used to prevent canvas pan during node drag.
  bool isDraggingNode = false;

  /// Tracks which nodes are being dragged for deferred snap.
  final Set<String> _draggingNodeIds = {};

  static const List<Color> _edgeColors = [
    Color(0xFF42A5F5), // Blue
    Color(0xFF66BB6A), // Green
    Color(0xFFAB47BC), // Purple
    Color(0xFFEF5350), // Red
    Color(0xFFFFA726), // Orange
    Color(0xFF26C6DA), // Cyan
    Color(0xFFEC407A), // Pink
    Color(0xFF8D6E63), // Brown
  ];

  int _edgeColorIndex = 0;
  List<Map<String, dynamic>> _clipboard = [];

  List<FlowNode>? _cachedNodes;
  List<FlowEdge>? _cachedEdges;

  // ── Getters ───────────────────────────────────────────────────────────────

  FlowGraph get graph => _graph;

  List<FlowNode> get nodes =>
      _cachedNodes ??= List.unmodifiable(_graph.nodes);

  List<FlowEdge> get edges =>
      _cachedEdges ??= List.unmodifiable(_graph.edges);

  FlowViewport get viewport => _viewport;
  bool get canUndo => _history.canUndo;
  bool get canRedo => _history.canRedo;

  void _invalidateCache() {
    _cachedNodes = null;
    _cachedEdges = null;
  }

  // ── Nodes ─────────────────────────────────────────────────────────────────

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
    _graph.indexNode(node);
    _invalidateCache();
    notifyListeners();
    return node;
  }

  void removeNode(String nodeId) {
    _pushHistory();
    GraphUtils.removeEdgesForNode(_graph, nodeId);
    _graph.nodes.removeWhere((n) => n.id == nodeId);
    _graph.unindexNode(nodeId);
    _invalidateCache();
    selection.deselectNode(nodeId);
    notifyListeners();
  }

  void moveNode(String nodeId, Offset newPosition) {
    final node = _graph.nodeById(nodeId);
    if (node == null) return;
    node.position = snapToGrid ? _snap(newPosition) : newPosition;
    notifyListeners();
  }

  void moveNodeBy(String nodeId, Offset delta) {
    final node = _graph.nodeById(nodeId);
    if (node == null) return;
    final raw = node.position + delta;
    node.position = (snapToGrid && !isDraggingNode) ? _snap(raw) : raw;
    notifyListeners();
  }

  Offset _snap(Offset pos) {
    return Offset(
      (pos.dx / gridSnap).round() * gridSnap,
      (pos.dy / gridSnap).round() * gridSnap,
    );
  }

  void startNodeDrag(String nodeId) {
    _pushHistory();
    isDraggingNode = true;
    _draggingNodeIds.add(nodeId);
  }

  void endNodeDrag() {
    if (snapToGrid) {
      for (final id in _draggingNodeIds) {
        final node = _graph.nodeById(id);
        if (node != null) {
          node.position = _snap(node.position);
        }
      }
    }
    _draggingNodeIds.clear();
    isDraggingNode = false;
    notifyListeners();
  }

  void renameNode(String nodeId, String newLabel) {
    _pushHistory();
    _graph.nodeById(nodeId)?.label = newLabel;
    notifyListeners();
  }

  void setNodeType(String nodeId, NodeType newType) {
    _pushHistory();
    _graph.nodeById(nodeId)?.type = newType;
    notifyListeners();
  }

  void resizeNode(String nodeId, Size newSize) {
    _pushHistory();
    _graph.nodeById(nodeId)?.size = newSize;
    notifyListeners();
  }

  void addNodeField(String nodeId, {required String key, dynamic value}) {
    _pushHistory();
    _graph.nodeById(nodeId)?.data[key] = value;
    notifyListeners();
  }

  void removeNodeField(String nodeId, String key) {
    _pushHistory();
    _graph.nodeById(nodeId)?.data.remove(key);
    notifyListeners();
  }

  // ── Edges ─────────────────────────────────────────────────────────────────

  /// Creates an edge. Returns `null` if validation fails.
  /// Auto-assigns a vibrant color when no custom style is given.
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

    final effectiveStyle = style ??
        EdgeStyle(
          color: _edgeColors[_edgeColorIndex % _edgeColors.length],
        );
    _edgeColorIndex++;

    _pushHistory();
    final edge = FlowEdge(
      sourceNodeId: sourceNodeId,
      targetNodeId: targetNodeId,
      sourceHandleId: sourceHandleId,
      targetHandleId: targetHandleId,
      style: effectiveStyle,
    );
    _graph.edges.add(edge);
    _graph.indexEdge(edge);
    _invalidateCache();
    notifyListeners();
    return edge;
  }

  void removeEdge(String edgeId) {
    _pushHistory();
    _graph.edges.removeWhere((e) => e.id == edgeId);
    _graph.unindexEdge(edgeId);
    _invalidateCache();
    selection.deselectEdge(edgeId);
    notifyListeners();
  }

  void updateEdgeStyle(String edgeId, EdgeStyle newStyle) {
    _pushHistory();
    _graph.edgeById(edgeId)?.style = newStyle;
    notifyListeners();
  }

  // ── Viewport ──────────────────────────────────────────────────────────────

  void pan(Offset newOffset) {
    _viewport = _viewport.copyWith(offset: newOffset);
    notifyListeners();
  }

  void panBy(Offset delta) {
    _viewport = _viewport.copyWith(
      offset: _viewport.offset + delta,
    );
    notifyListeners();
  }

  void setZoom(double zoom) {
    _viewport = _viewport.copyWith(zoom: zoom);
    notifyListeners();
  }

  /// Sets offset and zoom in a single update to avoid double rebuild.
  void setViewport({Offset? offset, double? zoom}) {
    _viewport = _viewport.copyWith(offset: offset, zoom: zoom);
    notifyListeners();
  }

  void zoomIn({double factor = 0.1}) => setZoom(_viewport.zoom + factor);
  void zoomOut({double factor = 0.1}) => setZoom(_viewport.zoom - factor);

  void fitView(Size canvasSize) {
    if (_graph.nodes.isEmpty) return;

    final positions = _graph.nodes.map((n) => n.position).toList();
    final bottomRights = _graph.nodes
        .map((n) => n.position + Offset(n.size.width, n.size.height))
        .toList();

    final bounds = MathUtils.boundingRect(
      [...positions, ...bottomRights],
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

  // ── Selection ─────────────────────────────────────────────────────────────

  void selectAll() {
    selection.selectAll(
      _graph.nodes.map((n) => n.id).toSet(),
      _graph.edges.map((e) => e.id).toSet(),
    );
  }

  void deleteSelection() {
    _pushHistory();
    final edgeIds = Set<String>.of(selection.selectedEdgeIds);
    final nodeIds = Set<String>.of(selection.selectedNodeIds);
    for (final id in edgeIds) {
      _graph.edges.removeWhere((e) => e.id == id);
      _graph.unindexEdge(id);
    }
    for (final id in nodeIds) {
      GraphUtils.removeEdgesForNode(_graph, id);
      _graph.nodes.removeWhere((n) => n.id == id);
      _graph.unindexNode(id);
    }
    _invalidateCache();
    selection.clearSelection();
    notifyListeners();
  }

  // ── History ───────────────────────────────────────────────────────────────

  void undo() {
    final previous = _history.undo(_graph);
    if (previous != null) {
      _graph = previous;
      _invalidateCache();
      notifyListeners();
    }
  }

  void redo() {
    final next = _history.redo(_graph);
    if (next != null) {
      _graph = next;
      _invalidateCache();
      notifyListeners();
    }
  }

  void _pushHistory() => _history.pushSnapshot(_graph);

  // ── Copy / Paste ──────────────────────────────────────────────────────────

  void copySelectedNodes() {
    _clipboard = selection.selectedNodeIds
        .map((id) => _graph.nodeById(id))
        .whereType<FlowNode>()
        .map((n) => n.toJson())
        .toList();
  }

  void pasteNodes({Offset offset = const Offset(30, 30)}) {
    if (_clipboard.isEmpty) return;
    _pushHistory();
    selection.clearSelection();
    for (final json in _clipboard) {
      final original = FlowNode.fromJson(json);
      final pasted = addNode(
        type: original.type,
        label: '${original.label} (copy)',
        position: original.position + offset,
        size: original.size,
        data: Map<String, dynamic>.from(original.data),
      );
      selection.selectNode(pasted.id, clearExisting: false);
    }
  }

  // ── Serialization ─────────────────────────────────────────────────────────

  String toJson() => Serializer.serialize(graph: _graph, viewport: _viewport);

  void fromJson(String jsonString) {
    _pushHistory();
    final result = Serializer.deserialize(jsonString);
    _graph = result.graph;
    _viewport = result.viewport;
    _invalidateCache();
    notifyListeners();
  }

  Map<String, dynamic> toMap() {
    return Serializer.toMap(graph: _graph, viewport: _viewport);
  }

  void fromMap(Map<String, dynamic> map) {
    _pushHistory();
    final result = Serializer.fromMap(map);
    _graph = result.graph;
    _viewport = result.viewport;
    _invalidateCache();
    notifyListeners();
  }

  void clear() {
    _pushHistory();
    _graph = FlowGraph();
    _viewport = const FlowViewport();
    _invalidateCache();
    selection.clearSelection();
    _history.clear();
    notifyListeners();
  }

  @override
  void dispose() {
    selection.removeListener(notifyListeners);
    selection.dispose();
    super.dispose();
  }
}
