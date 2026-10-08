import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flowcraft/core/canvas/tool_cursor.dart';
import 'package:flowcraft/core/canvas/whiteboard_canvas.dart';
import 'package:flowcraft/models/sketch_tool.dart';
import 'package:flowcraft/viewmodels/sketch_controller.dart';

final _glyph = find.byKey(const ValueKey('tool-cursor-glyph'));

/// Canvas with a 100 px "island" on top of its left edge, like the toolbar.
Future<SketchController> _pump(WidgetTester tester, SketchTool tool) async {
  final c = SketchController(currentTool: tool);
  addTearDown(c.dispose);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Stack(
          children: [
            Positioned.fill(child: WhiteboardCanvas(sketchController: c)),
            const Positioned(
              left: 0,
              top: 0,
              width: 100,
              height: 100,
              child: ColoredBox(color: Colors.red),
            ),
          ],
        ),
      ),
    ),
  );
  return c;
}

MouseCursor _cursor(WidgetTester tester) => tester
    .widget<MouseRegion>(
      find
          .descendant(
            of: find.byType(ToolCursorLayer),
            matching: find.byType(MouseRegion),
          )
          .first,
    )
    .cursor;

void main() {
  testWidgets('each tool group maps to its system cursor', (tester) async {
    final c = await _pump(tester, SketchTool.select);
    const expected = {
      SketchTool.select: SystemMouseCursors.basic,
      SketchTool.hand: SystemMouseCursors.grab,
      SketchTool.rectangle: SystemMouseCursors.precise,
      SketchTool.arrow: SystemMouseCursors.precise,
      SketchTool.frame: SystemMouseCursors.precise,
      SketchTool.text: SystemMouseCursors.text,
      SketchTool.freedraw: SystemMouseCursors.none,
      SketchTool.eraser: SystemMouseCursors.none,
    };
    for (final e in expected.entries) {
      c.currentTool = e.key;
      await tester.pump();
      expect(_cursor(tester), e.value, reason: '${e.key}');
    }
  });

  testWidgets('glyph sits on the hotspot, hides on exit and tool switch', (
    tester,
  ) async {
    final c = await _pump(tester, SketchTool.freedraw);
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(mouse.removePointer);
    await mouse.addPointer(location: const Offset(300, 300));
    await mouse.moveTo(const Offset(300, 300));
    await tester.pump();

    const k = ToolCursorLayer.glyphSize / 24;
    expect(
      tester.getTopLeft(_glyph),
      const Offset(300, 300) - ToolCursorLayer.pencilHotspot * k,
    );

    // Over the island the glyph goes away.
    await mouse.moveTo(const Offset(50, 50));
    await tester.pump();
    expect(_glyph, findsNothing);

    // Eraser uses its own hotspot.
    c.currentTool = SketchTool.eraser;
    await mouse.moveTo(const Offset(300, 300));
    await tester.pump();
    expect(
      tester.getTopLeft(_glyph),
      const Offset(300, 300) - ToolCursorLayer.eraserHotspot * k,
    );

    // Back to select: basic cursor, no glyph.
    c.currentTool = SketchTool.select;
    await tester.pump();
    expect(_cursor(tester), SystemMouseCursors.basic);
    expect(_glyph, findsNothing);
  });
}
