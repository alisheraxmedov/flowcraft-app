import 'package:flutter_test/flutter_test.dart';
import 'package:flowcraft/flowcraft.dart';

void main() {
  group('FlowNode', () {
    test('creates node with default values', () {
      final node = FlowNode();
      expect(node.label, 'Node');
      expect(node.type, NodeType.defaultNode);
      expect(node.handles.length, 4);
    });

    test('toJson/fromJson round-trip', () {
      final node = FlowNode(
        label: 'Test Node',
        position: const Offset(100, 200),
        data: {'key': 'value'},
      );
      final json = node.toJson();
      final restored = FlowNode.fromJson(json);
      expect(restored.label, 'Test Node');
      expect(restored.position.dx, 100);
      expect(restored.position.dy, 200);
      expect(restored.data['key'], 'value');
    });
  });

  group('FlowEdge', () {
    test('creates edge with source and target', () {
      final edge = FlowEdge(
        sourceNodeId: 'node_1',
        targetNodeId: 'node_2',
        sourceHandleId: 'handle_1',
        targetHandleId: 'handle_2',
      );
      expect(edge.sourceNodeId, 'node_1');
      expect(edge.targetNodeId, 'node_2');
    });

    test('toJson/fromJson round-trip', () {
      final edge = FlowEdge(
        sourceNodeId: 'n1',
        targetNodeId: 'n2',
        sourceHandleId: 'h1',
        targetHandleId: 'h2',
        style: const EdgeStyle(animated: true, dashPattern: [8, 4]),
      );
      final json = edge.toJson();
      final restored = FlowEdge.fromJson(json);
      expect(restored.sourceNodeId, 'n1');
      expect(restored.style.animated, true);
      expect(restored.style.dashPattern, [8, 4]);
    });
  });

  group('FlowController', () {
    test('addNode and removeNode', () {
      final controller = FlowController();
      final node = controller.addNode(label: 'A');
      expect(controller.nodes.length, 1);
      controller.removeNode(node.id);
      expect(controller.nodes.length, 0);
    });

    test('undo and redo', () {
      final controller = FlowController();
      controller.addNode(label: 'A');
      expect(controller.nodes.length, 1);
      controller.undo();
      expect(controller.nodes.length, 0);
      controller.redo();
      expect(controller.nodes.length, 1);
    });

    test('addEdge with validation', () {
      final controller = FlowController();
      final n1 = controller.addNode(label: 'Source');
      final n2 = controller.addNode(label: 'Target');
      final edge = controller.addEdge(
        sourceNodeId: n1.id,
        targetNodeId: n2.id,
        sourceHandleId: n1.handles.first.id,
        targetHandleId: n2.handles.first.id,
      );
      expect(edge, isNotNull);
      expect(controller.edges.length, 1);
    });

    test('self-connection is rejected', () {
      final controller = FlowController();
      final n1 = controller.addNode(label: 'Self');
      final edge = controller.addEdge(
        sourceNodeId: n1.id,
        targetNodeId: n1.id,
        sourceHandleId: n1.handles[0].id,
        targetHandleId: n1.handles[1].id,
      );
      expect(edge, isNull);
    });

    test('serialization round-trip', () {
      final controller = FlowController();
      controller.addNode(label: 'X', position: const Offset(50, 50));
      final json = controller.toJson();
      final controller2 = FlowController();
      controller2.fromJson(json);
      expect(controller2.nodes.length, 1);
      expect(controller2.nodes.first.label, 'X');
    });
  });
}
