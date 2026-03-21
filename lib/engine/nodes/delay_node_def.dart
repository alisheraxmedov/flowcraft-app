import 'package:flowcraft/engine/execution_context.dart';
import 'package:flowcraft/engine/execution_result.dart';
import 'package:flowcraft/engine/node_definition.dart';
import 'package:flowcraft/engine/param_definition.dart';
import 'package:flowcraft/engine/port_definition.dart';

/// Delay node — pauses execution for a specified duration.
class DelayNodeDef extends NodeDefinition {
  @override
  String get typeId => 'delay';

  @override
  String get displayName => 'Delay';

  @override
  String get category => 'Flow';

  @override
  String get description => 'Pauses execution for a specified duration';

  @override
  List<PortDefinition> get inputs => [
        const PortDefinition(name: 'data', dataType: PortDataType.json),
      ];

  @override
  List<PortDefinition> get outputs => [
        const PortDefinition(name: 'data', dataType: PortDataType.json),
      ];

  @override
  List<ParamDefinition> get params => [
        const ParamDefinition(
          name: 'duration',
          displayName: 'Duration (ms)',
          type: ParamType.number,
          defaultValue: 1000,
          description: 'Delay in milliseconds',
        ),
      ];

  @override
  Future<ExecutionResult> execute(ExecutionContext context) async {
    final ms = context.getParam<num>('duration', 1000).toInt();
    await Future<void>.delayed(Duration(milliseconds: ms));

    return ExecutionResult.success(
      nodeId: context.nodeId,
      outputData: {
        ...context.inputData,
        '_delayed': true,
        '_delayMs': ms,
      },
    );
  }
}
