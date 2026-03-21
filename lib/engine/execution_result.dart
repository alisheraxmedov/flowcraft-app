import 'package:flowcraft/engine/node_status.dart';

/// The result of executing a single node.
class ExecutionResult {
  const ExecutionResult({
    required this.nodeId,
    required this.status,
    this.outputData = const {},
    this.errorMessage,
    this.duration = Duration.zero,
  });

  /// Convenience factory for successful execution.
  factory ExecutionResult.success({
    required String nodeId,
    Map<String, dynamic> outputData = const {},
    Duration duration = Duration.zero,
  }) {
    return ExecutionResult(
      nodeId: nodeId,
      status: NodeStatus.success,
      outputData: outputData,
      duration: duration,
    );
  }

  /// Convenience factory for failed execution.
  factory ExecutionResult.error({
    required String nodeId,
    required String message,
    Duration duration = Duration.zero,
  }) {
    return ExecutionResult(
      nodeId: nodeId,
      status: NodeStatus.error,
      errorMessage: message,
      duration: duration,
    );
  }

  /// Convenience factory for skipped nodes.
  factory ExecutionResult.skipped({required String nodeId}) {
    return ExecutionResult(
      nodeId: nodeId,
      status: NodeStatus.skipped,
    );
  }

  /// The node that was executed.
  final String nodeId;

  /// The execution status.
  final NodeStatus status;

  /// Output data produced by the node.
  final Map<String, dynamic> outputData;

  /// Error message if execution failed.
  final String? errorMessage;

  /// How long the execution took.
  final Duration duration;

  bool get isSuccess => status == NodeStatus.success;
  bool get isError => status == NodeStatus.error;
}
