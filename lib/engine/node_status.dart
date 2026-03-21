/// Runtime status of a node during workflow execution.
enum NodeStatus {
  /// Node has not been executed.
  idle,

  /// Node is waiting to be executed.
  queued,

  /// Node is currently executing.
  running,

  /// Node executed successfully.
  success,

  /// Node execution failed.
  error,

  /// Node was skipped (e.g. condition branch not taken).
  skipped,
}
