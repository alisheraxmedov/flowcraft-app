import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flowcraft/flowcraft.dart';

/// Hosts the handler at offset zero. With the default (unpanned, 1.0 zoom)
/// viewport screen coordinates are canvas coordinates; pass [viewport] to
/// exercise a zoomed canvas, where they are not.
///
/// [snap] and [gridSpacing] mirror the widget's own parameters so a test can
/// isolate one half of the snapping behaviour: most transform tests turn
/// snapping off entirely so their arithmetic is the transform's, and the
/// alignment tests keep it on but drop the grid.
Widget _host(
  SketchController controller,
  SketchInteractionState interaction, {
  FlowViewport viewport = const FlowViewport(),
  bool snap = true,
  double? gridSpacing = AppSpacing.canvasGrid,
  ValueChanged<bool>? onConsumedChange,
}) {
  return MaterialApp(
    home: SketchGestureHandler(
      controller: controller,
      interaction: interaction,
      viewportProvider: () => viewport,
      snapEnabled: snap,
      gridSpacing: gridSpacing,
      onConsumedChange: onConsumedChange,
      child: const SizedBox.expand(),
    ),
  );
}

/// Runs [body] with [key] physically held, so the handler's live
/// `HardwareKeyboard.instance` reads see it. Released even when [body]
/// throws — a key left down leaks into the next test in the file.
Future<void> _holding(
  WidgetTester tester,
  LogicalKeyboardKey key,
  Future<void> Function() body,
) async {
  await tester.sendKeyDownEvent(key);
  try {
    await body();
  } finally {
    await tester.sendKeyUpEvent(key);
  }
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

    // (40, 20) is where the pointer went; the top edge then snapped the
    // remaining 4px onto the 24px grid — see the snapping tests below.
    expect(controller.elements.single.bounds,
        const Rect.fromLTWH(40, 24, 100, 100));
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

  // ── Endpoint handles ─────────────────────────────────────────────────────
  // Before these, `_isResizable` excluded linear elements outright: a
  // pointer-down on an endpoint fell through to the plain hit test and
  // dragged the whole line, so an arrow drawn 5px off could only be deleted
  // and redrawn.

  testWidgets("dragging a line's start endpoint moves only that end",
      (tester) async {
    final controller = SketchController(
      currentTool: SketchTool.select,
      initialElements: [
        SketchLine.create(
          id: 'rail',
          start: const Offset(100, 100),
          end: const Offset(300, 100),
        ),
      ],
    );
    addTearDown(controller.dispose);
    controller.select('rail');

    final interaction = SketchInteractionState();
    addTearDown(interaction.dispose);

    await tester.pumpWidget(_host(controller, interaction, snap: false));

    final gesture = await tester.startGesture(const Offset(100, 100));
    await gesture.moveBy(const Offset(20, -30));
    await tester.pump();
    await gesture.moveBy(const Offset(24, -22));
    await tester.pump();
    await gesture.up();
    await tester.pump();

    final line = controller.elements.single as SketchLine;
    expect(line.start, const Offset(144, 48));
    expect(line.end, const Offset(300, 100));

    // Two pointer-moves, one continuous drag, one undo entry.
    controller.undo();
    expect(
      (controller.elements.single as SketchLine).start,
      const Offset(100, 100),
    );
    expect(controller.canUndo, isFalse);
  });

  testWidgets("dragging an arrow's end endpoint moves only the head",
      (tester) async {
    final controller = SketchController(
      currentTool: SketchTool.select,
      initialElements: [
        SketchArrow.create(
          id: 'flow',
          start: const Offset(0, 96),
          end: const Offset(200, 96),
        ),
      ],
    );
    addTearDown(controller.dispose);
    controller.select('flow');

    final interaction = SketchInteractionState();
    addTearDown(interaction.dispose);

    await tester.pumpWidget(_host(controller, interaction, snap: false));

    final gesture = await tester.startGesture(const Offset(200, 96));
    await gesture.moveBy(const Offset(20, -20));
    await tester.pump();
    await gesture.moveBy(const Offset(20, -28));
    await tester.pump();
    await gesture.up();
    await tester.pump();

    final arrow = controller.elements.single as SketchArrow;
    expect(arrow.end, const Offset(240, 48));
    expect(arrow.start, const Offset(0, 96));

    controller.undo();
    expect(
      (controller.elements.single as SketchArrow).end,
      const Offset(200, 96),
    );
    expect(controller.canUndo, isFalse);
  });

  testWidgets('an endpoint drag refuses to collapse the line to a point',
      (tester) async {
    final controller = SketchController(
      currentTool: SketchTool.select,
      initialElements: [
        SketchLine.create(
          id: 'rail',
          start: const Offset(100, 100),
          end: const Offset(300, 100),
        ),
      ],
    );
    addTearDown(controller.dispose);
    controller.select('rail');

    final interaction = SketchInteractionState();
    addTearDown(interaction.dispose);

    await tester.pumpWidget(_host(controller, interaction, snap: false));

    // Drag the tail exactly onto the head. A zero-length line has no
    // direction and no grabbable geometry left, so the frame is refused.
    final gesture = await tester.startGesture(const Offset(100, 100));
    await gesture.moveTo(const Offset(300, 100));
    await tester.pump();
    await gesture.up();
    await tester.pump();

    final line = controller.elements.single as SketchLine;
    expect(line.start, isNot(line.end));
  });

  // ── Eight-handle resize ──────────────────────────────────────────────────

  testWidgets('a top-left handle extends the shape up and to the left',
      (tester) async {
    final controller = SketchController(
      currentTool: SketchTool.select,
      initialElements: [_box('box', const Rect.fromLTWH(100, 100, 120, 80))],
    );
    addTearDown(controller.dispose);
    controller.select('box');

    final interaction = SketchInteractionState();
    addTearDown(interaction.dispose);

    await tester.pumpWidget(_host(controller, interaction, snap: false));

    // The selection box is padded, and the handle sits on the padded
    // corner — (100,100) inflated by SketchGeometry.selectionPadding.
    final gesture = await tester.startGesture(const Offset(96, 96));
    await gesture.moveBy(const Offset(-40, -30));
    await tester.pump();
    await gesture.up();
    await tester.pump();

    expect(
      controller.elements.single.bounds,
      const Rect.fromLTRB(60, 70, 220, 180),
    );
  });

  testWidgets('an edge midpoint handle moves one edge and leaves the other axis',
      (tester) async {
    final controller = SketchController(
      currentTool: SketchTool.select,
      initialElements: [_box('box', const Rect.fromLTWH(100, 100, 120, 80))],
    );
    addTearDown(controller.dispose);
    controller.select('box');

    final interaction = SketchInteractionState();
    addTearDown(interaction.dispose);

    await tester.pumpWidget(_host(controller, interaction, snap: false));

    // Right-edge midpoint of the padded box: (224, 140).
    final gesture = await tester.startGesture(const Offset(224, 140));
    await gesture.moveBy(const Offset(60, 60));
    await tester.pump();
    await gesture.up();
    await tester.pump();

    // The 60px of vertical pointer travel is ignored: this handle owns one
    // axis.
    expect(
      controller.elements.single.bounds,
      const Rect.fromLTRB(100, 100, 280, 180),
    );
  });

  testWidgets('Shift locks a corner resize to the original aspect ratio',
      (tester) async {
    final controller = SketchController(
      currentTool: SketchTool.select,
      initialElements: [_box('box', const Rect.fromLTWH(100, 100, 200, 100))],
    );
    addTearDown(controller.dispose);
    controller.select('box');

    final interaction = SketchInteractionState();
    addTearDown(interaction.dispose);

    await tester.pumpWidget(_host(controller, interaction, snap: false));

    await _holding(tester, LogicalKeyboardKey.shiftLeft, () async {
      // Bottom-right handle of the padded box, dragged along x only.
      final gesture = await tester.startGesture(const Offset(304, 204));
      await gesture.moveBy(const Offset(100, 0));
      await tester.pump();
      await gesture.up();
      await tester.pump();
    });

    // 200x100 grown to 300 wide keeps its 2:1 ratio, so the height follows
    // to 150 even though the pointer never moved vertically.
    expect(
      controller.elements.single.bounds,
      const Rect.fromLTRB(100, 100, 400, 250),
    );
  });

  // ── Additive, group-aware selection ──────────────────────────────────────

  testWidgets('Shift-click adds to the selection, then toggles back out',
      (tester) async {
    final controller = SketchController(
      currentTool: SketchTool.select,
      initialElements: [
        _box('a', const Rect.fromLTWH(0, 0, 100, 100)),
        _box('b', const Rect.fromLTWH(200, 0, 100, 100)),
      ],
    );
    addTearDown(controller.dispose);

    final interaction = SketchInteractionState();
    addTearDown(interaction.dispose);

    await tester.pumpWidget(_host(controller, interaction));

    await tester.tapAt(const Offset(50, 50));
    await tester.pump();
    expect(controller.selectedIds, <String>{'a'});

    await _holding(tester, LogicalKeyboardKey.shiftLeft, () async {
      await tester.tapAt(const Offset(250, 50));
      await tester.pump();
    });
    expect(controller.selectedIds, <String>{'a', 'b'});

    await _holding(tester, LogicalKeyboardKey.shiftLeft, () async {
      await tester.tapAt(const Offset(250, 50));
      await tester.pump();
    });
    expect(controller.selectedIds, <String>{'a'});
  });

  testWidgets('a Shift-marquee adds its hits instead of replacing them',
      (tester) async {
    final controller = SketchController(
      currentTool: SketchTool.select,
      initialElements: [
        _box('a', const Rect.fromLTWH(0, 0, 100, 100)),
        _box('b', const Rect.fromLTWH(200, 0, 100, 100)),
      ],
    );
    addTearDown(controller.dispose);

    final interaction = SketchInteractionState();
    addTearDown(interaction.dispose);

    await tester.pumpWidget(_host(controller, interaction));

    await tester.tapAt(const Offset(50, 50));
    await tester.pump();

    await _holding(tester, LogicalKeyboardKey.shiftLeft, () async {
      // A band over 'b' only — 'a' survives because shift was held.
      final gesture = await tester.startGesture(const Offset(350, 200));
      await gesture.moveTo(const Offset(210, 20));
      await tester.pump();
      await gesture.up();
      await tester.pump();
    });

    expect(controller.selectedIds, <String>{'a', 'b'});
  });

  testWidgets('clicking one member of a group selects the whole group',
      (tester) async {
    final controller = SketchController(
      currentTool: SketchTool.select,
      initialElements: [
        _box('a', const Rect.fromLTWH(0, 0, 100, 100)),
        _box('b', const Rect.fromLTWH(200, 0, 100, 100)),
      ],
    );
    addTearDown(controller.dispose);
    controller.selectMany(const <String>['a', 'b']);
    controller.groupSelected();
    controller.clearSelection();

    final interaction = SketchInteractionState();
    addTearDown(interaction.dispose);

    await tester.pumpWidget(_host(controller, interaction));

    await tester.tapAt(const Offset(50, 50));
    await tester.pump();

    expect(controller.selectedIds, <String>{'a', 'b'});
  });

  testWidgets('a marquee catching one group member takes the whole group',
      (tester) async {
    final controller = SketchController(
      currentTool: SketchTool.select,
      initialElements: [
        _box('a', const Rect.fromLTWH(0, 0, 100, 100)),
        _box('b', const Rect.fromLTWH(200, 0, 100, 100)),
      ],
    );
    addTearDown(controller.dispose);
    controller.selectMany(const <String>['a', 'b']);
    controller.groupSelected();
    controller.clearSelection();

    final interaction = SketchInteractionState();
    addTearDown(interaction.dispose);

    await tester.pumpWidget(_host(controller, interaction));

    final gesture = await tester.startGesture(const Offset(350, 200));
    await gesture.moveTo(const Offset(210, 20));
    await tester.pump();
    await gesture.up();
    await tester.pump();

    expect(controller.selectedIds, <String>{'a', 'b'});
  });

  testWidgets('a marquee drawn flush along a connector catches it',
      (tester) async {
    // An axis-aligned arrow's bounds are a single edge, and Rect.overlaps
    // calls a shared edge disjoint — so a band starting exactly on the
    // stroke visibly covered it and selected nothing.
    final controller = SketchController(
      currentTool: SketchTool.select,
      initialElements: [
        SketchArrow.create(
          id: 'wire',
          start: const Offset(100, 200),
          end: const Offset(300, 200),
        ),
      ],
    );
    addTearDown(controller.dispose);

    final interaction = SketchInteractionState();
    addTearDown(interaction.dispose);

    await tester.pumpWidget(_host(controller, interaction));

    final gesture = await tester.startGesture(const Offset(80, 200));
    await gesture.moveTo(const Offset(320, 260));
    await tester.pump();
    await gesture.up();
    await tester.pump();

    expect(controller.selectedIds, <String>{'wire'});
  });

  testWidgets('a marquee clipping only a diagonal line\'s empty corner misses',
      (tester) async {
    final controller = SketchController(
      currentTool: SketchTool.select,
      initialElements: [
        SketchLine.create(
          id: 'rail',
          start: Offset.zero,
          end: const Offset(200, 200),
        ),
      ],
    );
    addTearDown(controller.dispose);

    final interaction = SketchInteractionState();
    addTearDown(interaction.dispose);

    await tester.pumpWidget(_host(controller, interaction));

    // Inside the line's bounding box, but ~100px from the stroke.
    final gesture = await tester.startGesture(const Offset(190, 10));
    await gesture.moveTo(const Offset(150, 50));
    await tester.pump();
    await gesture.up();
    await tester.pump();

    expect(controller.selectedIds, isEmpty);
  });

  testWidgets('a cancelled drag does not wedge the drag after it',
      (tester) async {
    final controller = SketchController(
      currentTool: SketchTool.select,
      initialElements: [_box('box', const Rect.fromLTWH(96, 96, 48, 48))],
    );
    addTearDown(controller.dispose);

    final interaction = SketchInteractionState();
    addTearDown(interaction.dispose);

    await tester.pumpWidget(_host(controller, interaction));

    // A drag the window loses the pointer part-way through.
    final cancelled = await tester.startGesture(const Offset(120, 120));
    await cancelled.moveBy(const Offset(24, 24));
    await tester.pump();
    await cancelled.cancel();
    await tester.pump();

    expect(
      controller.elements.single.bounds,
      const Rect.fromLTWH(120, 120, 48, 48),
    );
    expect(controller.canUndo, isTrue,
        reason: 'the cancelled drag still moved something');

    // The next drag must record its own entry. It used to record none: the
    // controller was still mid-session, so `beginDragSession` no-opped and
    // there was no armed snapshot left for the mutation to commit.
    final gesture = await tester.startGesture(const Offset(144, 144));
    await gesture.moveBy(const Offset(24, 24));
    await tester.pump();
    await gesture.up();
    await tester.pump();

    expect(
      controller.elements.single.bounds,
      const Rect.fromLTWH(144, 144, 48, 48),
    );
    controller.undo();
    expect(
      controller.elements.single.bounds,
      const Rect.fromLTWH(120, 120, 48, 48),
      reason: 'one undo steps back one drag, not two',
    );
    controller.undo();
    expect(
      controller.elements.single.bounds,
      const Rect.fromLTWH(96, 96, 48, 48),
    );
    expect(controller.canUndo, isFalse);
  });

  // ── Button filtering ─────────────────────────────────────────────────────
  // `Listener` reports every button, so the handler used to treat a
  // right-click as a draw. On desktop right-click means context menu, and
  // the eraser mutates on pointer-down, so it was also a data-loss path.

  for (final (name, button) in <(String, int)>[
    ('right', kSecondaryButton),
    ('middle', kMiddleMouseButton),
  ]) {
    testWidgets('a $name-click with a shape tool draws nothing',
        (tester) async {
      final controller = SketchController(currentTool: SketchTool.rectangle);
      addTearDown(controller.dispose);

      final interaction = SketchInteractionState();
      addTearDown(interaction.dispose);

      final consumed = <bool>[];
      await tester.pumpWidget(
        _host(controller, interaction, onConsumedChange: consumed.add),
      );

      final gesture = await tester.startGesture(
        const Offset(100, 100),
        kind: PointerDeviceKind.mouse,
        buttons: button,
      );
      await gesture.moveBy(const Offset(80, 60));
      await tester.pump();
      await gesture.up();
      await tester.pump();

      expect(controller.elements, isEmpty);
      expect(controller.canUndo, isFalse);
      // Never consumed, so the canvas underneath keeps its pan/zoom — a
      // swallowed right-click is as wrong as a drawing one.
      expect(consumed, isEmpty);
    });

    testWidgets('a $name-click with the eraser deletes nothing',
        (tester) async {
      // The eraser erases on pointer-down, so it is the tool that loses
      // work outright if the button is not checked.
      final controller = SketchController(
        currentTool: SketchTool.eraser,
        initialElements: [_box('box', const Rect.fromLTWH(0, 0, 100, 100))],
      );
      addTearDown(controller.dispose);

      final interaction = SketchInteractionState();
      addTearDown(interaction.dispose);

      await tester.pumpWidget(_host(controller, interaction));

      final gesture = await tester.startGesture(
        const Offset(50, 50),
        kind: PointerDeviceKind.mouse,
        buttons: button,
      );
      await gesture.up();
      await tester.pump();

      expect(controller.elements, hasLength(1));
      expect(controller.canUndo, isFalse);
    });
  }

  testWidgets('a primary drag with a shape tool still draws', (tester) async {
    final controller = SketchController(currentTool: SketchTool.rectangle);
    addTearDown(controller.dispose);

    final interaction = SketchInteractionState();
    addTearDown(interaction.dispose);

    final consumed = <bool>[];
    await tester.pumpWidget(
      _host(controller, interaction, onConsumedChange: consumed.add),
    );

    final gesture = await tester.startGesture(
      const Offset(100, 100),
      kind: PointerDeviceKind.mouse,
    );
    await gesture.moveBy(const Offset(80, 60));
    await tester.pump();
    await gesture.up();
    await tester.pump();

    expect(controller.elements, hasLength(1));
    expect(controller.elements.single.bounds,
        const Rect.fromLTRB(100, 100, 180, 160));
    expect(consumed, <bool>[true, false]);
  });

  testWidgets('a trackpad-style touch drag still counts as primary',
      (tester) async {
    final controller = SketchController(currentTool: SketchTool.rectangle);
    addTearDown(controller.dispose);

    final interaction = SketchInteractionState();
    addTearDown(interaction.dispose);

    await tester.pumpWidget(_host(controller, interaction));

    // Touch and stylus contacts report kPrimaryButton the same way a mouse
    // does, which is why one mask test covers every device.
    final gesture = await tester.startGesture(const Offset(100, 100));
    await gesture.moveBy(const Offset(80, 60));
    await tester.pump();
    await gesture.up();
    await tester.pump();

    expect(controller.elements, hasLength(1));
  });

  testWidgets('pressing a second button mid-drag does not abandon the drag',
      (tester) async {
    final controller = SketchController(
      currentTool: SketchTool.select,
      initialElements: [_box('box', const Rect.fromLTWH(96, 96, 48, 48))],
    );
    addTearDown(controller.dispose);

    final interaction = SketchInteractionState();
    addTearDown(interaction.dispose);

    await tester.pumpWidget(_host(controller, interaction, snap: false));

    // Pressing a second button while down delivers a *move* with a wider
    // mask, not a fresh down — the drag has to survive it.
    final pointer = TestPointer(1, PointerDeviceKind.mouse);
    await tester.sendEventToBinding(pointer.down(const Offset(120, 120)));
    await tester.pump();
    await tester.sendEventToBinding(pointer.move(
      const Offset(140, 140),
      buttons: kPrimaryButton | kSecondaryButton,
    ));
    await tester.pump();
    await tester.sendEventToBinding(pointer.up());
    await tester.pump();

    expect(
      controller.elements.single.bounds,
      const Rect.fromLTWH(116, 116, 48, 48),
    );
  });

  testWidgets('a move reporting no buttons does not abandon the drag',
      (tester) async {
    // Flutter normalises touch and stylus masks but passes mouse and
    // trackpad ones through as the platform sent them, so a zero mask on a
    // move is a report with no interpretation — and the reading that drops
    // the drag is the one that loses the user's work.
    final controller = SketchController(
      currentTool: SketchTool.select,
      initialElements: [_box('box', const Rect.fromLTWH(96, 96, 48, 48))],
    );
    addTearDown(controller.dispose);

    final interaction = SketchInteractionState();
    addTearDown(interaction.dispose);

    await tester.pumpWidget(_host(controller, interaction, snap: false));

    final pointer = TestPointer(1, PointerDeviceKind.mouse);
    await tester.sendEventToBinding(pointer.down(const Offset(120, 120)));
    await tester.pump();
    await tester.sendEventToBinding(
      pointer.move(const Offset(140, 140), buttons: 0),
    );
    await tester.pump();
    await tester.sendEventToBinding(pointer.up());
    await tester.pump();

    expect(
      controller.elements.single.bounds,
      const Rect.fromLTWH(116, 116, 48, 48),
    );
  });

  testWidgets('releasing the primary under a held secondary ends the drag',
      (tester) async {
    final controller = SketchController(
      currentTool: SketchTool.select,
      initialElements: [_box('box', const Rect.fromLTWH(96, 96, 48, 48))],
    );
    addTearDown(controller.dispose);

    final interaction = SketchInteractionState();
    addTearDown(interaction.dispose);

    await tester.pumpWidget(_host(controller, interaction, snap: false));

    final pointer = TestPointer(1, PointerDeviceKind.mouse);
    await tester.sendEventToBinding(pointer.down(const Offset(120, 120)));
    await tester.pump();
    await tester.sendEventToBinding(pointer.move(const Offset(140, 140)));
    await tester.pump();

    // Primary released, secondary still held. No PointerUpEvent will
    // arrive until every button is up, so the drag has to end here —
    // otherwise it keeps tracking a cursor with nothing pressed.
    await tester.sendEventToBinding(
      pointer.move(const Offset(200, 200), buttons: kSecondaryButton),
    );
    await tester.pump();
    await tester.sendEventToBinding(
      pointer.move(const Offset(300, 300), buttons: kSecondaryButton),
    );
    await tester.pump();
    await tester.sendEventToBinding(pointer.up());
    await tester.pump();

    expect(
      controller.elements.single.bounds,
      const Rect.fromLTWH(116, 116, 48, 48),
      reason: 'the drag stopped where the primary came up',
    );
    // And it stayed one undo entry.
    controller.undo();
    expect(
      controller.elements.single.bounds,
      const Rect.fromLTWH(96, 96, 48, 48),
    );
    expect(controller.canUndo, isFalse);
  });

  // ── Snapping ─────────────────────────────────────────────────────────────

  testWidgets('a move snaps onto the grid, and Alt turns that off',
      (tester) async {
    // Already grid-aligned: 96 and 144 are both multiples of the 24px grid.
    final controller = SketchController(
      currentTool: SketchTool.select,
      initialElements: [_box('box', const Rect.fromLTWH(96, 96, 48, 48))],
    );
    addTearDown(controller.dispose);

    final interaction = SketchInteractionState();
    addTearDown(interaction.dispose);

    await tester.pumpWidget(_host(controller, interaction));

    Future<void> dragBy(Offset delta) async {
      final gesture = await tester.startGesture(const Offset(120, 120));
      await gesture.moveBy(delta);
      await tester.pump();
      await gesture.up();
      await tester.pump();
    }

    // 21px of pointer travel lands 3px short of the next grid line.
    await dragBy(const Offset(21, 21));
    expect(
      controller.elements.single.bounds,
      const Rect.fromLTWH(120, 120, 48, 48),
    );

    controller.undo();
    expect(
      controller.elements.single.bounds,
      const Rect.fromLTWH(96, 96, 48, 48),
    );

    await _holding(tester, LogicalKeyboardKey.altLeft, () async {
      await dragBy(const Offset(21, 21));
    });
    expect(
      controller.elements.single.bounds,
      const Rect.fromLTWH(117, 117, 48, 48),
    );
  });

  testWidgets('the snap threshold is a screen distance at 0.25x and at 4x',
      (tester) async {
    // 4 screen px of gap is inside the 6px magnet at both zooms...
    expect(await _alignmentRun(tester, zoom: 0.25, screenGap: 4),
        moreOrLessEquals(400, epsilon: 0.01));
    expect(await _alignmentRun(tester, zoom: 4.0, screenGap: 4),
        moreOrLessEquals(400, epsilon: 0.01));
    // ...and 10 screen px is outside it at both, even though those are 40
    // and 2.5 *canvas* pixels respectively.
    expect(await _alignmentRun(tester, zoom: 0.25, screenGap: 10),
        moreOrLessEquals(410, epsilon: 0.01));
    expect(await _alignmentRun(tester, zoom: 4.0, screenGap: 10),
        moreOrLessEquals(410, epsilon: 0.01));
  });
}

