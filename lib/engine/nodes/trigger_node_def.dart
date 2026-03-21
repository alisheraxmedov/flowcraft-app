import 'package:flowcraft/engine/execution_context.dart';
import 'package:flowcraft/engine/execution_result.dart';
import 'package:flowcraft/engine/node_definition.dart';
import 'package:flowcraft/engine/param_definition.dart';
import 'package:flowcraft/engine/port_definition.dart';

/// Manual trigger node — starts a workflow execution.
///
/// Passes configured data as output to downstream nodes.
class TriggerNodeDef extends NodeDefinition {
  @override
  String get typeId => 'trigger';

  @override
  String get displayName => 'Trigger';

  @override
  String get category => 'Core';

  @override
  String get description => 'Starts the workflow execution';

  @override
  bool get isTrigger => true;

  @override
  List<PortDefinition> get inputs => [];

  @override
  List<PortDefinition> get outputs => [
        const PortDefinition(name: 'data', dataType: PortDataType.json),
      ];

  @override
  List<ParamDefinition> get params => [
        const ParamDefinition(
          name: 'payload',
          displayName: 'Initial Payload',
          type: ParamType.json,
          defaultValue: '{}',
          description: 'JSON data to pass to the first node',
        ),
      ];

  @override
  Future<ExecutionResult> execute(ExecutionContext context) async {
    final payload = context.params['payload'];
    final data = <String, dynamic>{};

    if (payload is Map<String, dynamic>) {
      data.addAll(payload);
    } else if (payload is String && payload.isNotEmpty) {
      data['payload'] = payload;
    }

    // Also pass through any non-internal params
    for (final entry in context.params.entries) {
      if (entry.key != 'definitionType' && entry.key != 'direction') {
        data[entry.key] = entry.value;
      }
    }

    return ExecutionResult.success(
      nodeId: context.nodeId,
      outputData: data,
    );
  }
}
