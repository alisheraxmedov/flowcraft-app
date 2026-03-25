import 'package:flutter_test/flutter_test.dart';

import 'package:flowcraft/engine/execution_context.dart';
import 'package:flowcraft/engine/nodes/delay_node_def.dart';
import 'package:flowcraft/engine/nodes/loop_node_def.dart';
import 'package:flowcraft/engine/nodes/merge_node_def.dart';
import 'package:flowcraft/engine/nodes/output_node_def.dart';
import 'package:flowcraft/engine/nodes/trigger_node_def.dart';
import 'package:flowcraft/engine/nodes/variable_node_def.dart';
import 'package:flowcraft/engine/nodes/error_handler_node_def.dart';

void main() {
  // ─────────────────────────────────────────────────────────────────────
  // DelayNodeDef
  // ─────────────────────────────────────────────────────────────────────

  group('DelayNodeDef', () {
    late DelayNodeDef node;
    setUp(() => node = DelayNodeDef());

    test('metadata', () {
      expect(node.typeId, 'delay');
      expect(node.category, 'Flow');
      expect(node.isTrigger, isFalse);
    });

    test('passes input data through with delay metadata', () async {
      final ctx = ExecutionContext(
        nodeId: 'n1',
        inputData: const {'key': 'value'},
        params: const {'duration': 1}, // 1ms for fast test
      );
      final result = await node.execute(ctx);
      expect(result.isSuccess, isTrue);
      expect(result.outputData['key'], 'value');
      expect(result.outputData['_delayed'], isTrue);
      expect(result.outputData['_delayMs'], 1);
    });
  });

  // ─────────────────────────────────────────────────────────────────────
  // LoopNodeDef
  // ─────────────────────────────────────────────────────────────────────

  group('LoopNodeDef', () {
    late LoopNodeDef node;
    setUp(() => node = LoopNodeDef());

    test('metadata', () {
      expect(node.typeId, 'loop');
      expect(node.category, 'Flow');
    });

    test('iterates over a list field', () async {
      final ctx = ExecutionContext(
        nodeId: 'n1',
        inputData: const {
          'items': [1, 2, 3],
        },
        params: const {'listField': 'items', 'maxIterations': 100},
      );
      final result = await node.execute(ctx);
      expect(result.isSuccess, isTrue);
      expect(result.outputData['items'], [1, 2, 3]);
      expect(result.outputData['totalCount'], 3);
      expect(result.outputData['processedCount'], 3);
      expect(result.outputData['_loopCompleted'], isTrue);
    });

    test('respects maxIterations', () async {
      final ctx = ExecutionContext(
        nodeId: 'n1',
        inputData: const {
          'items': [1, 2, 3, 4, 5],
        },
        params: const {'listField': 'items', 'maxIterations': 2},
      );
      final result = await node.execute(ctx);
      expect(result.outputData['processedCount'], 2);
      expect(result.outputData['totalCount'], 5);
    });

    test('wraps non-list value in a list', () async {
      final ctx = ExecutionContext(
        nodeId: 'n1',
        inputData: const {'items': 'single_value'},
        params: const {'listField': 'items', 'maxIterations': 100},
      );
      final result = await node.execute(ctx);
      expect(result.outputData['items'], ['single_value']);
      expect(result.outputData['totalCount'], 1);
    });
  });

  // ─────────────────────────────────────────────────────────────────────
  // MergeNodeDef
  // ─────────────────────────────────────────────────────────────────────

  group('MergeNodeDef', () {
    late MergeNodeDef node;
    setUp(() => node = MergeNodeDef());

    test('metadata', () {
      expect(node.typeId, 'merge');
      expect(node.category, 'Core');
      expect(node.inputs, hasLength(2));
      expect(node.outputs, hasLength(1));
    });

    test('passes through input data', () async {
      final ctx = ExecutionContext(
        nodeId: 'n1',
        inputData: const {'a': 1, 'b': 2},
        params: const {'mode': 'combine'},
      );
      final result = await node.execute(ctx);
      expect(result.isSuccess, isTrue);
      expect(result.outputData['a'], 1);
      expect(result.outputData['b'], 2);
    });
  });

  // ─────────────────────────────────────────────────────────────────────
  // OutputNodeDef
  // ─────────────────────────────────────────────────────────────────────

  group('OutputNodeDef', () {
    late OutputNodeDef node;
    setUp(() => node = OutputNodeDef());

    test('metadata', () {
      expect(node.typeId, 'output');
      expect(node.category, 'Core');
      expect(node.outputs, isEmpty);
      expect(node.inputs, hasLength(1));
    });

    test('passes input data with label', () async {
      final ctx = ExecutionContext(
        nodeId: 'n1',
        inputData: const {'result': 42},
        params: const {'label': 'Final'},
      );
      final result = await node.execute(ctx);
      expect(result.isSuccess, isTrue);
      expect(result.outputData['label'], 'Final');
      expect(result.outputData['result'], 42);
    });

    test('uses default label "Result"', () async {
      final ctx = ExecutionContext(
        nodeId: 'n1',
        inputData: const {},
      );
      final result = await node.execute(ctx);
      expect(result.outputData['label'], 'Result');
    });
  });

  // ─────────────────────────────────────────────────────────────────────
  // TriggerNodeDef
  // ─────────────────────────────────────────────────────────────────────

  group('TriggerNodeDef', () {
    late TriggerNodeDef node;
    setUp(() => node = TriggerNodeDef());

    test('metadata', () {
      expect(node.typeId, 'trigger');
      expect(node.category, 'Core');
      expect(node.isTrigger, isTrue);
      expect(node.inputs, isEmpty);
      expect(node.outputs, hasLength(1));
    });

    test('outputs payload map when payload is a Map', () async {
      final ctx = ExecutionContext(
        nodeId: 'n1',
        params: const {
          'payload': {'greeting': 'hello'},
        },
      );
      final result = await node.execute(ctx);
      expect(result.isSuccess, isTrue);
      expect(result.outputData['greeting'], 'hello');
    });

    test('outputs payload string when payload is a string', () async {
      final ctx = ExecutionContext(
        nodeId: 'n1',
        params: const {'payload': 'start'},
      );
      final result = await node.execute(ctx);
      expect(result.outputData['payload'], 'start');
    });

    test('passes through non-internal params', () async {
      final ctx = ExecutionContext(
        nodeId: 'n1',
        params: const {
          'payload': {},
          'customField': 'customValue',
        },
      );
      final result = await node.execute(ctx);
      expect(result.outputData['customField'], 'customValue');
    });
  });

  // ─────────────────────────────────────────────────────────────────────
  // VariableNodeDef
  // ─────────────────────────────────────────────────────────────────────

  group('VariableNodeDef', () {
    late VariableNodeDef node;
    setUp(() => node = VariableNodeDef());

    test('metadata', () {
      expect(node.typeId, 'variable');
      expect(node.category, 'Flow');
    });

    test('set operation adds variables to data', () async {
      final ctx = ExecutionContext(
        nodeId: 'n1',
        inputData: const {'existing': 'data'},
        params: const {
          'operation': 'set',
          'variables': {'newVar': 'newValue'},
        },
      );
      final result = await node.execute(ctx);
      expect(result.outputData['existing'], 'data');
      expect(result.outputData['newVar'], 'newValue');
    });

    test('get operation returns only matching variables', () async {
      final ctx = ExecutionContext(
        nodeId: 'n1',
        inputData: const {'a': 1, 'b': 2, 'c': 3},
        params: const {
          'operation': 'get',
          'variables': {'a': null, 'c': null},
        },
      );
      final result = await node.execute(ctx);
      expect(result.outputData, {'a': 1, 'c': 3});
    });

    test('setAndGet adds and returns all data', () async {
      final ctx = ExecutionContext(
        nodeId: 'n1',
        inputData: const {'existing': 'data'},
        params: const {
          'operation': 'setAndGet',
          'variables': {'newVar': 'value'},
        },
      );
      final result = await node.execute(ctx);
      expect(result.outputData['existing'], 'data');
      expect(result.outputData['newVar'], 'value');
    });
  });

  // ─────────────────────────────────────────────────────────────────────
  // ErrorHandlerNodeDef
  // ─────────────────────────────────────────────────────────────────────

  group('ErrorHandlerNodeDef', () {
    late ErrorHandlerNodeDef node;
    setUp(() => node = ErrorHandlerNodeDef());

    test('metadata', () {
      expect(node.typeId, 'error_handler');
      expect(node.category, 'Flow');
      expect(node.outputs, hasLength(2));
      expect(node.outputs.map((o) => o.name), containsAll(['success', 'error']));
    });

    test('passes data through when no error', () async {
      final ctx = ExecutionContext(
        nodeId: 'n1',
        inputData: const {'result': 42},
        params: const {'errorField': '_error', 'continueOnError': true},
      );
      final result = await node.execute(ctx);
      expect(result.isSuccess, isTrue);
      expect(result.outputData['result'], 42);
    });

    test('catches error and outputs fallback when continueOnError is true',
        () async {
      final ctx = ExecutionContext(
        nodeId: 'n1',
        inputData: const {'_error': 'Something broke'},
        params: const {
          'errorField': '_error',
          'continueOnError': true,
          'fallbackValue': {'default': 'data'},
        },
      );
      final result = await node.execute(ctx);
      expect(result.isSuccess, isTrue);
      expect(result.outputData['_errorCaught'], isTrue);
      expect(result.outputData['_originalError'], 'Something broke');
      expect(result.outputData['default'], 'data');
    });

    test('returns error result when continueOnError is false', () async {
      final ctx = ExecutionContext(
        nodeId: 'n1',
        inputData: const {'_error': 'Fatal'},
        params: const {
          'errorField': '_error',
          'continueOnError': false,
        },
      );
      final result = await node.execute(ctx);
      expect(result.isError, isTrue);
      expect(result.errorMessage, contains('Fatal'));
    });

    test('no error when field is null', () async {
      final ctx = ExecutionContext(
        nodeId: 'n1',
        inputData: const {'_error': null, 'data': 'ok'},
        params: const {'errorField': '_error'},
      );
      final result = await node.execute(ctx);
      expect(result.isSuccess, isTrue);
      expect(result.outputData['data'], 'ok');
    });
  });
}
