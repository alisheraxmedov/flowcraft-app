import 'package:flutter_test/flutter_test.dart';

import 'package:flowcraft/core/models/edge_style.dart';
import 'package:flowcraft/core/models/flow_edge.dart';

void main() {
  group('FlowEdge', () {
    group('construction', () {
      test('creates edge with required fields', () {
        final edge = FlowEdge(
          id: 'e1',
          sourceNodeId: 'n1',
          targetNodeId: 'n2',
          sourceHandleId: 'h1',
          targetHandleId: 'h2',
        );

        expect(edge.id, 'e1');
        expect(edge.sourceNodeId, 'n1');
        expect(edge.targetNodeId, 'n2');
        expect(edge.sourceHandleId, 'h1');
        expect(edge.targetHandleId, 'h2');
      });

      test('auto-generates id when not provided', () {
        final edge = FlowEdge(
          sourceNodeId: 'n1',
          targetNodeId: 'n2',
          sourceHandleId: 'h1',
          targetHandleId: 'h2',
        );
        expect(edge.id, isNotEmpty);
      });

      test('defaults style to EdgeStyle()', () {
        final edge = FlowEdge(
          sourceNodeId: 'n1',
          targetNodeId: 'n2',
          sourceHandleId: 'h1',
          targetHandleId: 'h2',
        );
        expect(edge.style, isA<EdgeStyle>());
      });
    });

    group('copyWith', () {
      test('copies all fields unchanged', () {
        final edge = FlowEdge(
          id: 'e1',
          sourceNodeId: 'n1',
          targetNodeId: 'n2',
          sourceHandleId: 'h1',
          targetHandleId: 'h2',
        );

        final copy = edge.copyWith();
        expect(copy.id, 'e1');
        expect(copy.sourceNodeId, 'n1');
        expect(copy.targetNodeId, 'n2');
      });

      test('overrides specified fields', () {
        final edge = FlowEdge(
          id: 'e1',
          sourceNodeId: 'n1',
          targetNodeId: 'n2',
          sourceHandleId: 'h1',
          targetHandleId: 'h2',
        );

        final copy = edge.copyWith(
          targetNodeId: 'n3',
          targetHandleId: 'h3',
        );
        expect(copy.targetNodeId, 'n3');
        expect(copy.targetHandleId, 'h3');
        expect(copy.sourceNodeId, 'n1'); // unchanged
      });
    });

    group('equality', () {
      test('edges with same id are equal', () {
        final a = FlowEdge(
          id: 'e1',
          sourceNodeId: 'n1',
          targetNodeId: 'n2',
          sourceHandleId: 'h1',
          targetHandleId: 'h2',
        );
        final b = FlowEdge(
          id: 'e1',
          sourceNodeId: 'n3',
          targetNodeId: 'n4',
          sourceHandleId: 'h3',
          targetHandleId: 'h4',
        );
        expect(a, equals(b));
      });

      test('edges with different id are not equal', () {
        final a = FlowEdge(
          id: 'e1',
          sourceNodeId: 'n1',
          targetNodeId: 'n2',
          sourceHandleId: 'h1',
          targetHandleId: 'h2',
        );
        final b = FlowEdge(
          id: 'e2',
          sourceNodeId: 'n1',
          targetNodeId: 'n2',
          sourceHandleId: 'h1',
          targetHandleId: 'h2',
        );
        expect(a, isNot(equals(b)));
      });

      test('hashCode is based on id', () {
        final a = FlowEdge(
          id: 'e1',
          sourceNodeId: 'n1',
          targetNodeId: 'n2',
          sourceHandleId: 'h1',
          targetHandleId: 'h2',
        );
        final b = FlowEdge(
          id: 'e1',
          sourceNodeId: 'n1',
          targetNodeId: 'n2',
          sourceHandleId: 'h1',
          targetHandleId: 'h2',
        );
        expect(a.hashCode, b.hashCode);
      });
    });

    group('serialization', () {
      test('toJson produces expected keys', () {
        final edge = FlowEdge(
          id: 'e1',
          sourceNodeId: 'n1',
          targetNodeId: 'n2',
          sourceHandleId: 'h1',
          targetHandleId: 'h2',
        );

        final json = edge.toJson();
        expect(json['id'], 'e1');
        expect(json['sourceNodeId'], 'n1');
        expect(json['targetNodeId'], 'n2');
        expect(json['sourceHandleId'], 'h1');
        expect(json['targetHandleId'], 'h2');
        expect(json['style'], isA<Map>());
      });

      test('fromJson round-trip preserves values', () {
        final original = FlowEdge(
          id: 'e1',
          sourceNodeId: 'n1',
          targetNodeId: 'n2',
          sourceHandleId: 'h1',
          targetHandleId: 'h2',
        );

        final json = original.toJson();
        final restored = FlowEdge.fromJson(json);

        expect(restored.id, original.id);
        expect(restored.sourceNodeId, original.sourceNodeId);
        expect(restored.targetNodeId, original.targetNodeId);
        expect(restored.sourceHandleId, original.sourceHandleId);
        expect(restored.targetHandleId, original.targetHandleId);
      });
    });

    test('toString includes id, sourceNodeId, targetNodeId', () {
      final edge = FlowEdge(
        id: 'e1',
        sourceNodeId: 'n1',
        targetNodeId: 'n2',
        sourceHandleId: 'h1',
        targetHandleId: 'h2',
      );
      expect(edge.toString(), contains('e1'));
      expect(edge.toString(), contains('n1'));
      expect(edge.toString(), contains('n2'));
    });
  });
}
