import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flowcraft/flowcraft.dart';

/// Hosts the handler at offset zero. With the default (unpanned, 1.0 zoom)
/// viewport screen coordinates are canvas coordinates; pass [viewport] to
/// exercise a zoomed canvas, where they are not.
Widget _host(
  SketchController controller,
  SketchInteractionState interaction, {
  FlowViewport viewport = const FlowViewport(),
}) {
  return MaterialApp(
    home: SketchGestureHandler(
      controller: controller,
      interaction: interaction,
      viewportProvider: () => viewport,
      child: const SizedBox.expand(),
    ),
  );
}

/// A filled rectangle, so a tap anywhere in its interior hits it
/// independently of stroke-hit tolerance.
SketchRectangle _filledBox({String id = 'box'}) => SketchRectangle.create(
      id: id,
      rect: const Rect.fromLTWH(0, 0, 100, 100),
      style: const SketchStyle(
        fillStyle: FillStyle.solid,
        fillColor: Color(0xFF000000),
      ),
    );

/// 'Hello' at 16pt: 80px wide once measured, against the 44px the replaced
/// `length * fontSize * 0.55` guess claimed. A tap at x=70 therefore lands
/// on a painted glyph that the old bounds put outside the element.
SketchText _greeting() => SketchText.create(
      id: 'greeting',
      position: Offset.zero,
      text: 'Hello',
      fontSize: 16,
    );