/// A filled box, so a tap anywhere inside it hits independently of
/// stroke-hit tolerance.
SketchRectangle _box(String id, Rect rect) => SketchRectangle.create(
      id: id,
      rect: rect,
      style: const SketchStyle(
        fillStyle: FillStyle.solid,
        fillColor: Color(0xFF000000),
      ),
    );

/// Drags a box until its left edge sits [screenGap] *screen* pixels short of
/// another box's left edge, and reports where that edge ended up — also in
/// screen pixels.
///
/// Every canvas coordinate is divided by [zoom], so the two runs are
/// pixel-identical on screen and differ only in what those pixels mean in
/// canvas units. That difference is precisely what a screen-space threshold
/// has to absorb, and what an unscaled one would not: at 4x it would be 16x
/// stickier than at 0.25x.
Future<double> _alignmentRun(
  WidgetTester tester, {
  required double zoom,
  required double screenGap,
}) async {
  final u = 1 / zoom;
  final controller = SketchController(
    currentTool: SketchTool.select,
    initialElements: [
      _box('target', Rect.fromLTWH(400 * u, 100 * u, 100 * u, 100 * u)),
      _box('mover', Rect.fromLTWH(100 * u, 300 * u, 100 * u, 100 * u)),
    ],
  );
  addTearDown(controller.dispose);
  controller.select('mover');

  final interaction = SketchInteractionState();
  addTearDown(interaction.dispose);

  // Grid off, so the only magnet under test is element alignment — the grid
  // has a floor of its own at low zoom (see SketchSnapper).
  await tester.pumpWidget(_host(
    controller,
    interaction,
    viewport: FlowViewport(zoom: zoom),
    gridSpacing: null,
  ));

  final gesture = await tester.startGesture(const Offset(150, 350));
  await gesture.moveBy(Offset(300 + screenGap, 0));
  await tester.pump();
  await gesture.up();
  await tester.pump();

  final mover = controller.elements.firstWhere((e) => e.id == 'mover');
  return mover.bounds.left * zoom;
}
