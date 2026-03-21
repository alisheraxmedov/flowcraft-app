import 'package:flowcraft/engine/execution_context.dart';
import 'package:flowcraft/engine/execution_result.dart';
import 'package:flowcraft/engine/node_definition.dart';
import 'package:flowcraft/engine/param_definition.dart';
import 'package:flowcraft/engine/port_definition.dart';

/// Merge node — combines data from multiple input connections.
class MergeNodeDef extends NodeDefinition {
  @override
  String get typeId => 'merge';

  @override
  String get displayName => 'Merge';

  @override
  String get category => 'Core';

  @override
  String get description => 'Merges data from multiple inputs into one output';

  @override
  List<PortDefinition> get inputs => [
        const PortDefinition(
          name: 'input1',
          dataType: PortDataType.json,
          required: false,
        ),
        const PortDefinition(
          name: 'input2',
          dataType: PortDataType.json,
          required: false,
        ),
      ];

  @override
  List<PortDefinition> get outputs => [
        const PortDefinition(name: 'merged', dataType: PortDataType.json),
      ];

  @override
  List<ParamDefinition> get params => [
        const ParamDefinition(
          name: 'mode',
          displayName: 'Merge Mode',
          type: ParamType.select,
          defaultValue: 'combine',
          options: ['combine', 'overwrite'],
        ),
      ];

  @override
  Future<ExecutionResult> execute(ExecutionContext context) async {
    return ExecutionResult.success(
      nodeId: context.nodeId,
      outputData: Map<String, dynamic>.from(context.inputData),
    );
  }
}
