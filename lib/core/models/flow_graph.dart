import 'package:flowcraft/core/models/flow_edge.dart';
import 'package:flowcraft/core/models/flow_node.dart';

/// The container holding all nodes and edges in a flow graph.
///
/// Provides lookup helpers and serialization for the entire graph state.
class FlowGraph {
  /// Creates a [FlowGraph].
  FlowGraph({
    List<FlowNode>? nodes,
    List<FlowEdge>? edges,
  })  : nodes = nodes ?? [],
        edges = edges ?? [];

  /// All nodes in the graph.
  final List<FlowNode> nodes;

  /// All edges in the graph.
  final List<FlowEdge> edges;

  /// Finds a node by its ID, or returns `null`.
  FlowNode? nodeById(String id) {
    for (final node in nodes) {
      if (node.id == id) return node;
    }
    return null;
  }

  /// Finds an edge by its ID, or returns `null`.
  FlowEdge? edgeById(String id) {
    for (final edge in edges) {
      if (edge.id == id) return edge;
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
