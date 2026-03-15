import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flowcraft/flowcraft.dart';
import 'package:flowcraft/canvas/canvas_layer_stack.dart';

void main() {
  Widget buildApp(FlowController controller, {bool miniMap = true, bool controls = true}) {
    return MaterialApp(
      home: Scaffold(
        body: FlowCanvas(
          controller: controller,
          showMiniMap: miniMap,
          showControls: controls,
        ),
      ),
    );
  }

  group('FlowCanvas Widget Tests', () {
    testWidgets('renders empty canvas correctly', (tester) async {
      final controller = FlowController();
      await tester.pumpWidget(buildApp(controller));
      
      expect(find.byType(FlowCanvas), findsOneWidget);
      expect(find.byType(CanvasLayerStack), findsOneWidget);
    });

    testWidgets('renders nodes and edges', (tester) async {
      final controller = FlowController();
      final node1 = controller.addNode(position: const Offset(10, 10), label: 'N1');
      final node2 = controller.addNode(position: const Offset(200, 200), label: 'N2');
      controller.addEdge(
        sourceNodeId: node1.id,
        targetNodeId: node2.id,
        sourceHandleId: node1.handles.first.id, // Assuming it has handles (default nodes do)
        targetHandleId: node2.handles.last.id,
      );

      await tester.pumpWidget(buildApp(controller));
      await tester.pump(const Duration(milliseconds: 100));

      // Nodes are typically rendered via BaseNodeWidget -> DefaultNodeWidget
      expect(find.text('N1'), findsOneWidget);
      expect(find.text('N2'), findsOneWidget);
    });

    testWidgets('handles viewport panning', (tester) async {
      final controller = FlowController();
      controller.addNode(position: const Offset(10, 10), label: 'PanMe');
      
      await tester.pumpWidget(buildApp(controller));
      await tester.pump(const Duration(milliseconds: 100));

      expect(controller.viewport.offset, Offset.zero);

      // Pan the canvas
      final canvasCenter = tester.getCenter(find.byType(FlowCanvas));
      await tester.dragFrom(canvasCenter, const Offset(100, 50));
      await tester.pump(const Duration(milliseconds: 100));

      expect(controller.viewport.offset.dx, 80);
      expect(controller.viewport.offset.dy, 40);
    });

    testWidgets('minimap and controls can be disabled', (tester) async {
      final controller = FlowController();
      await tester.pumpWidget(buildApp(controller, miniMap: false, controls: false));
      // In a real app we'd look for ControlsWidget and MinimapWidget types
      // But we can check they are absent here
      expect(find.byIcon(Icons.add), findsNothing); // Usually controls have zoom in/out icons
    });
  });
}
