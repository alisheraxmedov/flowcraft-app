import 'package:flutter_test/flutter_test.dart';
import 'package:flowcraft/flowcraft.dart';

void main() {
  group('Serializer', () {
    test('serialize and deserialize to/from Map', () {
      final graph = FlowGraph(
        nodes: [FlowNode(id: 'n1', label: 'Node 1')],
        edges: [FlowEdge(id: 'e1', sourceNodeId: 'n1', targetNodeId: 'n1', sourceHandleId: 'h1', targetHandleId: 'h2')],
      );
      const viewport = FlowViewport(offset: Offset(10, 20), zoom: 2.0);

      final map = Serializer.toMap(graph: graph, viewport: viewport);
      expect(map['version'], 1);
      expect(map['graph'], isNotNull);
      expect(map['viewport'], isNotNull);

      final restored = Serializer.fromMap(map);
      expect(restored.graph.nodes.length, 1);
      expect(restored.graph.edges.length, 1);
      expect(restored.viewport.zoom, 2.0);
    });

    test('serialize and deserialize to/from String', () {
       final graph = FlowGraph(nodes: [], edges: []);
       const viewport = FlowViewport();

       final jsonStr = Serializer.serialize(graph: graph, viewport: viewport);
       expect(jsonStr, isA<String>());

       final restored = Serializer.deserialize(jsonStr);
       expect(restored.graph.nodes.isEmpty, isTrue);
       expect(restored.viewport.offset, Offset.zero);
    });
  });
}
