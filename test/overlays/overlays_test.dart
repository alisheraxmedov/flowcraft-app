import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flowcraft/flowcraft.dart';
import 'package:flowcraft/overlays/minimap_widget.dart';
import 'package:flowcraft/overlays/controls_widget.dart';

void main() {
  Widget buildApp(Widget child) {
    return MaterialApp(home: Scaffold(body: child));
  }

  group('Overlays', () {
    testWidgets('MinimapWidget renders nodes correctly', (tester) async {
      final controller = FlowController();
      controller.addNode(position: const Offset(100, 100));
      controller.addNode(position: const Offset(500, 500));
      
      await tester.pumpWidget(buildApp(Stack(children: [
        MinimapWidget(controller: controller)
      ])));
      
      // Minimap uses CustomPaint for nodes
      expect(find.byType(CustomPaint), findsWidgets);
    });

    testWidgets('ControlsWidget renders buttons and triggers zoom', (tester) async {
      final controller = FlowController();
      expect(controller.viewport.zoom, 1.0);
      
      await tester.pumpWidget(buildApp(Stack(children: [
        ControlsWidget(controller: controller)
      ])));
      
      final zoomInBtn = find.text('+');
      final zoomOutBtn = find.text('−');
      final fitViewBtn = find.text('⊡');

      expect(zoomInBtn, findsOneWidget);
      expect(zoomOutBtn, findsOneWidget);
      expect(fitViewBtn, findsOneWidget);

      await tester.tap(zoomInBtn);
      await tester.pump();
      expect(controller.viewport.zoom, greaterThan(1.0));

      await tester.tap(zoomOutBtn);
      await tester.pump();
      // Should be back to 1.0 roughly, or exactly 1.0 (if 1.2 * 0.8)
      expect(controller.viewport.zoom, lessThan(1.2));
    });
  });
}
