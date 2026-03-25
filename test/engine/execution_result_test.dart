import 'package:flutter_test/flutter_test.dart';

import 'package:flowcraft/engine/execution_result.dart';
import 'package:flowcraft/engine/node_status.dart';

void main() {
  group('ExecutionResult', () {
    group('factory constructors', () {
      test('success() sets status to success', () {
        final result = ExecutionResult.success(
          nodeId: 'n1',
          outputData: const {'key': 'value'},
        );

        expect(result.nodeId, 'n1');
        expect(result.status, NodeStatus.success);
        expect(result.isSuccess, isTrue);
        expect(result.isError, isFalse);
        expect(result.outputData, {'key': 'value'});
        expect(result.errorMessage, isNull);
      });

      test('error() sets status to error with message', () {
        final result = ExecutionResult.error(
          nodeId: 'n1',
          message: 'Something broke',
        );

        expect(result.nodeId, 'n1');
        expect(result.status, NodeStatus.error);
        expect(result.isError, isTrue);
        expect(result.isSuccess, isFalse);
        expect(result.errorMessage, 'Something broke');
        expect(result.outputData, isEmpty);
      });

      test('skipped() sets status to skipped', () {
        final result = ExecutionResult.skipped(nodeId: 'n1');

        expect(result.nodeId, 'n1');
        expect(result.status, NodeStatus.skipped);
        expect(result.isSuccess, isFalse);
        expect(result.isError, isFalse);
      });
    });

    test('success defaults to empty outputData', () {
      final result = ExecutionResult.success(nodeId: 'n1');
      expect(result.outputData, isEmpty);
    });

    test('duration defaults to zero', () {
      final result = ExecutionResult.success(nodeId: 'n1');
      expect(result.duration, Duration.zero);
    });

    test('duration can be set', () {
      final result = ExecutionResult.success(
        nodeId: 'n1',
        duration: const Duration(milliseconds: 150),
      );
      expect(result.duration, const Duration(milliseconds: 150));
    });
  });

  group('NodeStatus', () {
    test('has 6 values', () {
      expect(NodeStatus.values.length, 6);
    });

    test('includes idle, queued, running, success, error, skipped', () {
      expect(NodeStatus.values, contains(NodeStatus.idle));
      expect(NodeStatus.values, contains(NodeStatus.queued));
      expect(NodeStatus.values, contains(NodeStatus.running));
      expect(NodeStatus.values, contains(NodeStatus.success));
      expect(NodeStatus.values, contains(NodeStatus.error));
      expect(NodeStatus.values, contains(NodeStatus.skipped));
    });
  });
}
