import 'package:flowcraft/core/models/flow_edge.dart';
import 'package:flowcraft/core/models/flow_node.dart';

/// The container holding all nodes and edges in a flow graph.
///
/// Provides lookup helpers and serialization for the entire graph state.
/// Uses internal [Map]-based indexes for O(1) lookups by ID.
class FlowGraph {
  /// Creates a [FlowGraph].
  FlowGraph({
    List<FlowNode>? nodes,
    List<FlowEdge>? edges,
  })  : nodes = nodes ?? [],
        edges = edges ?? [] {
    _rebuildIndexes();
  }

  /// All nodes in the graph.
  final List<FlowNode> nodes;

  /// All edges in the graph.
  final List<FlowEdge> edges;

  final Map<String, FlowNode> _nodeIndex = {};
  final Map<String, FlowEdge> _edgeIndex = {};

  /// Rebuilds the internal lookup indexes from the current lists.
  void _rebuildIndexes() {
    _nodeIndex.clear();
    for (final node in nodes) {
      _nodeIndex[node.id] = node;
    }
    _edgeIndex.clear();
    for (final edge in edges) {
      _edgeIndex[edge.id] = edge;
    }
  }

  /// Registers a node in the index after adding it to [nodes].
  void indexNode(FlowNode node) => _nodeIndex[node.id] = node;

  /// Removes a node from the index.
  void unindexNode(String id) => _nodeIndex.remove(id);

  /// Registers an edge in the index after adding it to [edges].
  void indexEdge(FlowEdge edge) => _edgeIndex[edge.id] = edge;

  /// Removes an edge from the index.
  void unindexEdge(String id) => _edgeIndex.remove(id);

  /// Finds a node by its ID in O(1), or returns `null`.
  /// Falls back to linear scan for items added directly to the list.
  FlowNode? nodeById(String id) {
    final indexed = _nodeIndex[id];
    if (indexed != null) return indexed;
    for (final node in nodes) {
      if (node.id == id) {
        _nodeIndex[id] = node;
        return node;
      }
    }
    return null;
  }

  /// Finds an edge by its ID in O(1), or returns `null`.
  /// Falls back to linear scan for items added directly to the list.
  FlowEdge? edgeById(String id) {
    final indexed = _edgeIndex[id];
    if (indexed != null) return indexed;
    for (final edge in edges) {
      if (edge.id == id) {
        _edgeIndex[id] = edge;
        return edge;
      }
    }
    return null;
  }

  /// Returns all edges connected to the given [nodeId].
  List<FlowEdge> edgesForNode(String nodeId) {
    return edges
        .where(
            (e) => e.sourceNodeId == nodeId || e.targetNodeId == nodeId)
        .toList();
  }

  /// Returns all edges originating from the given [nodeId].
  List<FlowEdge> outgoingEdges(String nodeId) {
    return edges.where((e) => e.sourceNodeId == nodeId).toList();
  }

  /// Returns all edges targeting the given [nodeId].
  List<FlowEdge> incomingEdges(String nodeId) {
    return edges.where((e) => e.targetNodeId == nodeId).toList();
  }

  /// Creates a deep copy of this [FlowGraph].
  FlowGraph copyWith({
    List<FlowNode>? nodes,
    List<FlowEdge>? edges,
  }) {
    return FlowGraph(
      nodes:
          nodes ?? this.nodes.map((n) => n.copyWith()).toList(),
      edges:
          edges ?? this.edges.map((e) => e.copyWith()).toList(),
    );
  }

  /// Serializes this [FlowGraph] to a JSON map.
  Map<String, dynamic> toJson() {
    return {
      'nodes': nodes.map((n) => n.toJson()).toList(),
      'edges': edges.map((e) => e.toJson()).toList(),
    };
  }

  /// Deserializes a [FlowGraph] from a JSON map.
  factory FlowGraph.fromJson(Map<String, dynamic> json) {
    return FlowGraph(
      nodes: (json['nodes'] as List<dynamic>?)
              ?.map((n) => FlowNode.fromJson(n as Map<String, dynamic>))
              .toList() ??
          [],
      edges: (json['edges'] as List<dynamic>?)
              ?.map((e) => FlowEdge.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
  @override
  String toString() =>
      'FlowGraph(nodes: ${nodes.length}, edges: ${edges.length})';
}
