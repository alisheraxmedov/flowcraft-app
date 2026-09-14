import 'package:flowcraft/flowcraft.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

SketchRectangle _rect(String id) {
  return SketchRectangle.create(
    id: id,
    rect: const Rect.fromLTWH(0, 0, 10, 10),
  );
}

Widget _host(SketchController controller) {
  return MaterialApp(
    home: Scaffold(body: PartialSceneBanner(controller: controller)),
  );
}

void main() {
  testWidgets('stays out of the way on a clean load', (tester) async {
    final controller = SketchController(initialElements: [_rect('a')]);
    addTearDown(controller.dispose);

    await tester.pumpWidget(_host(controller));

    expect(find.textContaining('could not be read'), findsNothing);
  });

  testWidgets('says how many were lost and that saving is off', (tester) async {
    final controller = SketchController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(_host(controller));
    controller.loadScene([_rect('a')], droppedOnLoad: 3);
    await tester.pump();

    expect(find.textContaining('3 elements could not be read'), findsOneWidget);
    // The half people actually need: their edits are not being written.
    expect(find.textContaining('not being saved'), findsOneWidget);
  });

  testWidgets('counts one element in the singular', (tester) async {
    final controller = SketchController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(_host(controller));
    controller.loadScene([_rect('a')], droppedOnLoad: 1);
    await tester.pump();

    expect(find.textContaining('1 element could not'), findsOneWidget);
  });

  testWidgets('Save anyway is the only way out — dismissing would hide that '
      'nothing is being written', (tester) async {
    final controller = SketchController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(_host(controller));
    controller.loadScene([_rect('a')], droppedOnLoad: 2);
    await tester.pump();

    expect(find.text('Save anyway'), findsOneWidget);
    await tester.tap(find.text('Save anyway'));
    await tester.pump();

    expect(controller.sceneIsPartial, isFalse);
    expect(find.textContaining('could not be read'), findsNothing);
  });
}
