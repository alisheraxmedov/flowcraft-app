import 'package:flutter_test/flutter_test.dart';

import 'package:flowcraft/engine/execution_result.dart';
import 'package:flowcraft/engine/node_status.dart';
import 'package:flowcraft/engine/workflow_result.dart';

void main() {
  group('WorkflowResult', () {
    test('isSuccess when status is success', () {
      final wr = WorkflowResult(
        nodeResults: const {},
        status: NodeStatus.success,
        duration: Duration.zero,
      );
      expect(wr.isSuccess, isTrue);
      expect(wr.isError, isFalse);
    });

    test('isError when status is error', () {
      final wr = WorkflowResult(
        nodeResults: const {},
        status: NodeStatus.error,
        duration: Duration.zero,
      );
      expect(wr.isError, isTrue);
      expect(wr.isSuccess, isFalse);
    });

    test('outputOf returns output for existing node', () {
      final wr = WorkflowResult(
        nodeResults: {
          'n1': ExecutionResult.success(
            nodeId: 'n1',
            outputData: const {'result': 42},
          ),
        },
        status: NodeStatus.success,
        duration: Duration.zero,
      );
      expect(wr.outputOf('n1'), {'result': 42});
    });

    test('outputOf returns null for missing node', () {
      final wr = WorkflowResult(
        nodeResults: const {},
        status: NodeStatus.success,
        duration: Duration.zero,
      );
      expect(wr.outputOf('missing'), isNull);
    });

    test('errors collects error messages from failed nodes', () {
      final wr = WorkflowResult(
        nodeResults: {
          'n1': ExecutionResult.success(nodeId: 'n1'),
          'n2': ExecutionResult.error(
            nodeId: 'n2',
            message: 'Timeout',
          ),
          'n3': ExecutionResult.error(
            nodeId: 'n3',
            message: 'API error',
          ),
        },
        status: NodeStatus.error,
        duration: const Duration(seconds: 1),
      );

      expect(wr.errors, hasLength(2));
      expect(wr.errors[0], contains('n2'));
      expect(wr.errors[0], contains('Timeout'));
      expect(wr.errors[1], contains('n3'));
      expect(wr.errors[1], contains('API error'));
    });

    test('errors is empty when all nodes succeed', () {
      final wr = WorkflowResult(
        nodeResults: {
          'n1': ExecutionResult.success(nodeId: 'n1'),
        },
        status: NodeStatus.success,
        duration: Duration.zero,
      );
      expect(wr.errors, isEmpty);
    });

    test('duration is stored', () {
      final wr = WorkflowResult(
        nodeResults: const {},
        status: NodeStatus.success,
        duration: const Duration(milliseconds: 500),
      );
      expect(wr.duration, const Duration(milliseconds: 500));
    });
  });
}
