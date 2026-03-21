import 'package:flowcraft/engine/execution_context.dart';
import 'package:flowcraft/engine/execution_result.dart';
import 'package:flowcraft/engine/node_definition.dart';
import 'package:flowcraft/engine/param_definition.dart';
import 'package:flowcraft/engine/port_definition.dart';

/// Variable node — stores and retrieves named values in the workflow.
///
/// Can set new variables, read existing ones from input data,
/// or combine both operations.
class VariableNodeDef extends NodeDefinition {
  @override
  String get typeId => 'variable';

  @override
  String get displayName => 'Variable';

  @override
  String get category => 'Flow';

  @override
  String get description => 'Stores and retrieves named variables';

  @override
  List<PortDefinition> get inputs => [
        const PortDefinition(
          name: 'data',
          dataType: PortDataType.json,
          required: false,
        ),
      ];

  @override
  List<PortDefinition> get outputs => [
        const PortDefinition(name: 'data', dataType: PortDataType.json),
      ];

  @override
  List<ParamDefinition> get params => [
        const ParamDefinition(
          name: 'operation',
          displayName: 'Operation',
          type: ParamType.select,
          defaultValue: 'set',
          options: ['set', 'get', 'setAndGet'],
        ),
        const ParamDefinition(
          name: 'variables',
          displayName: 'Variables',
          type: ParamType.json,
          defaultValue: '{}',
          description: 'Key-value pairs of variable names and values',
        ),
      ];

  @override
  Future<ExecutionResult> execute(ExecutionContext context) async {
    final operation = context.getParam<String>('operation', 'set');
    final varsRaw = context.params['variables'];
    final vars = varsRaw is Map<String, dynamic>
        ? varsRaw
        : <String, dynamic>{};

    final data = Map<String, dynamic>.from(context.inputData);

    switch (operation) {
      case 'set':
        data.addAll(vars);
        break;
      case 'get':
        final result = <String, dynamic>{};
        for (final key in vars.keys) {
          if (data.containsKey(key)) {
            result[key] = data[key];
          }
        }
        return ExecutionResult.success(
          nodeId: context.nodeId,
          outputData: result,
        );
      case 'setAndGet':
        data.addAll(vars);
        break;
    }

    return ExecutionResult.success(
      nodeId: context.nodeId,
      outputData: data,
    );
  }
}
