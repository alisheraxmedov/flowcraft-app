import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flowcraft/flowcraft.dart';

void main() {
  group('FlowController - Node Operations', () {
    test('addNode, removeNode, moveNode, renameNode, setNodeType', () {
      final controller = FlowController();

      final node = controller.addNode(position: const Offset(10, 10));
      expect(controller.nodes.length, 1);
      expect(controller.nodes.first.id, node.id);

      controller.moveNode(node.id, const Offset(20, 20));
      expect(controller.nodes.first.position, const Offset(20, 20));

      controller.moveNodeBy(node.id, const Offset(5, 5));
      expect(controller.nodes.first.position, const Offset(25, 25));

      controller.renameNode(node.id, 'New Name');
      expect(controller.nodes.first.label, 'New Name');

      controller.setNodeType(node.id, NodeType.input);
      expect(controller.nodes.first.type, NodeType.input);

      controller.resizeNode(node.id, const Size(200, 100));
      expect(controller.nodes.first.size, const Size(200, 100));

      controller.addNodeField(node.id, key: 'testKey', value: 123);
      expect(controller.nodes.first.data['testKey'], 123);
      controller.removeNodeField(node.id, 'testKey');
      expect(controller.nodes.first.data.containsKey('testKey'), isFalse);

      controller.removeNode(node.id);
      expect(controller.nodes.isEmpty, isTrue);
    });

    test('startNodeDrag pushes history', () {
      final controller = FlowController();
      final node = controller.addNode();
      expect(controller.canUndo, isTrue);

      controller.startNodeDrag(node.id);
      expect(controller.canUndo, isTrue);
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

    test('addEdge fails for self-connection', () {
      final controller = FlowController();
      final n1 = controller.addNode();

      final edge = controller.addEdge(
        sourceNodeId: n1.id,
        targetNodeId: n1.id,
        sourceHandleId: 'h1',
        targetHandleId: 'h2',
      );
      expect(edge, isNull);
    });

    test('addEdge auto-assigns different colors from palette', () {
      final controller = FlowController();
      final n1 = controller.addNode();
      final n2 = controller.addNode();
      final n3 = controller.addNode();

      final edge1 = controller.addEdge(
        sourceNodeId: n1.id,
        targetNodeId: n2.id,
        sourceHandleId: n1.handles.first.id,
        targetHandleId: n2.handles.first.id,
      );
      final edge2 = controller.addEdge(
        sourceNodeId: n2.id,
        targetNodeId: n3.id,
        sourceHandleId: n2.handles[1].id,
        targetHandleId: n3.handles.first.id,
      );

      expect(edge1, isNotNull);
      expect(edge2, isNotNull);
      expect(edge1!.style.color, isNot(edge2!.style.color));
    });

    test('addEdge auto-assigned edges are animated by default', () {
      final controller = FlowController();
      final n1 = controller.addNode();
      final n2 = controller.addNode();

      final edge = controller.addEdge(
        sourceNodeId: n1.id,
        targetNodeId: n2.id,
        sourceHandleId: n1.handles.first.id,
        targetHandleId: n2.handles.first.id,
      );

      expect(edge, isNotNull);
      expect(edge!.style.animated, isTrue);
    });

    test('addEdge uses custom style when provided', () {
      final controller = FlowController();
      final n1 = controller.addNode();
      final n2 = controller.addNode();

      const customStyle = EdgeStyle(
        color: Color(0xFFFF0000),
        animated: false,
        thickness: 4.0,
      );

      final edge = controller.addEdge(
        sourceNodeId: n1.id,
        targetNodeId: n2.id,
        sourceHandleId: n1.handles.first.id,
        targetHandleId: n2.handles.first.id,
        style: customStyle,
      );

      expect(edge, isNotNull);
      expect(edge!.style.color, const Color(0xFFFF0000));
      expect(edge.style.animated, false);
      expect(edge.style.thickness, 4.0);
    });
  });

  group('FlowController - Viewport', () {
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
      controller.addNode(position: const Offset(0, 0), size: const Size(100, 100));
      controller.addNode(position: const Offset(400, 400), size: const Size(100, 100));

      const canvasSize = Size(1000, 1000);
      controller.fitView(canvasSize);

      expect(controller.viewport.zoom > 0, isTrue);
      expect(controller.viewport.offset.dx > 0, isTrue);
    });
  });

  group('FlowController - Selection', () {
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
      controller.addNode();
      expect(controller.nodes.length, 1);

      controller.addNode();
      expect(controller.nodes.length, 2);

      controller.undo();
      expect(controller.nodes.length, 1);

      controller.redo();
      expect(controller.nodes.length, 2);
    });

    test('dispose correctly', () {
       final controller = FlowController();
       controller.dispose();
    });
  });

  group('FlowController - Snap to Grid', () {
    test('constructor accepts snapToGrid and gridSnap', () {
      final controller = FlowController(snapToGrid: true, gridSnap: 25.0);
      expect(controller.snapToGrid, isTrue);
      expect(controller.gridSnap, 25.0);
    });

    test('defaults to snapToGrid=false, gridSnap=20', () {
      final controller = FlowController();
      expect(controller.snapToGrid, isFalse);
      expect(controller.gridSnap, 20.0);
    });

    test('moveNode snaps when enabled', () {
      final controller = FlowController(snapToGrid: true, gridSnap: 20.0);
      final node = controller.addNode(position: const Offset(0, 0));

      controller.moveNode(node.id, const Offset(33, 47));
      expect(controller.nodes.first.position, const Offset(40, 40));
    });

    test('moveNode does not snap when disabled', () {
      final controller = FlowController(snapToGrid: false);
      final node = controller.addNode(position: const Offset(0, 0));

      controller.moveNode(node.id, const Offset(33, 47));
      expect(controller.nodes.first.position, const Offset(33, 47));
    });

    test('moveNodeBy snaps when enabled', () {
      final controller = FlowController(snapToGrid: true, gridSnap: 20.0);
      final node = controller.addNode(position: const Offset(0, 0));

      controller.moveNodeBy(node.id, const Offset(13, 13));
      expect(controller.nodes.first.position, const Offset(20, 20));
    });

    test('moveNodeBy does not snap when disabled', () {
      final controller = FlowController(snapToGrid: false);
      final node = controller.addNode(position: const Offset(0, 0));

      controller.moveNodeBy(node.id, const Offset(13, 13));
      expect(controller.nodes.first.position, const Offset(13, 13));
    });

    test('snapToGrid toggled at runtime', () {
      final controller = FlowController();
      final node = controller.addNode(position: const Offset(0, 0));

      controller.moveNode(node.id, const Offset(33, 47));
      expect(controller.nodes.first.position, const Offset(33, 47));

      controller.snapToGrid = true;
      controller.moveNode(node.id, const Offset(33, 47));
      expect(controller.nodes.first.position, const Offset(40, 40));

      controller.gridSnap = 10.0;
      controller.moveNode(node.id, const Offset(33, 47));
      expect(controller.nodes.first.position, const Offset(30, 50));
    });

    test('snap rounds to nearest grid point', () {
      final controller = FlowController(snapToGrid: true, gridSnap: 20.0);
      final node = controller.addNode(position: const Offset(0, 0));

      controller.moveNode(node.id, const Offset(10, 10));
      expect(controller.nodes.first.position, const Offset(20, 20));

      controller.moveNode(node.id, const Offset(9, 9));
      expect(controller.nodes.first.position, const Offset(0, 0));
    });
  });

  group('FlowController - Copy and Paste', () {
    test('copy and paste selected nodes', () {
      final controller = FlowController();
      final n1 = controller.addNode(label: 'A', position: const Offset(10, 10));
      controller.addNode(label: 'B', position: const Offset(200, 200));

      controller.selection.selectNode(n1.id);
      controller.copySelectedNodes();
      controller.pasteNodes();

      expect(controller.nodes.length, 3);
      final pasted = controller.nodes.last;
      expect(pasted.label, 'A (copy)');
      expect(pasted.position, const Offset(40, 40));
      expect(pasted.id, isNot(n1.id));
    });

    test('paste does nothing with empty clipboard', () {
      final controller = FlowController();
      controller.addNode(label: 'X');
      controller.pasteNodes();
      expect(controller.nodes.length, 1);
    });

    test('paste selects the pasted nodes', () {
      final controller = FlowController();
      final n1 = controller.addNode(label: 'Original');

      controller.selection.selectNode(n1.id);
      controller.copySelectedNodes();
      controller.pasteNodes();

      expect(controller.selection.selectedNodeIds.contains(n1.id), isFalse);
      expect(controller.selection.selectedNodeIds.contains(controller.nodes.last.id), isTrue);
    });

    test('copy and paste multiple nodes', () {
      final controller = FlowController();
      final n1 = controller.addNode(label: 'First');
      final n2 = controller.addNode(label: 'Second');

      controller.selection.selectNodes({n1.id, n2.id});
      controller.copySelectedNodes();
      controller.pasteNodes();

      expect(controller.nodes.length, 4);
    });

    test('paste preserves data fields', () {
      final controller = FlowController();
      final n1 = controller.addNode(
        label: 'With Data',
        data: {'key1': 'val1', 'key2': 42},
      );

      controller.selection.selectNode(n1.id);
      controller.copySelectedNodes();
      controller.pasteNodes();

      final pasted = controller.nodes.last;
      expect(pasted.data['key1'], 'val1');
      expect(pasted.data['key2'], 42);
    });

    test('paste pushes history for undo', () {
      final controller = FlowController();
      final n1 = controller.addNode(label: 'A');

      controller.selection.selectNode(n1.id);
      controller.copySelectedNodes();
      controller.pasteNodes();
      expect(controller.nodes.length, 2);

      controller.undo();
      expect(controller.nodes.length, 1);
    });
  });
}
