import 'package:flutter/foundation.dart';

import 'package:flowcraft/core/models/flow_graph.dart';
import 'package:flowcraft/core/models/flow_node.dart';
import 'package:flowcraft/engine/execution_context.dart';
import 'package:flowcraft/engine/execution_result.dart';
import 'package:flowcraft/engine/node_definition_registry.dart';
import 'package:flowcraft/engine/node_status.dart';
import 'package:flowcraft/engine/workflow_result.dart';

/// Callback for runtime status changes during execution.
typedef StatusCallback = void Function(String nodeId, NodeStatus status);

/// Executes a workflow graph by running nodes in topological order.
///
/// The engine resolves the execution order, passes data between nodes
/// via edges, and collects results from each node.
class ExecutionEngine {
  /// Executes the given [graph] using node definitions from [registry].
  ///
  /// [nodeTypeResolver] maps a [FlowNode] to its definition typeId.
  /// By default it uses `node.data['definitionType']`.
  ///
  /// [onStatusChanged] is called whenever a node's execution status changes.
  ///
  /// [credentials] are passed to all nodes during execution.
  static Future<WorkflowResult> execute({
    required FlowGraph graph,
    required NodeDefinitionRegistry registry,
    String Function(FlowNode node)? nodeTypeResolver,
    StatusCallback? onStatusChanged,
    Map<String, dynamic> credentials = const {},
  }) async {
    final stopwatch = Stopwatch()..start();
    final results = <String, ExecutionResult>{};
    final outputCache = <String, Map<String, dynamic>>{};

    final resolver =
        nodeTypeResolver ?? (node) => node.data['definitionType'] as String? ?? '';

    // Topological sort
    final sortedNodes = _topologicalSort(graph);

    for (final node in sortedNodes) {
      final typeId = resolver(node);
      final definition = registry.getDefinition(typeId);

      if (definition == null) {
        onStatusChanged?.call(node.id, NodeStatus.error);
        results[node.id] = ExecutionResult.error(
          nodeId: node.id,
          message: 'No definition found for type "$typeId"',
        );
        continue;
      }

      // Gather input data from upstream nodes via edges
      final inputData = _gatherInputData(graph, node.id, outputCache);

      // Build execution context
      final context = ExecutionContext(
        nodeId: node.id,
        inputData: inputData,
        params: Map<String, dynamic>.from(node.data),
        credentials: credentials,
      );

      // Execute
      onStatusChanged?.call(node.id, NodeStatus.running);
      final nodeStopwatch = Stopwatch()..start();

      try {
        final result = await definition.execute(context);
        nodeStopwatch.stop();

        final finalResult = ExecutionResult(
          nodeId: node.id,
          status: result.status,
          outputData: result.outputData,
          errorMessage: result.errorMessage,
          duration: nodeStopwatch.elapsed,
        );

        results[node.id] = finalResult;
        outputCache[node.id] = result.outputData;

        onStatusChanged?.call(node.id, finalResult.status);

        if (result.isError) {
          debugPrint(
              'FlowCraft: Node "${node.label}" (${node.id}) failed: ${result.errorMessage}');
        }
      } catch (e, stack) {
        nodeStopwatch.stop();
        final errorResult = ExecutionResult.error(
          nodeId: node.id,
          message: e.toString(),
          duration: nodeStopwatch.elapsed,
        );
        results[node.id] = errorResult;
        onStatusChanged?.call(node.id, NodeStatus.error);
        debugPrint('FlowCraft: Node "${node.label}" (${node.id}) threw: $e');
        debugPrint('$stack');
      }
    }

    stopwatch.stop();

    final hasError = results.values.any((r) => r.isError);

    return WorkflowResult(
      nodeResults: results,
      status: hasError ? NodeStatus.error : NodeStatus.success,
      duration: stopwatch.elapsed,
    );
  }

  /// Gathers input data for a node from all upstream connected nodes.
  static Map<String, dynamic> _gatherInputData(
    FlowGraph graph,
    String nodeId,
    Map<String, Map<String, dynamic>> outputCache,
  ) {
    final incoming = graph.incomingEdges(nodeId);
    if (incoming.isEmpty) return {};

    final merged = <String, dynamic>{};

    for (final edge in incoming) {
      final sourceOutput = outputCache[edge.sourceNodeId];
      if (sourceOutput != null) {
        merged.addAll(sourceOutput);
      }
    }

    return merged;
  }

  /// Performs a topological sort of the graph nodes (Kahn's algorithm).
  /// Nodes with no incoming edges come first (triggers/sources).
  static List<FlowNode> _topologicalSort(FlowGraph graph) {
    final inDegree = <String, int>{};
    final adjacency = <String, List<String>>{};

    for (final node in graph.nodes) {
      inDegree[node.id] = 0;
      adjacency[node.id] = [];
    }

    for (final edge in graph.edges) {
      inDegree[edge.targetNodeId] =
          (inDegree[edge.targetNodeId] ?? 0) + 1;
      adjacency[edge.sourceNodeId]?.add(edge.targetNodeId);
    }

    // Start with nodes that have no incoming edges
    final queue = <String>[];
    for (final entry in inDegree.entries) {
      if (entry.value == 0) queue.add(entry.key);
    }

    final sorted = <FlowNode>[];
    final nodeMap = {for (final n in graph.nodes) n.id: n};

    while (queue.isNotEmpty) {
      final current = queue.removeAt(0);
      final node = nodeMap[current];
      if (node != null) sorted.add(node);

      for (final neighbor in adjacency[current] ?? []) {
        inDegree[neighbor] = (inDegree[neighbor] ?? 1) - 1;
        if (inDegree[neighbor] == 0) queue.add(neighbor);
      }
    }

    // Add remaining nodes (in case of cycles, which shouldn't happen)
    for (final node in graph.nodes) {
      if (!sorted.contains(node)) sorted.add(node);
    }

    return sorted;
  }
}
