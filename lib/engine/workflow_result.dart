import 'package:flowcraft/engine/execution_result.dart';
import 'package:flowcraft/engine/node_status.dart';

/// Aggregate result of executing an entire workflow.
class WorkflowResult {
  const WorkflowResult({
    required this.nodeResults,
    required this.status,
    required this.duration,
  });

  /// Results per node, keyed by node ID.
  final Map<String, ExecutionResult> nodeResults;

  /// Overall workflow status.
  final NodeStatus status;

  /// Total execution duration.
  final Duration duration;

  bool get isSuccess => status == NodeStatus.success;
  bool get isError => status == NodeStatus.error;

  /// Gets the output data of a specific node.
  Map<String, dynamic>? outputOf(String nodeId) {
    return nodeResults[nodeId]?.outputData;
  }

  /// All error messages from failed nodes.
  List<String> get errors {
    return nodeResults.values
        .where((r) => r.isError && r.errorMessage != null)
        .map((r) => '${r.nodeId}: ${r.errorMessage}')
        .toList();
  }
}
