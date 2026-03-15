import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flowcraft/flowcraft.dart';

void main() {
  Widget buildApp(
    FlowController controller, {
    bool miniMap = true,
    bool controls = true,
    bool enableKeyboardShortcuts = true,
    void Function(String edgeId)? onConnectionCreated,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: FlowCanvas(
          controller: controller,
          showMiniMap: miniMap,
          showControls: controls,
          enableKeyboardShortcuts: enableKeyboardShortcuts,
          onConnectionCreated: onConnectionCreated,
        ),
      ),
    );
  }

  group('FlowCanvas Widget', () {
    testWidgets('renders empty canvas', (tester) async {
      final controller = FlowController();
      await tester.pumpWidget(buildApp(controller));
      expect(find.byType(FlowCanvas), findsOneWidget);
    });

    testWidgets('renders nodes and edges', (tester) async {
      final controller = FlowController();
      final n1 = controller.addNode(position: const Offset(10, 10), label: 'N1');
      final n2 = controller.addNode(position: const Offset(200, 200), label: 'N2');
      controller.addEdge(
        sourceNodeId: n1.id,
        targetNodeId: n2.id,
        sourceHandleId: n1.handles.first.id,
        targetHandleId: n2.handles.last.id,
      );

      await tester.pumpWidget(buildApp(controller));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('N1'), findsOneWidget);
      expect(find.text('N2'), findsOneWidget);
    });

    testWidgets('minimap and controls can be disabled', (tester) async {
      final controller = FlowController();
      await tester.pumpWidget(buildApp(controller, miniMap: false, controls: false));
      expect(find.byIcon(Icons.add), findsNothing);
    });
  });

  group('FlowCanvas Keyboard Shortcuts', () {
    testWidgets('Ctrl+Z triggers undo', (tester) async {
      final controller = FlowController();
      controller.addNode(label: 'N1');
      controller.addNode(label: 'N2');
      expect(controller.nodes.length, 2);

      await tester.pumpWidget(buildApp(controller));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(find.byType(FlowCanvas));
      await tester.pump();

      await simulateKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await simulateKeyDownEvent(LogicalKeyboardKey.keyZ);
      await simulateKeyUpEvent(LogicalKeyboardKey.keyZ);
      await simulateKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pump();

      expect(controller.nodes.length, 1);
    });

    testWidgets('Ctrl+Y triggers redo', (tester) async {
      final controller = FlowController();
      controller.addNode(label: 'N1');
      controller.addNode(label: 'N2');
      controller.undo();
      expect(controller.nodes.length, 1);

      await tester.pumpWidget(buildApp(controller));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(find.byType(FlowCanvas));
      await tester.pump();

      await simulateKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await simulateKeyDownEvent(LogicalKeyboardKey.keyY);
      await simulateKeyUpEvent(LogicalKeyboardKey.keyY);
      await simulateKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pump();

      expect(controller.nodes.length, 2);
    });

    testWidgets('Escape clears selection', (tester) async {
      final controller = FlowController();
      final node = controller.addNode(label: 'EscMe');
      controller.selection.selectNode(node.id);
      expect(controller.selection.hasSelection, isTrue);

      await tester.pumpWidget(buildApp(controller));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(find.byType(FlowCanvas));
      await tester.pump();

      await simulateKeyDownEvent(LogicalKeyboardKey.escape);
      await simulateKeyUpEvent(LogicalKeyboardKey.escape);
      await tester.pump();

      expect(controller.selection.hasSelection, isFalse);
    });

    testWidgets('deleteSelection removes selected nodes', (tester) async {
      final controller = FlowController();
      final node = controller.addNode(label: 'ToDelete');
      controller.selection.selectNode(node.id);

      controller.deleteSelection();
      expect(controller.nodes.length, 0);
    });

    testWidgets('deleteSelection removes selected edges', (tester) async {
      final controller = FlowController();
      final n1 = controller.addNode(label: 'A');
      final n2 = controller.addNode(label: 'B');
      final edge = controller.addEdge(
        sourceNodeId: n1.id,
        targetNodeId: n2.id,
        sourceHandleId: 'h1',
        targetHandleId: 'h2',
      );

      controller.selection.toggleEdgeSelection(edge!.id);
      controller.deleteSelection();
      expect(controller.edges.isEmpty, isTrue);
    });
  });

  group('FlowCanvas API', () {
    testWidgets('onConnectionCreated callback accepted', (tester) async {
      final controller = FlowController();
      String? createdEdgeId;

      await tester.pumpWidget(buildApp(
        controller,
        onConnectionCreated: (id) => createdEdgeId = id,
      ));

      expect(find.byType(FlowCanvas), findsOneWidget);
      expect(createdEdgeId, isNull);
    });

    testWidgets('enableKeyboardShortcuts defaults to true', (tester) async {
      final controller = FlowController();
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: FlowCanvas(controller: controller)),
      ));
      expect(find.byType(FlowCanvas), findsOneWidget);
    });

    testWidgets('enableKeyboardShortcuts=false builds without error', (tester) async {
      final controller = FlowController();
      await tester.pumpWidget(buildApp(controller, enableKeyboardShortcuts: false));
      expect(find.byType(FlowCanvas), findsOneWidget);
    });

    testWidgets('Ctrl+Z is no-op when shortcuts disabled', (tester) async {
      final controller = FlowController();
      controller.addNode(label: 'N1');
      controller.addNode(label: 'N2');

      await tester.pumpWidget(buildApp(controller, enableKeyboardShortcuts: false));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(find.byType(FlowCanvas));
      await tester.pump();

      await simulateKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await simulateKeyDownEvent(LogicalKeyboardKey.keyZ);
      await simulateKeyUpEvent(LogicalKeyboardKey.keyZ);
      await simulateKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pump();

      expect(controller.nodes.length, 2);
    });
  });
}