/// Regression coverage for the interaction layer — the eraser tool, which
/// the user reported as "stopped working" after the `SketchHitTest`
/// stroke-hit consolidation, and the text-edit entry points, where a click
/// on existing text used to spawn a second text box on top of it.
void main() {
  testWidgets(
      'eraser tool removes the element under the pointer on pointer down',
      (tester) async {
    final controller = SketchController(currentTool: SketchTool.eraser);
    addTearDown(controller.dispose);

    // A filled rectangle so a tap anywhere in its interior hits it,
    // independent of stroke-hit tolerance edge cases.
    final rect = SketchRectangle.create(
      id: 'erase-me',
      rect: const Rect.fromLTWH(0, 0, 100, 100),
      style: const SketchStyle(
        fillStyle: FillStyle.solid,
        fillColor: Color(0xFF000000),
      ),
    );
    controller.add(rect);
    expect(controller.elements, hasLength(1));

    final interaction = SketchInteractionState();
    addTearDown(interaction.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: SketchGestureHandler(
          controller: controller,
          interaction: interaction,
          viewportProvider: () => const FlowViewport(),
          child: const SizedBox.expand(),
        ),
      ),
    );

    // The gesture handler fills the whole test surface at offset zero and
    // the default viewport has zero pan / 1.0 zoom, so screen == canvas
    // coordinates. Tap the interior of the rectangle (canvas 50,50).
    await tester.tapAt(const Offset(50, 50));
    await tester.pump();

    expect(controller.elements, isEmpty);
  });

  testWidgets(
      'text tool edits existing text instead of stacking a second text box',
      (tester) async {
    final controller = SketchController(currentTool: SketchTool.text);
    addTearDown(controller.dispose);

    final greeting = _greeting();
    controller.add(greeting);
    expect(greeting.bounds.right, greaterThan(70));

    final interaction = SketchInteractionState();
    addTearDown(interaction.dispose);

    await tester.pumpWidget(_host(controller, interaction));

    await tester.tapAt(const Offset(70, 8));
    await tester.pump();

    // Targeting the existing element, not a fresh canvas position.
    expect(controller.editingElementId, 'greeting');
    expect(controller.editingCanvasPosition, isNull);

    controller.commitTextEdit('Hello there');
    expect(controller.elements, hasLength(1));
    expect((controller.elements.single as SketchText).text, 'Hello there');
  });

  testWidgets('text tool still creates a new text box on empty canvas',
      (tester) async {
    final controller = SketchController(currentTool: SketchTool.text);
    addTearDown(controller.dispose);
    controller.add(_greeting());

    final interaction = SketchInteractionState();
    addTearDown(interaction.dispose);

    await tester.pumpWidget(_host(controller, interaction));

    await tester.tapAt(const Offset(400, 300));
    await tester.pump();

    expect(controller.editingElementId, isNull);
    expect(controller.editingCanvasPosition, const Offset(400, 300));

    controller.commitTextEdit('Second');
    expect(controller.elements, hasLength(2));
  });

  testWidgets('select tool double-tap opens the editor on a bare SketchText',
      (tester) async {
    final controller = SketchController(currentTool: SketchTool.select);
    addTearDown(controller.dispose);
    controller.add(_greeting());

    final interaction = SketchInteractionState();
    addTearDown(interaction.dispose);

    await tester.pumpWidget(_host(controller, interaction));

    // First tap selects; only the second one within the 400ms window edits.
    await tester.tapAt(const Offset(70, 8));
    await tester.pump();
    expect(controller.editingElementId, isNull);

    await tester.tapAt(const Offset(70, 8));
    await tester.pump();
    expect(controller.editingElementId, 'greeting');
    expect(controller.elements, hasLength(1));
  });

  testWidgets('select tool double-tap opens the editor on a labelled shape',
      (tester) async {
    final controller = SketchController(currentTool: SketchTool.select);
    addTearDown(controller.dispose);
    controller.add(SketchRectangle.create(
      id: 'box',
      rect: const Rect.fromLTWH(0, 0, 100, 100),
      text: 'Label',
    ));

    final interaction = SketchInteractionState();
    addTearDown(interaction.dispose);

    await tester.pumpWidget(_host(controller, interaction));

    await tester.tapAt(const Offset(50, 50));
    await tester.pump();
    expect(controller.editingElementId, isNull);

    await tester.tapAt(const Offset(50, 50));
    await tester.pump();
    expect(controller.editingElementId, 'box');
  });

  testWidgets('clicking to select leaves no undo entry behind', (tester) async {
    final controller = SketchController(
      currentTool: SketchTool.select,
      initialElements: [_filledBox()],
    );
    addTearDown(controller.dispose);

    final interaction = SketchInteractionState();
    addTearDown(interaction.dispose);

    await tester.pumpWidget(_host(controller, interaction));

    await tester.tapAt(const Offset(50, 50));
    await tester.pump();

    expect(controller.isSelected('box'), isTrue);
    // The click opened a move session that never moved. An entry here makes
    // the user's first undo a visible no-op.
    expect(controller.canUndo, isFalse);
  });

  testWidgets('dragging a selection leaves exactly one undo entry',
      (tester) async {
    final controller = SketchController(
      currentTool: SketchTool.select,
      initialElements: [_filledBox()],
    );
    addTearDown(controller.dispose);

    final interaction = SketchInteractionState();
    addTearDown(interaction.dispose);

    await tester.pumpWidget(_host(controller, interaction));

    final gesture = await tester.startGesture(const Offset(50, 50));
    await gesture.moveBy(const Offset(20, 10));
    await tester.pump();
    await gesture.moveBy(const Offset(20, 10));
    await tester.pump();
    await gesture.up();
    await tester.pump();

    expect(controller.elements.single.bounds,
        const Rect.fromLTWH(40, 20, 100, 100));
    controller.undo();
    expect(controller.elements.single.bounds,
        const Rect.fromLTWH(0, 0, 100, 100));
    expect(controller.canUndo, isFalse);
  });

  testWidgets('grab radius stays a screen distance when zoomed in',
      (tester) async {
    final controller = SketchController(
      currentTool: SketchTool.eraser,
      initialElements: [
        SketchLine.create(
          id: 'rail',
          start: Offset.zero,
          end: const Offset(100, 0),
        ),
      ],
    );
    addTearDown(controller.dispose);

    final interaction = SketchInteractionState();
    addTearDown(interaction.dispose);

    // At 4x zoom the line runs from screen (0,0) to (400,0).
    await tester.pumpWidget(_host(
      controller,
      interaction,
      viewport: const FlowViewport(zoom: 4.0),
    ));

    // 20 screen px away — well outside an 8px grab radius, but only 5
    // *canvas* px, which an unscaled tolerance of 8 would have swallowed.
    await tester.tapAt(const Offset(200, 20));
    await tester.pump();
    expect(controller.elements, hasLength(1));

    // 4 screen px away — inside the radius, so it still erases.
    await tester.tapAt(const Offset(200, 4));
    await tester.pump();
    expect(controller.elements, isEmpty);
  });

  testWidgets('grab radius stays a screen distance when zoomed out',
      (tester) async {
    final controller = SketchController(
      currentTool: SketchTool.eraser,
      initialElements: [
        SketchLine.create(
          id: 'rail',
          start: Offset.zero,
          end: const Offset(400, 0),
        ),
      ],
    );
    addTearDown(controller.dispose);

    final interaction = SketchInteractionState();
    addTearDown(interaction.dispose);

    // At 0.25x zoom the line runs from screen (0,0) to (100,0).
    await tester.pumpWidget(_host(
      controller,
      interaction,
      viewport: const FlowViewport(zoom: 0.25),
    ));

    // 6 screen px away — comfortably inside the radius, but 24 *canvas* px,
    // which an unscaled tolerance of 8 would have rejected.
    await tester.tapAt(const Offset(50, 6));
    await tester.pump();
    expect(controller.elements, isEmpty);
  });
}
