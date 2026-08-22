import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flowcraft/core/canvas/grid_painter.dart';
import 'package:flowcraft/core/canvas/whiteboard_canvas.dart';
import 'package:flowcraft/models/flow_viewport.dart';
import 'package:flowcraft/models/sketch_tool.dart';
import 'package:flowcraft/viewmodels/sketch_controller.dart';

/// The viewport the canvas is currently painting, read off its grid layer —
/// the one observable that every pan/zoom path ends in.
FlowViewport _viewportOf(WidgetTester tester) {
  final grid = tester
      .widgetList<CustomPaint>(find.byType(CustomPaint))
      .map((w) => w.painter)
      .whereType<GridPainter>()
      .single;
  return grid.viewport;
}

Future<SketchController> _pump(WidgetTester tester) async {
  final controller = SketchController(currentTool: SketchTool.hand);
  addTearDown(controller.dispose);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(body: WhiteboardCanvas(sketchController: controller)),
    ),
  );
  await tester.pump();
  return controller;
}

Future<void> _scroll(WidgetTester tester, Offset delta) async {
  final pointer = TestPointer(1, PointerDeviceKind.mouse);
  final centre = tester.getCenter(find.byType(WhiteboardCanvas));
  await tester.sendEventToBinding(pointer.hover(centre));
  await tester.sendEventToBinding(pointer.scroll(delta));
  await tester.pump();
}

void main() {
  testWidgets('horizontal scroll leaves zoom unchanged', (tester) async {
    await _pump(tester);
    final before = _viewportOf(tester);
    expect(before.zoom, 1.0);

    // A trackpad sideways flick is dozens of these in a row.
    for (var i = 0; i < 12; i++) {
      await _scroll(tester, const Offset(10, 0));
    }
    final after = _viewportOf(tester);
    expect(after.zoom, 1.0);
    expect(after.offset.dx, before.offset.dx - 120,
        reason: 'it pans sideways instead');
    expect(after.offset.dy, before.offset.dy);
  });

  testWidgets('plain vertical scroll pans', (tester) async {
    await _pump(tester);
    final before = _viewportOf(tester);
    await _scroll(tester, const Offset(0, 40));
    final after = _viewportOf(tester);
    expect(after.zoom, before.zoom);
    expect(after.offset, before.offset - const Offset(0, 40));
  });

  testWidgets('ctrl+scroll zooms, multiplicatively and about the pointer',
      (tester) async {
    await _pump(tester);
    final before = _viewportOf(tester);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await _scroll(tester, const Offset(0, -100)); // wheel up → zoom in
    final zoomedIn = _viewportOf(tester);
    expect(zoomedIn.zoom,
        closeTo(before.zoom * (1 + 100 * WhiteboardCanvas.wheelZoomRate), 1e-9));

    await _scroll(tester, const Offset(0, 100)); // wheel down → zoom out
    final zoomedOut = _viewportOf(tester);
    expect(zoomedOut.zoom,
        closeTo(zoomedIn.zoom * (1 - 100 * WhiteboardCanvas.wheelZoomRate), 1e-9));
    expect(zoomedOut.zoom, lessThan(zoomedIn.zoom));

    // Horizontal travel with the modifier held is still not a zoom.
    await _scroll(tester, const Offset(25, 0));
    expect(_viewportOf(tester).zoom, zoomedOut.zoom);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
  });

  testWidgets('cmd+scroll zooms too', (tester) async {
    await _pump(tester);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
    await _scroll(tester, const Offset(0, -50));
    await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
    expect(_viewportOf(tester).zoom, greaterThan(1.0));
  });

  testWidgets('a single flung wheel event cannot take zoom negative',
      (tester) async {
    await _pump(tester);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await _scroll(tester, const Offset(0, 5000));
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    final v = _viewportOf(tester);
    expect(v.zoom, greaterThan(0));
    expect(v.zoom, greaterThanOrEqualTo(v.minZoom));
  });
}
