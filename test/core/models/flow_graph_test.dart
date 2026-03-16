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

  group('FlowGraph - Index Operations', () {
    test('constructor builds indexes from initial nodes and edges', () {
      final node1 = FlowNode(id: 'n1', label: 'Node 1');
      final node2 = FlowNode(id: 'n2', label: 'Node 2');
      final edge = FlowEdge(
        id: 'e1',
        sourceNodeId: 'n1',
        targetNodeId: 'n2',
        sourceHandleId: 'h1',
        targetHandleId: 'h2',
      );

      final graph = FlowGraph(nodes: [node1, node2], edges: [edge]);

      expect(graph.nodeById('n1'), node1);
      expect(graph.nodeById('n2'), node2);
      expect(graph.edgeById('e1'), edge);
    });

    test('indexNode registers a node for O(1) lookup', () {
      final graph = FlowGraph();
      final node = FlowNode(id: 'idx1', label: 'Indexed');

      graph.nodes.add(node);
      graph.indexNode(node);

      expect(graph.nodeById('idx1'), node);
    });

    test('unindexNode removes a node from the index', () {
      final node = FlowNode(id: 'rm1', label: 'To Remove');
      final graph = FlowGraph(nodes: [node]);

      expect(graph.nodeById('rm1'), node);

      graph.unindexNode('rm1');
      graph.nodes.removeWhere((n) => n.id == 'rm1');

      expect(graph.nodeById('rm1'), isNull);
    });

    test('indexEdge registers an edge for O(1) lookup', () {
      final graph = FlowGraph();
      final edge = FlowEdge(
        id: 'eidx1',
        sourceNodeId: 'n1',
        targetNodeId: 'n2',
        sourceHandleId: 'h1',
        targetHandleId: 'h2',
      );

      graph.edges.add(edge);
      graph.indexEdge(edge);

      expect(graph.edgeById('eidx1'), edge);
    });

    test('unindexEdge removes an edge from the index', () {
      final edge = FlowEdge(
        id: 'erm1',
        sourceNodeId: 'n1',
        targetNodeId: 'n2',
        sourceHandleId: 'h1',
        targetHandleId: 'h2',
      );
      final graph = FlowGraph(edges: [edge]);

      expect(graph.edgeById('erm1'), edge);

      graph.unindexEdge('erm1');
      graph.edges.removeWhere((e) => e.id == 'erm1');

      expect(graph.edgeById('erm1'), isNull);
    });

    test('nodeById falls back to linear scan for items added without indexing', () {
      final graph = FlowGraph();
      final node = FlowNode(id: 'fallback1', label: 'Fallback');
      graph.nodes.add(node);

      expect(graph.nodeById('fallback1'), node);
    });

    test('edgeById falls back to linear scan for items added without indexing', () {
      final graph = FlowGraph();
      final edge = FlowEdge(
        id: 'efallback1',
        sourceNodeId: 'n1',
        targetNodeId: 'n2',
        sourceHandleId: 'h1',
        targetHandleId: 'h2',
      );
      graph.edges.add(edge);

      expect(graph.edgeById('efallback1'), edge);
    });

    test('nodeById auto-indexes on fallback hit for subsequent O(1) access', () {
      final graph = FlowGraph();
      final node = FlowNode(id: 'auto_idx', label: 'Auto Index');
      graph.nodes.add(node);

      // First access uses fallback scan and auto-indexes
      final first = graph.nodeById('auto_idx');
      expect(first, node);

      // Second access should be O(1) from the index
      final second = graph.nodeById('auto_idx');
      expect(second, node);
      expect(identical(first, second), isTrue);
    });

    test('copyWith preserves index in new graph', () {
      final node = FlowNode(id: 'cp1', label: 'Copy');
      final edge = FlowEdge(
        id: 'ecp1',
        sourceNodeId: 'cp1',
        targetNodeId: 'cp1',
        sourceHandleId: 'h1',
        targetHandleId: 'h2',
      );
      final original = FlowGraph(nodes: [node], edges: [edge]);
      final copy = original.copyWith();

      expect(copy.nodeById('cp1'), isNotNull);
      expect(copy.nodeById('cp1')!.label, 'Copy');
      expect(copy.edgeById('ecp1'), isNotNull);
    });

    test('fromJson rebuilds indexes correctly', () {
      final original = FlowGraph(
        nodes: [FlowNode(id: 'js1', label: 'JSON')],
        edges: [
          FlowEdge(
            id: 'ejs1',
            sourceNodeId: 'js1',
            targetNodeId: 'js1',
            sourceHandleId: 'h1',
            targetHandleId: 'h2',
          ),
        ],
      );

      final json = original.toJson();
      final restored = FlowGraph.fromJson(json);

      expect(restored.nodeById('js1'), isNotNull);
      expect(restored.nodeById('js1')!.label, 'JSON');
      expect(restored.edgeById('ejs1'), isNotNull);
    });

    test('nodeById returns null for non-existent ID', () {
      final graph = FlowGraph(
        nodes: [FlowNode(id: 'exists', label: 'Here')],
      );
      expect(graph.nodeById('does_not_exist'), isNull);
    });

    test('edgeById returns null for non-existent ID', () {
      final graph = FlowGraph(
        edges: [
          FlowEdge(
            id: 'exists',
            sourceNodeId: 'n1',
            targetNodeId: 'n2',
            sourceHandleId: 'h1',
            targetHandleId: 'h2',
          ),
        ],
      );
      expect(graph.edgeById('does_not_exist'), isNull);
    });
  });
}
