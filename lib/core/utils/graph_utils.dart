import 'package:flowcraft/core/models/flow_edge.dart';
import 'package:flowcraft/core/models/flow_graph.dart';
import 'package:flowcraft/core/models/flow_node.dart';

/// Utility functions for inspecting and validating graph structure.
class GraphUtils {
  /// Checks whether adding an edge from [sourceNodeId] to [targetNodeId]
  /// would create a cycle in the graph.
  static bool wouldCreateCycle(
    FlowGraph graph,
    String sourceNodeId,
    String targetNodeId,
  ) {
    // BFS/DFS from targetNodeId to see if we can reach sourceNodeId
    final visited = <String>{};
    final queue = <String>[targetNodeId];

    while (queue.isNotEmpty) {
      final current = queue.removeAt(0);
      if (current == sourceNodeId) return true;
      if (visited.contains(current)) continue;
      visited.add(current);

      for (final edge in graph.outgoingEdges(current)) {
        queue.add(edge.targetNodeId);
      }
    }
    return false;
  }

  /// Returns whether a self-connection is being made (same source and target node).
  static bool isSelfConnection(String sourceNodeId, String targetNodeId) {
    return sourceNodeId == targetNodeId;
  }

  /// Returns whether an edge already exists between the same source and target handles.
  static bool isDuplicateEdge(
    FlowGraph graph, {
    required String sourceHandleId,
    required String targetHandleId,
  }) {
    return graph.edges.any(
      (e) =>
          e.sourceHandleId == sourceHandleId &&
          e.targetHandleId == targetHandleId,
    );
  }

  /// Validates an edge before adding it to the graph.
  ///
  /// Returns `null` if the edge is valid, or an error message if not.
  static String? validateEdge(
    FlowGraph graph, {
    required String sourceNodeId,
    required String targetNodeId,
    required String sourceHandleId,
    required String targetHandleId,
  }) {
    if (isSelfConnection(sourceNodeId, targetNodeId)) {
      return 'Cannot connect a node to itself';
    }

    if (isDuplicateEdge(graph,
        sourceHandleId: sourceHandleId, targetHandleId: targetHandleId)) {
      return 'Edge already exists between these handles';
    }

    if (graph.nodeById(sourceNodeId) == null) {
      return 'Source node not found';
    }

    if (graph.nodeById(targetNodeId) == null) {
      return 'Target node not found';
    }

    return null;
  }

  /// Returns all nodes that have no incoming edges (root/source nodes).
  static List<FlowNode> sourceNodes(FlowGraph graph) {
    final nodesWithIncoming = <String>{};
    for (final edge in graph.edges) {
      nodesWithIncoming.add(edge.targetNodeId);
    }
    return graph.nodes
        .where((n) => !nodesWithIncoming.contains(n.id))
        .toList();
  }

  /// Returns all nodes that have no outgoing edges (leaf/sink nodes).
  static List<FlowNode> sinkNodes(FlowGraph graph) {
    final nodesWithOutgoing = <String>{};
    for (final edge in graph.edges) {
      nodesWithOutgoing.add(edge.sourceNodeId);
    }
    return graph.nodes
        .where((n) => !nodesWithOutgoing.contains(n.id))
        .toList();
  }

  /// Removes all edges associated with the given [nodeId] from the graph.
  static List<FlowEdge> removeEdgesForNode(FlowGraph graph, String nodeId) {
    final removed = graph.edgesForNode(nodeId);
    graph.edges.removeWhere(
      (e) => e.sourceNodeId == nodeId || e.targetNodeId == nodeId,
    );
    return removed;
  }
}
