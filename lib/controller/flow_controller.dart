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
import 'package:flowcraft/engine/execution_engine.dart';
import 'package:flowcraft/engine/execution_result.dart';
import 'package:flowcraft/engine/node_definition_registry.dart';
import 'package:flowcraft/engine/node_status.dart';
import 'package:flowcraft/engine/workflow_result.dart';
import 'package:flowcraft/nodes/node_type_registry.dart';

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

  /// Registry of available node type definitions for execution.
  final NodeDefinitionRegistry nodeDefinitionRegistry = NodeDefinitionRegistry();

  /// Registry of custom node widget builders for rendering.
  final NodeTypeRegistry nodeTypeRegistry = NodeTypeRegistry();

  /// Runtime status of each node during/after workflow execution.
  final Map<String, NodeStatus> runtimeStates = {};

  /// Execution results per node after workflow execution.
  final Map<String, ExecutionResult> nodeResults = {};

  /// Whether a workflow is currently executing.
  bool isExecuting = false;

  /// The last workflow execution result.
  WorkflowResult? lastWorkflowResult;

  /// Persistent credentials (API keys, tokens) used across executions.
  Map<String, dynamic> _credentials = {};

  /// Sets persistent credentials that are automatically merged into
  /// every [executeWorkflow] call.
  void setCredentials(Map<String, dynamic> creds) {
    _credentials = Map<String, dynamic>.from(creds);
  }

  /// Returns a copy of the current credentials.
  Map<String, dynamic> get credentials => Map.unmodifiable(_credentials);

  /// Whether node positions snap to grid during drag.
  bool snapToGrid;

  /// Grid snap interval in logical pixels.
  double gridSnap;

  bool _nodeTapped = false;

  /// Marks that a node tap occurred this frame.
  void markNodeTapped() => _nodeTapped = true;

  /// Returns true and resets if a node was tapped this frame.
  bool consumeNodeTap() {
    if (_nodeTapped) {
      _nodeTapped = false;
      return true;
    }
    return false;
  }

  /// Whether a node is currently being dragged.
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

  int _paintGen = 0;

  /// Monotonically increasing version bumped whenever something visible
  /// to canvas painters changes (node positions, sizes, edges, styles).
  /// Used by [CustomPainter.shouldRepaint] checks to detect change in O(1).
  int get paintGen => _paintGen;

  /// Bumps the paint generation and notifies listeners.
  /// Centralises notify+gen-bump to avoid divergence.
  void _notifyPainters() {
    _paintGen++;
    notifyListeners();
  }

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
    _notifyPainters();
    return node;
  }

  void removeNode(String nodeId) {
    _pushHistory();
    GraphUtils.removeEdgesForNode(_graph, nodeId);
    _graph.nodes.removeWhere((n) => n.id == nodeId);
    _graph.unindexNode(nodeId);
    _invalidateCache();
    selection.deselectNode(nodeId);
    _notifyPainters();
  }

  void moveNode(String nodeId, Offset newPosition) {
    final node = _graph.nodeById(nodeId);
    if (node == null) return;
    node.position = snapToGrid ? _snap(newPosition) : newPosition;
    _notifyPainters();
  }

  void moveNodeBy(String nodeId, Offset delta) {
    final node = _graph.nodeById(nodeId);
    if (node == null) return;
    final raw = node.position + delta;
    node.position = (snapToGrid && !isDraggingNode) ? _snap(raw) : raw;
    _notifyPainters();
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
    _notifyPainters();
  }

  void renameNode(String nodeId, String newLabel) {
    _pushHistory();
    _graph.nodeById(nodeId)?.label = newLabel;
    _notifyPainters();
  }

  void setNodeType(String nodeId, NodeType newType) {
    _pushHistory();
    _graph.nodeById(nodeId)?.type = newType;
    _notifyPainters();
  }

  void resizeNode(String nodeId, Size newSize) {
    _pushHistory();
    _graph.nodeById(nodeId)?.size = newSize;
    _notifyPainters();
  }

  void addNodeField(String nodeId, {required String key, dynamic value}) {
    _pushHistory();
    _graph.nodeById(nodeId)?.data[key] = value;
    _notifyPainters();
  }

  void removeNodeField(String nodeId, String key) {
    _pushHistory();
    _graph.nodeById(nodeId)?.data.remove(key);
    _notifyPainters();
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
    _notifyPainters();
    return edge;
  }

  void removeEdge(String edgeId) {
    _pushHistory();
    _graph.edges.removeWhere((e) => e.id == edgeId);
    _graph.unindexEdge(edgeId);
    _invalidateCache();
    selection.deselectEdge(edgeId);
    _notifyPainters();
  }

  void updateEdgeStyle(String edgeId, EdgeStyle newStyle) {
    _pushHistory();
    _graph.edgeById(edgeId)?.style = newStyle;
    _notifyPainters();
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
    _notifyPainters();
  }

  // ── History ───────────────────────────────────────────────────────────────

  void undo() {
    final previous = _history.undo(_graph);
    if (previous != null) {
      _graph = previous;
      _invalidateCache();
      _notifyPainters();
    }
  }

  void redo() {
    final next = _history.redo(_graph);
    if (next != null) {
      _graph = next;
      _invalidateCache();
      _notifyPainters();
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
    _notifyPainters();
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
    _notifyPainters();
  }

  void clear() {
    _pushHistory();
    _graph = FlowGraph();
    _viewport = const FlowViewport();
    _invalidateCache();
    selection.clearSelection();
    _history.clear();
    runtimeStates.clear();
    nodeResults.clear();
    lastWorkflowResult = null;
    _notifyPainters();
  }

  // ── Workflow Execution ──────────────────────────────────────────────────

  /// Executes the current workflow graph.
  ///
  /// Uses the [nodeDefinitionRegistry] to resolve node types.
  /// Updates [runtimeStates] during execution for UI feedback.
  Future<WorkflowResult> executeWorkflow({
    Map<String, dynamic> credentials = const {},
  }) async {
    if (isExecuting) {
      return WorkflowResult(
        nodeResults: {},
        status: NodeStatus.error,
        duration: Duration.zero,
      );
    }

    isExecuting = true;
    runtimeStates.clear();
    nodeResults.clear();

    // Merge persistent and per-call credentials
    final mergedCredentials = <String, dynamic>{
      ..._credentials,
      ...credentials,
    };

    // Set all nodes to queued
    for (final node in _graph.nodes) {
      runtimeStates[node.id] = NodeStatus.queued;
    }
    notifyListeners();

    final result = await ExecutionEngine.execute(
      graph: _graph,
      registry: nodeDefinitionRegistry,
      credentials: mergedCredentials,
      nodeTypeResolver: (node) =>
          node.data['definitionType'] as String? ?? node.type.name,
      onStatusChanged: (nodeId, status) {
        runtimeStates[nodeId] = status;
        notifyListeners();
      },
    );

    lastWorkflowResult = result;
    nodeResults.addAll(result.nodeResults);
    isExecuting = false;
    notifyListeners();

    return result;
  }

  /// Resets all runtime states to idle.
  void resetRuntimeStates() {
    runtimeStates.clear();
    nodeResults.clear();
    lastWorkflowResult = null;
    notifyListeners();
  }

  /// Gets the runtime status of a specific node.
  NodeStatus nodeStatus(String nodeId) {
    return runtimeStates[nodeId] ?? NodeStatus.idle;
  }

  @override
  void dispose() {
    selection.removeListener(notifyListeners);
    selection.dispose();
    super.dispose();
  }
}
