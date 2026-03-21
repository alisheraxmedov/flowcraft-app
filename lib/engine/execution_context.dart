/// Runtime context passed to a node during workflow execution.
///
/// Contains upstream data, configured parameters, and credentials.
class ExecutionContext {
  const ExecutionContext({
    required this.nodeId,
    this.inputData = const {},
    this.params = const {},
    this.credentials = const {},
  });

  /// The current node's ID.
  final String nodeId;

  /// Combined input data from all upstream nodes.
  /// Keys are port names, values are the data.
  final Map<String, dynamic> inputData;

  /// Configured parameter values from the node's `data` field.
  final Map<String, dynamic> params;

  /// Credential values (API keys, tokens, etc.).
  final Map<String, dynamic> credentials;

  /// Gets a typed input value by port name.
  T? getInput<T>(String portName) {
    final value = inputData[portName];
    return value is T ? value : null;
  }

  /// Gets a typed parameter value by name, with optional default.
  T getParam<T>(String name, T defaultValue) {
    final value = params[name];
    return value is T ? value : defaultValue;
  }

  /// Gets a credential value by key.
  String? getCredential(String key) {
    final value = credentials[key];
    return value is String ? value : null;
  }
}
