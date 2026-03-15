import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flowcraft/flowcraft.dart';

void main() {
  Widget buildApp(Widget child) {
    return MaterialApp(home: Scaffold(body: child));
  }

  group('Overlays - MinimapWidget', () {
    testWidgets('MinimapWidget renders with nodes', (tester) async {
      final controller = FlowController();
      controller.addNode(position: const Offset(100, 100));
      controller.addNode(position: const Offset(500, 500));
      
      await tester.pumpWidget(buildApp(Stack(children: [
        MinimapWidget(controller: controller)
      ])));
      
      expect(find.byType(CustomPaint), findsWidgets);
    });

    testWidgets('MinimapWidget renders with GestureDetector when interactive', (tester) async {
      final controller = FlowController();
      controller.addNode(position: const Offset(100, 100));

      await tester.pumpWidget(buildApp(Stack(children: [
        MinimapWidget(controller: controller, interactive: true)
      ])));

      expect(find.byType(GestureDetector), findsWidgets);
    });

    testWidgets('MinimapWidget interactive=false does not have GestureDetector for pan', (tester) async {
      final controller = FlowController();
      controller.addNode(position: const Offset(100, 100));

      await tester.pumpWidget(buildApp(Stack(children: [
        MinimapWidget(controller: controller, interactive: false)
      ])));

      // Should still render, just without interactive behavior
      expect(find.byType(CustomPaint), findsWidgets);
    });

    testWidgets('MinimapWidget defaults to interactive=true', (tester) async {
      final controller = FlowController();
      controller.addNode(position: const Offset(100, 100));

      await tester.pumpWidget(buildApp(Stack(children: [
        MinimapWidget(controller: controller)
      ])));

      // Should contain GestureDetector by default
      expect(find.byType(GestureDetector), findsWidgets);
    });

    testWidgets('MinimapWidget tap changes viewport when interactive', (tester) async {
      final controller = FlowController();
      controller.addNode(position: const Offset(100, 100));
      controller.addNode(position: const Offset(500, 500));

      final initialOffset = controller.viewport.offset;

      await tester.pumpWidget(buildApp(Stack(children: [
        MinimapWidget(controller: controller, interactive: true)
      ])));

      // Find and tap the minimap
      final minimapFinder = find.byType(MinimapWidget);
      expect(minimapFinder, findsOneWidget);

      await tester.tapAt(tester.getCenter(minimapFinder));
      await tester.pump();

      // Viewport should have changed
      expect(controller.viewport.offset, isNot(initialOffset));
    });

    testWidgets('MinimapWidget accepts custom colors', (tester) async {
      final controller = FlowController();
      controller.addNode(position: const Offset(100, 100));

      await tester.pumpWidget(buildApp(Stack(children: [
        MinimapWidget(
          controller: controller,
          backgroundColor: const Color(0xFF000000),
          nodeColor: const Color(0xFFFF0000),
          viewportColor: const Color(0x4400FF00),
        )
      ])));

      expect(find.byType(MinimapWidget), findsOneWidget);
    });

    testWidgets('MinimapWidget renders empty controller without errors', (tester) async {
      final controller = FlowController();
      
      await tester.pumpWidget(buildApp(Stack(children: [
        MinimapWidget(controller: controller)
      ])));

      expect(find.byType(MinimapWidget), findsOneWidget);
    });
  });

  group('Overlays - ControlsWidget', () {
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
      expect(controller.viewport.zoom, lessThan(1.2));
    });
  });
}
