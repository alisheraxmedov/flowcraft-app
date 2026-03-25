import 'package:flutter_test/flutter_test.dart';

import 'package:flowcraft/engine/execution_context.dart';

void main() {
  group('ExecutionContext', () {
    test('stores nodeId, inputData, params, and credentials', () {
      final ctx = ExecutionContext(
        nodeId: 'n1',
        inputData: const {'key': 'value'},
        params: const {'param1': 'abc'},
        credentials: const {'token': 'secret'},
      );

      expect(ctx.nodeId, 'n1');
      expect(ctx.inputData, {'key': 'value'});
      expect(ctx.params, {'param1': 'abc'});
      expect(ctx.credentials, {'token': 'secret'});
    });

    test('defaults to empty maps', () {
      final ctx = ExecutionContext(nodeId: 'n1');
      expect(ctx.inputData, isEmpty);
      expect(ctx.params, isEmpty);
      expect(ctx.credentials, isEmpty);
    });

    group('getInput', () {
      test('returns typed value when type matches', () {
        final ctx = ExecutionContext(
          nodeId: 'n1',
          inputData: const {'count': 42, 'name': 'test'},
        );

        expect(ctx.getInput<int>('count'), 42);
        expect(ctx.getInput<String>('name'), 'test');
      });

      test('returns null when key is missing', () {
        final ctx = ExecutionContext(nodeId: 'n1');
        expect(ctx.getInput<String>('missing'), isNull);
      });

      test('returns null when type does not match', () {
        final ctx = ExecutionContext(
          nodeId: 'n1',
          inputData: const {'count': 42},
        );
        expect(ctx.getInput<String>('count'), isNull);
      });
    });

    group('getParam', () {
      test('returns typed value when type matches', () {
        final ctx = ExecutionContext(
          nodeId: 'n1',
          params: const {'timeout': 30, 'label': 'hello'},
        );

        expect(ctx.getParam<int>('timeout', 0), 30);
        expect(ctx.getParam<String>('label', ''), 'hello');
      });

      test('returns default when key is missing', () {
        final ctx = ExecutionContext(nodeId: 'n1');
        expect(ctx.getParam<int>('timeout', 99), 99);
        expect(ctx.getParam<String>('label', 'default'), 'default');
      });

      test('returns default when type does not match', () {
        final ctx = ExecutionContext(
          nodeId: 'n1',
          params: const {'timeout': 'not_a_number'},
        );
        expect(ctx.getParam<int>('timeout', 99), 99);
      });
    });

    group('getCredential', () {
      test('returns string credential', () {
        final ctx = ExecutionContext(
          nodeId: 'n1',
          credentials: const {'api_key': 'abc123'},
        );
        expect(ctx.getCredential('api_key'), 'abc123');
      });

      test('returns null when key is missing', () {
        final ctx = ExecutionContext(nodeId: 'n1');
        expect(ctx.getCredential('api_key'), isNull);
      });

      test('returns null when value is not a string', () {
        final ctx = ExecutionContext(
          nodeId: 'n1',
          credentials: const {'api_key': 123},
        );
        expect(ctx.getCredential('api_key'), isNull);
      });
    });
  });
}
