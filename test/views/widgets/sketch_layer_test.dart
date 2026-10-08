import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flowcraft/flowcraft.dart';

SketchPainter _painter(WidgetTester tester) => tester
    .widgetList<CustomPaint>(find.byType(CustomPaint))
    .map((w) => w.painter)
    .whereType<SketchPainter>()
    .single;

Future<SketchController> _pump(
  WidgetTester tester, {
  bool animate = true,
}) async {
  final controller = SketchController(
    initialElements: [
      SketchRectangle.create(id: 'a', rect: const Rect.fromLTWH(0, 0, 50, 50)),
    ],
  );
  addTearDown(controller.dispose);
  final viewport = FlowViewport();
  await tester.pumpWidget(
    MaterialApp(
      home: SketchLayer(
        controller: controller,
        viewportProvider: () => viewport,
        animateReveal: animate,
      ),
    ),
  );
  return controller;
}

void main() {
  testWidgets('requestReveal animates and settles within 2.5 s with paintGen '
      'unchanged', (tester) async {
    final controller = await _pump(tester);
    final gen = controller.paintGen;
    expect(_painter(tester).reveal, isNull);

    controller.requestReveal(['a']);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    final mid = _painter(tester).reveal;
    expect(mid, isNotNull);
    expect(mid!.t, inExclusiveRange(0, 1));

    await tester.pump(const Duration(milliseconds: 2500));
    await tester.pump();
    expect(_painter(tester).reveal, isNull);
    expect(controller.paintGen, gen);
    expect(controller.canUndo, isFalse);
  });

  testWidgets('toggle off → no reveal passed to the painter', (tester) async {
    final controller = await _pump(tester, animate: false);

    controller.requestReveal(['a']);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(_painter(tester).reveal, isNull);
  });
}
