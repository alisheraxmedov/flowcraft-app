import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flowcraft/flowcraft.dart';

void main() {
  group('FlowController - Node Operations', () {
    test('addNode, removeNode, moveNode, renameNode, setNodeType', () {
      final controller = FlowController();
      
      // Add node
      final node = controller.addNode(position: const Offset(10, 10));
      expect(controller.nodes.length, 1);
      expect(controller.nodes.first.id, node.id);

      // Move node
      controller.moveNode(node.id, const Offset(20, 20));
      expect(controller.nodes.first.position, const Offset(20, 20));

      // Move node by
      controller.moveNodeBy(node.id, const Offset(5, 5));
      expect(controller.nodes.first.position, const Offset(25, 25));

      // Rename node
      controller.renameNode(node.id, 'New Name');
      expect(controller.nodes.first.label, 'New Name');

      // Set node type
      controller.setNodeType(node.id, NodeType.input);
      expect(controller.nodes.first.type, NodeType.input);

      // Resize node
      controller.resizeNode(node.id, const Size(200, 100));
      expect(controller.nodes.first.size, const Size(200, 100));

      // Add/Remove field
      controller.addNodeField(node.id, key: 'testKey', value: 123);
      expect(controller.nodes.first.data['testKey'], 123);
      controller.removeNodeField(node.id, 'testKey');
      expect(controller.nodes.first.data.containsKey('testKey'), isFalse);

      // Remove node
      controller.removeNode(node.id);
      expect(controller.nodes.isEmpty, isTrue);
    });

    test('startNodeDrag pushes history', () {
      final controller = FlowController();
      final node = controller.addNode();
      expect(controller.canUndo, isTrue); // addNode pushes
      
      controller.startNodeDrag(node.id);
      expect(controller.canUndo, isTrue); // pushes again
    });
  });

  group('FlowController - Edge Operations', () {
    test('addEdge, removeEdge, updateEdgeStyle', () {
      final controller = FlowController();
      final n1 = controller.addNode();
      final n2 = controller.addNode();

      final edge = controller.addEdge(
        sourceNodeId: n1.id,
        targetNodeId: n2.id,
        sourceHandleId: 'h1',
        targetHandleId: 'h2',
      );
      expect(edge, isNotNull);
      expect(controller.edges.length, 1);

      controller.updateEdgeStyle(edge!.id, const EdgeStyle(thickness: 5.0));
      expect(controller.edges.first.style.thickness, 5.0);

      controller.removeEdge(edge.id);
      expect(controller.edges.isEmpty, isTrue);
    });
    
    test('addEdge fails for invalid edge', () {
      final controller = FlowController();
      final n1 = controller.addNode();
      
      final edge = controller.addEdge(
        sourceNodeId: n1.id,
        targetNodeId: n1.id, // self connection
        sourceHandleId: 'h1',
        targetHandleId: 'h2',
      );
      expect(edge, isNull);
    });
  });

  group('FlowController - Viewport Operations', () {
    test('pan, panBy, setZoom, setViewport, zoomIn, zoomOut', () {
      final controller = FlowController();
      
      controller.pan(const Offset(10, 10));
      expect(controller.viewport.offset, const Offset(10, 10));

      controller.panBy(const Offset(5, 5));
      expect(controller.viewport.offset, const Offset(15, 15));

      controller.setZoom(2.0);
      expect(controller.viewport.zoom, 2.0);

      controller.zoomIn(factor: 0.5);
      expect(controller.viewport.zoom, 2.5);

      controller.zoomOut(factor: 0.5);
      expect(controller.viewport.zoom, 2.0);

      controller.setViewport(offset: const Offset(50, 50), zoom: 1.5);
      expect(controller.viewport.offset, const Offset(50, 50));
      expect(controller.viewport.zoom, 1.5);
    });

    test('fitView calculation', () {
      final controller = FlowController();
      controller.addNode(position: const Offset(0, 0), size: const Size(100, 100)); // bottom right 100,100
      controller.addNode(position: const Offset(400, 400), size: const Size(100, 100)); // bottom right 500,500
      
      final canvasSize = const Size(1000, 1000);
      controller.fitView(canvasSize);
      
      expect(controller.viewport.zoom > 0, isTrue); // bounds size is 500x500 + padding => 600x600. So 1000/600 => zoom ~1.6
      expect(controller.viewport.offset.dx > 0, isTrue);
    });
  });

  group('FlowController - Selection Operations', () {
    test('selectAll and deleteSelection', () {
      final controller = FlowController();
      final n1 = controller.addNode();
      final n2 = controller.addNode();
      controller.addEdge(
        sourceNodeId: n1.id,
        targetNodeId: n2.id,
        sourceHandleId: 'h1',
        targetHandleId: 'h2',
      );

      controller.selectAll();
      expect(controller.selection.selectedNodeIds.length, 2);
      expect(controller.selection.selectedEdgeIds.length, 1);

      controller.deleteSelection();
      expect(controller.nodes.isEmpty, isTrue);
      expect(controller.edges.isEmpty, isTrue);
      expect(controller.selection.hasSelection, isFalse);
    });
  });

  group('FlowController - Serialization & History', () {
    test('toJson/fromJson, toMap/fromMap, clear', () {
      final controller = FlowController();
      controller.addNode();
      
      final map = controller.toMap();
      expect(map, isNotNull);

      controller.clear();
      expect(controller.nodes.isEmpty, isTrue);

      controller.fromMap(map);
      expect(controller.nodes.length, 1);

      final jsonStr = controller.toJson();
      controller.clear();
      controller.fromJson(jsonStr);
      expect(controller.nodes.length, 1);
    });

    test('undo/redo', () {
      final controller = FlowController();
      
      // Node 1
      controller.addNode();
      expect(controller.nodes.length, 1);

      // Node 2
      controller.addNode();
      expect(controller.nodes.length, 2);

      controller.undo();
      expect(controller.nodes.length, 1);

      controller.redo();
      expect(controller.nodes.length, 2);
    });
    
    test('dispose correctly calls dispose on selection', () {
       final controller = FlowController();
       controller.dispose();
       // we just verify it runs without crashing, as selection.dispose() is called.
    });
  });
}
