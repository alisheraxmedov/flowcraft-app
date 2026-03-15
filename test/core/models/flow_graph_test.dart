import 'package:flutter_test/flutter_test.dart';
import 'package:flowcraft/flowcraft.dart';

void main() {
  group('FlowGraph', () {
    test('add/remove nodes and edges', () {
      final graph = FlowGraph(nodes: [], edges: []);
      final node = FlowNode(id: 'n1', label: 'Node 1');
      graph.nodes.add(node);
      
      expect(graph.nodeById('n1'), node);
      expect(graph.nodeById('n2'), isNull);

      final edge = FlowEdge(sourceNodeId: 'n1', targetNodeId: 'n2', sourceHandleId: 'h1', targetHandleId: 'h2', id: 'e1');
      graph.edges.add(edge);

      expect(graph.edgeById('e1'), edge);
      expect(graph.edgeById('e2'), isNull);
    });

    test('toJson and fromJson', () {
      final graph = FlowGraph(
        nodes: [FlowNode(id: 'n1', label: 'N1')],
        edges: [FlowEdge(id: 'e1', sourceNodeId: 'n1', targetNodeId: 'n1', sourceHandleId: 'h1', targetHandleId: 'h2')],
      );

      final json = graph.toJson();
      final restored = FlowGraph.fromJson(json);

      expect(restored.nodes.length, 1);
      expect(restored.nodes.first.id, 'n1');
      expect(restored.edges.length, 1);
      expect(restored.edges.first.id, 'e1');
    });

    test('copyWith works', () {
      final graph = FlowGraph(nodes: [], edges: []);
      final copied = graph.copyWith(
        nodes: [FlowNode(id: 'nx', label: 'X')],
      );

      expect(copied.nodes.length, 1);
      expect(copied.edges.length, 0);
    });

    test('toString returns properly formatted string', () {
      final graph = FlowGraph(
        nodes: [FlowNode(id: 'n1', label: 'N1')],
        edges: [FlowEdge(id: 'e1', sourceNodeId: 'n1', targetNodeId: 'n1', sourceHandleId: 'h1', targetHandleId: 'h2')],
      );
      final str = graph.toString();
      expect(str, contains('FlowGraph(nodes: 1, edges: 1)'));
    });
  });
}
