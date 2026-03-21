import 'package:flowcraft/engine/execution_context.dart';
import 'package:flowcraft/engine/execution_result.dart';
import 'package:flowcraft/engine/node_definition.dart';
import 'package:flowcraft/engine/param_definition.dart';
import 'package:flowcraft/engine/port_definition.dart';

/// Condition node — evaluates a condition and routes data accordingly.
///
/// Checks if a field exists, equals a value, or is non-empty,
/// then outputs on the 'true' or 'false' port.
class ConditionNodeDef extends NodeDefinition {
  @override
  String get typeId => 'condition';

  @override
  String get displayName => 'Condition';

  @override
  String get category => 'Core';

  @override
  String get description => 'Routes data based on a condition';

  @override
  List<PortDefinition> get inputs => [
        const PortDefinition(name: 'data', dataType: PortDataType.json),
      ];

  @override
  List<PortDefinition> get outputs => [
        const PortDefinition(name: 'true', dataType: PortDataType.json),
        const PortDefinition(name: 'false', dataType: PortDataType.json),
      ];

  @override
  List<ParamDefinition> get params => [
        const ParamDefinition(
          name: 'field',
          displayName: 'Field Name',
          type: ParamType.string,
          description: 'The data field to check',
        ),
        const ParamDefinition(
          name: 'operator',
          displayName: 'Operator',
          type: ParamType.select,
          defaultValue: 'exists',
          options: ['exists', 'equals', 'notEquals', 'contains', 'greaterThan', 'lessThan'],
        ),
        const ParamDefinition(
          name: 'value',
          displayName: 'Value',
          type: ParamType.string,
          defaultValue: '',
          description: 'Value to compare against',
        ),
      ];

  @override
  Future<ExecutionResult> execute(ExecutionContext context) async {
    final field = context.getParam<String>('field', '');
    final operator = context.getParam<String>('operator', 'exists');
    final compareValue = context.getParam<String>('value', '');

    final data = context.inputData;
    final fieldValue = data[field];

    final conditionResult = _evaluate(fieldValue, operator, compareValue);

    return ExecutionResult.success(
      nodeId: context.nodeId,
      outputData: {
        ...data,
        '_condition': conditionResult,
        '_branch': conditionResult ? 'true' : 'false',
      },
    );
  }

  bool _evaluate(dynamic fieldValue, String operator, String compareValue) {
    switch (operator) {
      case 'exists':
        return fieldValue != null;

      case 'equals':
        return fieldValue?.toString() == compareValue;

      case 'notEquals':
        return fieldValue?.toString() != compareValue;

      case 'contains':
        return fieldValue?.toString().contains(compareValue) ?? false;

      case 'greaterThan':
        final a = num.tryParse(fieldValue?.toString() ?? '');
        final b = num.tryParse(compareValue);
        return a != null && b != null && a > b;

      case 'lessThan':
        final a = num.tryParse(fieldValue?.toString() ?? '');
        final b = num.tryParse(compareValue);
        return a != null && b != null && a < b;

      default:
        return false;
    }
  }
}
