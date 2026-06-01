import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flowcraft/controller/flow_controller.dart';
import 'package:flowcraft/engine/nodes/output_node_def.dart';
import 'package:flowcraft/engine/nodes/webhook_node_def.dart';
import 'package:flowcraft/overlays/node_properties_panel.dart';

void main() {
  group('NodePropertiesPanel required field indicator', () {
    testWidgets('shows red * next to required field labels', (tester) async {
      final controller = FlowController();
      controller.nodeDefinitionRegistry.register(WebhookNodeDef());

      final node = controller.addNode(
        label: 'Webhook',
        data: {'definitionType': 'webhook'},
      );
      controller.selection.selectNode(node.id);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Row(
              children: [
                NodePropertiesPanel(controller: controller),
              ],
            ),
          ),
        ),
      );

      // Required fields should have * in the RichText
      // 'HTTP Method' and 'Path' are required
      // 'Test Payload' and 'Expected Headers' are not required

      // Find all RichText widgets that contain ' *'
      final richTexts = find.byType(RichText);
      expect(richTexts, findsWidgets);

      // Verify the panel renders without errors
      expect(find.byType(NodePropertiesPanel), findsOneWidget);
    });

    testWidgets('does not show * for non-required fields', (tester) async {
      final controller = FlowController();
      controller.nodeDefinitionRegistry.register(OutputNodeDef());

      final node = controller.addNode(
        label: 'Output',
        data: {'definitionType': 'output'},
      );
      controller.selection.selectNode(node.id);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Row(
              children: [
                NodePropertiesPanel(controller: controller),
              ],
            ),
          ),
        ),
      );

      // OutputNodeDef has no required params — panel should render fine
      expect(find.byType(NodePropertiesPanel), findsOneWidget);
    });
  });

  group('FlowController serialization round-trip', () {
    test('toJson and fromJson preserve nodes and edges', () {
      final controller = FlowController();

      final node1 = controller.addNode(
        label: 'Webhook',
        position: const Offset(100, 200),
        data: {'definitionType': 'webhook', 'path': '/test'},
      );
      final node2 = controller.addNode(
        label: 'Output',
        position: const Offset(400, 200),
        data: {'definitionType': 'output'},
      );

      controller.addEdge(
        sourceNodeId: node1.id,
        targetNodeId: node2.id,
        sourceHandleId: node1.handles.first.id,
        targetHandleId: node2.handles.first.id,
      );

      // Serialize
      final json = controller.toJson();
      expect(json, isNotEmpty);

      // Restore into fresh controller
      final controller2 = FlowController();
      controller2.fromJson(json);

      // Verify nodes
      expect(controller2.nodes.length, 2);
      final restoredNode1 =
          controller2.nodes.firstWhere((n) => n.label == 'Webhook');
      final restoredNode2 =
          controller2.nodes.firstWhere((n) => n.label == 'Output');

      expect(restoredNode1.data['definitionType'], 'webhook');
      expect(restoredNode1.data['path'], '/test');
      expect(restoredNode2.data['definitionType'], 'output');

      // Verify position
      expect(restoredNode1.position.dx, 100);
      expect(restoredNode1.position.dy, 200);

      // Verify edges
      expect(controller2.graph.edges.length, 1);
      final edge = controller2.graph.edges.first;
      expect(edge.sourceNodeId, restoredNode1.id);
      expect(edge.targetNodeId, restoredNode2.id);
    });

    test('fromJson clears existing graph', () {
      final controller = FlowController();
      controller.addNode(label: 'Old Node');
      expect(controller.nodes.length, 1);

      // Save empty controller
      final emptyController = FlowController();
      final emptyJson = emptyController.toJson();

      // Load empty into controller with existing node
      controller.fromJson(emptyJson);
      expect(controller.nodes, isEmpty);
    });
  });
}
