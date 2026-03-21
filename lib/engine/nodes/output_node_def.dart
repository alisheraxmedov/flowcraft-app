import 'package:flowcraft/engine/execution_context.dart';
import 'package:flowcraft/engine/execution_result.dart';
import 'package:flowcraft/engine/node_definition.dart';
import 'package:flowcraft/engine/param_definition.dart';
import 'package:flowcraft/engine/port_definition.dart';

/// Output node — terminal node that collects the final workflow output.
class OutputNodeDef extends NodeDefinition {
  @override
  String get typeId => 'output';

  @override
  String get displayName => 'Output';

  @override
  String get category => 'Core';

  @override
  String get description => 'Collects the final output of the workflow';

  @override
  List<PortDefinition> get inputs => [
        const PortDefinition(name: 'data', dataType: PortDataType.json),
      ];

  @override
  List<PortDefinition> get outputs => [];

  @override
  List<ParamDefinition> get params => [
        const ParamDefinition(
          name: 'label',
          displayName: 'Output Label',
          type: ParamType.string,
          defaultValue: 'Result',
        ),
      ];

  @override
  Future<ExecutionResult> execute(ExecutionContext context) async {
    final label = context.getParam<String>('label', 'Result');

    return ExecutionResult.success(
      nodeId: context.nodeId,
      outputData: {
        'label': label,
        ...context.inputData,
      },
    );
  }
}
