import 'package:flowcraft/engine/execution_context.dart';
import 'package:flowcraft/engine/execution_result.dart';
import 'package:flowcraft/engine/param_definition.dart';
import 'package:flowcraft/engine/port_definition.dart';

/// Abstract base class for all executable node types.
///
/// Each integration (HTTP, Transform, AI, etc.) extends this class
/// to define its ports, parameters, and execution logic.
///
/// ```dart
/// class MyCustomNode extends NodeDefinition {
///   @override
///   String get typeId => 'my_custom';
///
///   @override
///   Future<ExecutionResult> execute(ExecutionContext context) async {
///     final input = context.getInput<String>('data');
///     return ExecutionResult.success(
///       nodeId: context.nodeId,
///       outputData: {'result': input?.toUpperCase()},
///     );
///   }
/// }
/// ```
abstract class NodeDefinition {
  /// Unique type identifier (e.g., 'http_request', 'openai_chat').
  String get typeId;

  /// Human-readable display name.
  String get displayName;

  /// Category for grouping in the UI (e.g., 'Core', 'AI', 'Integration').
  String get category;

  /// Short description of what this node does.
  String get description;

  /// Input port definitions.
  List<PortDefinition> get inputs;

  /// Output port definitions.
  List<PortDefinition> get outputs;

  /// Configurable parameter definitions.
  List<ParamDefinition> get params;

  /// Whether this node can start a workflow (trigger).
  bool get isTrigger => false;

  /// Execute this node with the given context.
  ///
  /// Implementations should read from [context.inputData] and [context.params],
  /// perform their logic, and return an [ExecutionResult] with output data.
  Future<ExecutionResult> execute(ExecutionContext context);
}
