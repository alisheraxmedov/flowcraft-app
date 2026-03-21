import 'package:flowcraft/engine/execution_context.dart';
import 'package:flowcraft/engine/execution_result.dart';
import 'package:flowcraft/engine/node_definition.dart';
import 'package:flowcraft/engine/param_definition.dart';
import 'package:flowcraft/engine/port_definition.dart';

/// Transform node — modifies or reshapes data flowing through the workflow.
///
/// Supports operations: set (add/overwrite fields), rename, remove, keep.
class TransformNodeDef extends NodeDefinition {
  @override
  String get typeId => 'transform';

  @override
  String get displayName => 'Transform';

  @override
  String get category => 'Core';

  @override
  String get description => 'Transforms data by setting, renaming, or removing fields';

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
          name: 'operation',
          displayName: 'Operation',
          type: ParamType.select,
          defaultValue: 'set',
          options: ['set', 'rename', 'remove', 'keep'],
        ),
        const ParamDefinition(
          name: 'fields',
          displayName: 'Fields',
          type: ParamType.json,
          defaultValue: '{}',
          description: 'Key-value pairs for the operation',
        ),
      ];

  @override
  Future<ExecutionResult> execute(ExecutionContext context) async {
    final operation = context.getParam<String>('operation', 'set');
    final fieldsRaw = context.params['fields'];
    final fields = fieldsRaw is Map<String, dynamic>
        ? fieldsRaw
        : <String, dynamic>{};

    final data = Map<String, dynamic>.from(context.inputData);

    switch (operation) {
      case 'set':
        data.addAll(fields);
        break;

      case 'rename':
        for (final entry in fields.entries) {
          if (data.containsKey(entry.key)) {
            data[entry.value.toString()] = data.remove(entry.key);
          }
        }
        break;

      case 'remove':
        for (final key in fields.keys) {
          data.remove(key);
        }
        break;

      case 'keep':
        final keysToKeep = fields.keys.toSet();
        data.removeWhere((key, _) => !keysToKeep.contains(key));
        break;
    }

    return ExecutionResult.success(
      nodeId: context.nodeId,
      outputData: data,
    );
  }
}
