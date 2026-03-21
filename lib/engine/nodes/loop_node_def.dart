import 'package:flowcraft/engine/execution_context.dart';
import 'package:flowcraft/engine/execution_result.dart';
import 'package:flowcraft/engine/node_definition.dart';
import 'package:flowcraft/engine/param_definition.dart';
import 'package:flowcraft/engine/port_definition.dart';

/// Loop node — iterates over a list field and outputs each item.
///
/// Collects items from a specified field in the input data,
/// then outputs all items as a list with iteration metadata.
class LoopNodeDef extends NodeDefinition {
  @override
  String get typeId => 'loop';

  @override
  String get displayName => 'Loop';

  @override
  String get category => 'Flow';

  @override
  String get description => 'Iterates over a list and outputs each item';

  @override
  List<PortDefinition> get inputs => [
        const PortDefinition(name: 'data', dataType: PortDataType.json),
      ];

  @override
  List<PortDefinition> get outputs => [
        const PortDefinition(name: 'item', dataType: PortDataType.json),
      ];

  @override
  List<ParamDefinition> get params => [
        const ParamDefinition(
          name: 'listField',
          displayName: 'List Field',
          type: ParamType.string,
          defaultValue: 'items',
          description: 'The field name containing the list to iterate',
        ),
        const ParamDefinition(
          name: 'maxIterations',
          displayName: 'Max Iterations',
          type: ParamType.number,
          defaultValue: 100,
          description: 'Safety limit for maximum iterations',
        ),
      ];

  @override
  Future<ExecutionResult> execute(ExecutionContext context) async {
    final fieldName = context.getParam<String>('listField', 'items');
    final maxIter = context.getParam<num>('maxIterations', 100).toInt();

    final raw = context.inputData[fieldName];
    final items = raw is List ? raw : [raw];
    final limited = items.take(maxIter).toList();

    return ExecutionResult.success(
      nodeId: context.nodeId,
      outputData: {
        'items': limited,
        'totalCount': items.length,
        'processedCount': limited.length,
        '_loopCompleted': true,
      },
    );
  }
}
