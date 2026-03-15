import 'package:flutter_test/flutter_test.dart';
import 'package:flowcraft/flowcraft.dart';

void main() {
  group('GraphUtils', () {
    test('validateEdge ensures source and target exist', () {
      final graph = FlowGraph(
        nodes: [FlowNode(id: 'n1'), FlowNode(id: 'n2')],
        edges: [],
      );

      expect(GraphUtils.validateEdge(graph, sourceNodeId: 'n1', targetNodeId: 'n2', sourceHandleId: 'h1', targetHandleId: 'h2'), isNull);
      expect(GraphUtils.validateEdge(graph, sourceNodeId: 'n1', targetNodeId: 'n3', sourceHandleId: 'h1', targetHandleId: 'h2'), isNotNull);
    });

    test('validateEdge prevents self-connections', () {
      final graph = FlowGraph(
        nodes: [FlowNode(id: 'n1')],
        edges: [],
      );
      expect(GraphUtils.validateEdge(graph, sourceNodeId: 'n1', targetNodeId: 'n1', sourceHandleId: 'h1', targetHandleId: 'h2'), isNotNull);
    });

    test('validateEdge prevents duplicate edges between same handles', () {
      final graph = FlowGraph(
        nodes: [FlowNode(id: 'n1'), FlowNode(id: 'n2')],
        edges: [
          FlowEdge(sourceNodeId: 'n1', targetNodeId: 'n2', sourceHandleId: 'h1', targetHandleId: 'h2')
        ],
      );
      
      expect(GraphUtils.validateEdge(graph, sourceNodeId: 'n1', targetNodeId: 'n2', sourceHandleId: 'h1', targetHandleId: 'h2'), isNotNull);
      expect(GraphUtils.validateEdge(graph, sourceNodeId: 'n1', targetNodeId: 'n2', sourceHandleId: 'h3', targetHandleId: 'h4'), isNull);
    });
    
    test('removeEdgesForNode returns correctly removed edges and modifies graph', () {
      final graph = FlowGraph(
        nodes: [FlowNode(id: 'n1'), FlowNode(id: 'n2'), FlowNode(id: 'n3'), FlowNode(id: 'n4')],
        edges: [
          FlowEdge(id: 'e1', sourceNodeId: 'n1', targetNodeId: 'n2', sourceHandleId: 'h1', targetHandleId: 'h2'),
          FlowEdge(id: 'e2', sourceNodeId: 'n2', targetNodeId: 'n3', sourceHandleId: 'h1', targetHandleId: 'h2'),
          FlowEdge(id: 'e3', sourceNodeId: 'n3', targetNodeId: 'n4', sourceHandleId: 'h1', targetHandleId: 'h2'),
        ],
      );
      
      final removed = GraphUtils.removeEdgesForNode(graph, 'n2');
      expect(removed.length, 2);
      expect(graph.edges.length, 1);
      expect(graph.edges.first.id, 'e3');
    });
    
    test('wouldCreateCycle logic is correct', () {
      final graph = FlowGraph(
        nodes: [FlowNode(id: 'n1'), FlowNode(id: 'n2'), FlowNode(id: 'n3')],
        edges: [
          FlowEdge(id: 'e1', sourceNodeId: 'n1', targetNodeId: 'n2', sourceHandleId: 'h1', targetHandleId: 'h2'),
          FlowEdge(id: 'e2', sourceNodeId: 'n2', targetNodeId: 'n3', sourceHandleId: 'h1', targetHandleId: 'h2'),
        ],
      );
      
      // We are trying to add an edge from n3 to n1. Does it create a cycle?
      // n1 -> n2 -> n3. Adding n3 -> n1 creates n1 -> n2 -> n3 -> n1
      final isCycle = GraphUtils.wouldCreateCycle(graph, 'n3', 'n1');
      expect(isCycle, isTrue); 
      expect(GraphUtils.wouldCreateCycle(graph, 'n1', 'n3'), isFalse);
    });
  });
}
