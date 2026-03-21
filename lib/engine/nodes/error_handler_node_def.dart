import 'package:flutter/foundation.dart';

import 'package:flowcraft/engine/execution_context.dart';
import 'package:flowcraft/engine/execution_result.dart';
import 'package:flowcraft/engine/node_definition.dart';
import 'package:flowcraft/engine/param_definition.dart';
import 'package:flowcraft/engine/port_definition.dart';

/// Error Handler node — wraps upstream data and catches errors.
///
/// If an error field exists in input data, routes to the error output.
/// Otherwise passes data through to the success output.
class ErrorHandlerNodeDef extends NodeDefinition {
  @override
  String get typeId => 'error_handler';

  @override
  String get displayName => 'Error Handler';

  @override
  String get category => 'Flow';

  @override
  String get description => 'Catches errors and provides fallback data';

  @override
  List<PortDefinition> get inputs => [
        const PortDefinition(name: 'data', dataType: PortDataType.json),
      ];

  @override
  List<PortDefinition> get outputs => [
        const PortDefinition(name: 'success', dataType: PortDataType.json),
        const PortDefinition(name: 'error', dataType: PortDataType.json),
      ];

  @override
  List<ParamDefinition> get params => [
        const ParamDefinition(
          name: 'errorField',
          displayName: 'Error Field',
          type: ParamType.string,
          defaultValue: '_error',
          description: 'Field name that indicates an error in input data',
        ),
        const ParamDefinition(
          name: 'fallbackValue',
          displayName: 'Fallback Value',
          type: ParamType.json,
          defaultValue: '{}',
          description: 'Default data to output when an error is caught',
        ),
        const ParamDefinition(
          name: 'continueOnError',
          displayName: 'Continue on Error',
          type: ParamType.boolean,
          defaultValue: true,
          description: 'Whether to continue workflow execution on error',
        ),
      ];

  @override
  Future<ExecutionResult> execute(ExecutionContext context) async {
    final errorField = context.getParam<String>('errorField', '_error');
    final continueOnError = context.getParam<bool>('continueOnError', true);
    final fallbackRaw = context.params['fallbackValue'];
    final fallback = fallbackRaw is Map<String, dynamic>
        ? fallbackRaw
        : <String, dynamic>{};

    final data = context.inputData;
    final hasError = data.containsKey(errorField) && data[errorField] != null;

    if (hasError) {
      debugPrint(
          'FlowCraft ErrorHandler: caught error in "$errorField": ${data[errorField]}');

      if (!continueOnError) {
        return ExecutionResult.error(
          nodeId: context.nodeId,
          message: 'Error caught: ${data[errorField]}',
        );
      }

      return ExecutionResult.success(
        nodeId: context.nodeId,
        outputData: {
          ...fallback,
          '_errorCaught': true,
          '_originalError': data[errorField],
        },
      );
    }

    return ExecutionResult.success(
      nodeId: context.nodeId,
      outputData: data,
    );
  }
}
