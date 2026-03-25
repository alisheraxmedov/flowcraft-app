import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';

import 'package:flowcraft/core/enums/handle_position.dart';
import 'package:flowcraft/core/enums/node_type.dart';
import 'package:flowcraft/core/models/flow_handle.dart';
import 'package:flowcraft/core/models/flow_node.dart';

void main() {
  group('FlowNode', () {
    group('construction', () {
      test('creates node with default values', () {
        final node = FlowNode(id: 'test1');

        expect(node.id, 'test1');
        expect(node.type, NodeType.defaultNode);
        expect(node.label, 'Node');
        expect(node.position, Offset.zero);
        expect(node.size, const Size(180, 60));
        expect(node.data, isEmpty);
      });

      test('auto-generates id when not provided', () {
        final node = FlowNode();
        expect(node.id, isNotEmpty);
      });

      test('creates 4 default handles when none provided', () {
        final node = FlowNode(id: 'n1');
        expect(node.handles, hasLength(4));

        final positions =
            node.handles.map((h) => h.position).toSet();
        expect(positions, {
          HandlePosition.top,
          HandlePosition.bottom,
          HandlePosition.left,
          HandlePosition.right,
        });
      });

      test('uses custom handles when provided', () {
        final node = FlowNode(
          id: 'n1',
          handles: [
            FlowHandle(
              nodeId: 'n1',
              position: HandlePosition.bottom,
            ),
          ],
        );
        expect(node.handles, hasLength(1));
        expect(node.handles.first.position, HandlePosition.bottom);
      });

      test('data map is mutable', () {
        final node = FlowNode(
          id: 'n1',
          data: {'key': 'value'},
        );
        node.data['new_key'] = 'new_value';
        expect(node.data['new_key'], 'new_value');
      });
    });

    group('computed properties', () {
      test('rect returns Rect from position and size', () {
        final node = FlowNode(
          id: 'n1',
          position: const Offset(10, 20),
          size: const Size(100, 50),
        );

        expect(node.rect, const Rect.fromLTWH(10, 20, 100, 50));
      });

      test('center returns center point', () {
        final node = FlowNode(
          id: 'n1',
          position: const Offset(0, 0),
          size: const Size(100, 50),
        );

        expect(node.center, const Offset(50, 25));
      });
    });

    group('handleById', () {
      test('returns handle when found', () {
        final node = FlowNode(id: 'n1');
        final handle = node.handles.first;
        expect(node.handleById(handle.id), isNotNull);
        expect(node.handleById(handle.id)?.id, handle.id);
      });

      test('returns null when not found', () {
        final node = FlowNode(id: 'n1');
        expect(node.handleById('nonexistent'), isNull);
      });
    });

    group('copyWith', () {
      test('copies all fields', () {
        final original = FlowNode(
          id: 'n1',
          type: NodeType.input,
          label: 'Original',
          position: const Offset(10, 20),
          size: const Size(200, 100),
          data: {'key': 'value'},
        );

        final copy = original.copyWith(
          label: 'Copy',
          position: const Offset(50, 50),
        );

        expect(copy.id, 'n1');
        expect(copy.type, NodeType.input);
        expect(copy.label, 'Copy');
        expect(copy.position, const Offset(50, 50));
        expect(copy.size, const Size(200, 100));
      });

      test('preserves data in copy', () {
        final original = FlowNode(
          id: 'n1',
          data: {'key': 'value'},
        );
        final copy = original.copyWith();
        expect(copy.data['key'], 'value');
      });
    });

    group('equality', () {
      test('nodes with same id are equal', () {
        final a = FlowNode(id: 'n1', label: 'A');
        final b = FlowNode(id: 'n1', label: 'B');
        expect(a, equals(b));
      });

      test('nodes with different id are not equal', () {
        final a = FlowNode(id: 'n1');
        final b = FlowNode(id: 'n2');
        expect(a, isNot(equals(b)));
      });

      test('hashCode is based on id', () {
        final a = FlowNode(id: 'n1');
        final b = FlowNode(id: 'n1');
        expect(a.hashCode, b.hashCode);
      });
    });

    group('serialization', () {
      test('toJson produces expected keys', () {
        final node = FlowNode(
          id: 'n1',
          label: 'Test',
          position: const Offset(10, 20),
          size: const Size(180, 60),
        );

        final json = node.toJson();
        expect(json['id'], 'n1');
        expect(json['label'], 'Test');
        expect(json['type'], 'defaultNode');
        expect(json['position'], {'dx': 10.0, 'dy': 20.0});
        expect(json['size'], {'width': 180.0, 'height': 60.0});
        expect(json['data'], isA<Map>());
        expect(json['handles'], isA<List>());
      });

      test('fromJson round-trip preserves values', () {
        final original = FlowNode(
          id: 'n1',
          type: NodeType.output,
          label: 'Output',
          position: const Offset(100, 200),
          size: const Size(250, 80),
          data: {'key': 'value'},
        );

        final json = original.toJson();
        final restored = FlowNode.fromJson(json);

        expect(restored.id, original.id);
        expect(restored.type, original.type);
        expect(restored.label, original.label);
        expect(restored.position, original.position);
        expect(restored.size, original.size);
        expect(restored.data['key'], 'value');
      });
    });

    test('toString includes id, type, label, and position', () {
      final node = FlowNode(id: 'n1', label: 'Test');
      expect(node.toString(), contains('n1'));
      expect(node.toString(), contains('Test'));
    });
  });
}
