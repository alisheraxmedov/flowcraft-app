import 'package:flutter_test/flutter_test.dart';
import 'package:flowcraft/flowcraft.dart';

void main() {
  group('NodeDragHandler', () {
    test('updates position', () {
      final controller = FlowController();
      final node = controller.addNode(position: const Offset(10, 10));
      
      final handler = NodeDragHandler(
        controller: controller,
        nodeId: node.id,
      );

      handler.onDragStart();
      expect(controller.selection.selectedNodeIds.contains(node.id), isTrue);

      handler.onDragUpdate(const Offset(20, 30));
      
      final updatedNode = controller.graph.nodeById(node.id)!;
      // 10 + 20 = 30, 10 + 30 = 40
      expect(updatedNode.position.dx, 30.0);
      expect(updatedNode.position.dy, 40.0);
    });
    
    test('group drag updates all selected nodes', () {
      final controller = FlowController();
      final node1 = controller.addNode(position: const Offset(10, 10));
      final node2 = controller.addNode(position: const Offset(100, 100));
      
      controller.selection.selectNodes({node1.id, node2.id});
      
      final handler = NodeDragHandler(
        controller: controller,
        nodeId: node1.id,
      );

      handler.onGroupDragUpdate(const Offset(10, 10));
      
      expect(controller.graph.nodeById(node1.id)!.position.dx, 20.0);
      expect(controller.graph.nodeById(node2.id)!.position.dx, 110.0);
    });
  });
}
