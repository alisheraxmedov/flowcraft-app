import 'package:flutter_test/flutter_test.dart';

import 'package:flowcraft/engine/execution_context.dart';
import 'package:flowcraft/engine/nodes/transform_node_def.dart';

void main() {
  late TransformNodeDef node;

  setUp(() {
    node = TransformNodeDef();
  });

  group('TransformNodeDef metadata', () {
    test('typeId is "transform"', () => expect(node.typeId, 'transform'));
    test('category is "Core"', () => expect(node.category, 'Core'));
    test('has 4 operations', () {
      final param = node.params.firstWhere((p) => p.name == 'operation');
      expect(param.options, ['set', 'rename', 'remove', 'keep']);
    });
  });

  group('execute — set operation', () {
    test('adds new fields', () async {
      final ctx = ExecutionContext(
        nodeId: 'n1',
        inputData: const {'a': 1},
        params: const {
          'operation': 'set',
          'fields': {'b': 2, 'c': 3},
        },
      );
      final result = await node.execute(ctx);
      expect(result.isSuccess, isTrue);
      expect(result.outputData['a'], 1);
      expect(result.outputData['b'], 2);
      expect(result.outputData['c'], 3);
    });

    test('overwrites existing fields', () async {
      final ctx = ExecutionContext(
        nodeId: 'n1',
        inputData: const {'a': 1},
        params: const {
          'operation': 'set',
          'fields': {'a': 99},
        },
      );
      final result = await node.execute(ctx);
      expect(result.outputData['a'], 99);
    });
  });

  group('execute — rename operation', () {
    test('renames fields', () async {
      final ctx = ExecutionContext(
        nodeId: 'n1',
        inputData: const {'oldName': 'value'},
        params: const {
          'operation': 'rename',
          'fields': {'oldName': 'newName'},
        },
      );
      final result = await node.execute(ctx);
      expect(result.outputData.containsKey('oldName'), isFalse);
      expect(result.outputData['newName'], 'value');
    });

    test('ignores non-existent fields in rename', () async {
      final ctx = ExecutionContext(
        nodeId: 'n1',
        inputData: const {'a': 1},
        params: const {
          'operation': 'rename',
          'fields': {'missing': 'newMissing'},
        },
      );
      final result = await node.execute(ctx);
      expect(result.outputData['a'], 1);
      expect(result.outputData.containsKey('newMissing'), isFalse);
    });
  });

  group('execute — remove operation', () {
    test('removes specified fields', () async {
      final ctx = ExecutionContext(
        nodeId: 'n1',
        inputData: const {'a': 1, 'b': 2, 'c': 3},
        params: const {
          'operation': 'remove',
          'fields': {'a': null, 'c': null},
        },
      );
      final result = await node.execute(ctx);
      expect(result.outputData, {'b': 2});
    });
  });

  group('execute — keep operation', () {
    test('keeps only specified fields', () async {
      final ctx = ExecutionContext(
        nodeId: 'n1',
        inputData: const {'a': 1, 'b': 2, 'c': 3},
        params: const {
          'operation': 'keep',
          'fields': {'a': null, 'c': null},
        },
      );
      final result = await node.execute(ctx);
      expect(result.outputData, {'a': 1, 'c': 3});
    });
  });
}
