import 'package:flutter_test/flutter_test.dart';

import 'package:flowcraft/engine/execution_context.dart';
import 'package:flowcraft/engine/nodes/condition_node_def.dart';

void main() {
  late ConditionNodeDef node;

  setUp(() {
    node = ConditionNodeDef();
  });

  group('ConditionNodeDef metadata', () {
    test('typeId is "condition"', () => expect(node.typeId, 'condition'));
    test('category is "Core"', () => expect(node.category, 'Core'));
    test('has 2 outputs (true/false)', () {
      expect(node.outputs, hasLength(2));
      expect(node.outputs.map((o) => o.name), containsAll(['true', 'false']));
    });
    test('has 3 params (field, operator, value)', () {
      expect(node.params, hasLength(3));
    });
    test('is NOT a trigger', () => expect(node.isTrigger, isFalse));
  });

  group('execute — exists operator', () {
    test('returns true when field exists', () async {
      final ctx = ExecutionContext(
        nodeId: 'n1',
        inputData: const {'name': 'Alice'},
        params: const {'field': 'name', 'operator': 'exists'},
      );
      final result = await node.execute(ctx);
      expect(result.isSuccess, isTrue);
      expect(result.outputData['_condition'], isTrue);
      expect(result.outputData['_branch'], 'true');
    });

    test('returns false when field is missing', () async {
      final ctx = ExecutionContext(
        nodeId: 'n1',
        inputData: const {},
        params: const {'field': 'name', 'operator': 'exists'},
      );
      final result = await node.execute(ctx);
      expect(result.outputData['_condition'], isFalse);
      expect(result.outputData['_branch'], 'false');
    });
  });

  group('execute — equals operator', () {
    test('returns true when values match', () async {
      final ctx = ExecutionContext(
        nodeId: 'n1',
        inputData: const {'status': 'active'},
        params: const {
          'field': 'status',
          'operator': 'equals',
          'value': 'active',
        },
      );
      final result = await node.execute(ctx);
      expect(result.outputData['_condition'], isTrue);
    });

    test('returns false when values differ', () async {
      final ctx = ExecutionContext(
        nodeId: 'n1',
        inputData: const {'status': 'inactive'},
        params: const {
          'field': 'status',
          'operator': 'equals',
          'value': 'active',
        },
      );
      final result = await node.execute(ctx);
      expect(result.outputData['_condition'], isFalse);
    });
  });

  group('execute — notEquals operator', () {
    test('returns true when values differ', () async {
      final ctx = ExecutionContext(
        nodeId: 'n1',
        inputData: const {'status': 'inactive'},
        params: const {
          'field': 'status',
          'operator': 'notEquals',
          'value': 'active',
        },
      );
      final result = await node.execute(ctx);
      expect(result.outputData['_condition'], isTrue);
    });
  });

  group('execute — contains operator', () {
    test('returns true when string contains substring', () async {
      final ctx = ExecutionContext(
        nodeId: 'n1',
        inputData: const {'text': 'Hello World'},
        params: const {
          'field': 'text',
          'operator': 'contains',
          'value': 'World',
        },
      );
      final result = await node.execute(ctx);
      expect(result.outputData['_condition'], isTrue);
    });

    test('returns false when string does not contain', () async {
      final ctx = ExecutionContext(
        nodeId: 'n1',
        inputData: const {'text': 'Hello'},
        params: const {
          'field': 'text',
          'operator': 'contains',
          'value': 'World',
        },
      );
      final result = await node.execute(ctx);
      expect(result.outputData['_condition'], isFalse);
    });
  });

  group('execute — greaterThan operator', () {
    test('returns true when field is greater', () async {
      final ctx = ExecutionContext(
        nodeId: 'n1',
        inputData: const {'count': 10},
        params: const {
          'field': 'count',
          'operator': 'greaterThan',
          'value': '5',
        },
      );
      final result = await node.execute(ctx);
      expect(result.outputData['_condition'], isTrue);
    });

    test('returns false when field is not greater', () async {
      final ctx = ExecutionContext(
        nodeId: 'n1',
        inputData: const {'count': 3},
        params: const {
          'field': 'count',
          'operator': 'greaterThan',
          'value': '5',
        },
      );
      final result = await node.execute(ctx);
      expect(result.outputData['_condition'], isFalse);
    });
  });

  group('execute — lessThan operator', () {
    test('returns true when field is less', () async {
      final ctx = ExecutionContext(
        nodeId: 'n1',
        inputData: const {'count': 3},
        params: const {
          'field': 'count',
          'operator': 'lessThan',
          'value': '5',
        },
      );
      final result = await node.execute(ctx);
      expect(result.outputData['_condition'], isTrue);
    });
  });

  test('unknown operator returns false', () async {
    final ctx = ExecutionContext(
      nodeId: 'n1',
      inputData: const {'x': 1},
      params: const {
        'field': 'x',
        'operator': 'unknown_op',
        'value': '1',
      },
    );
    final result = await node.execute(ctx);
    expect(result.outputData['_condition'], isFalse);
  });

  test('preserves input data in output', () async {
    final ctx = ExecutionContext(
      nodeId: 'n1',
      inputData: const {'key': 'value'},
      params: const {'field': 'key', 'operator': 'exists'},
    );
    final result = await node.execute(ctx);
    expect(result.outputData['key'], 'value');
  });
}
