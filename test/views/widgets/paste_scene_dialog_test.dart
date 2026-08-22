import 'package:flowcraft/flowcraft.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

SketchRectangle _rect(String id) {
  return SketchRectangle.create(
    id: id,
    rect: const Rect.fromLTWH(0, 0, 10, 10),
  );
}

/// Opens the dialog the way the export menu does.
Future<void> _open(WidgetTester tester, SketchController controller) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => PasteSceneDialog.show(context, controller),
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

Future<void> _paste(WidgetTester tester, String json) async {
  await tester.enterText(find.byType(TextField), json);
  await tester.pump();
}

void main() {
  testWidgets('adding keeps the canvas and reports the count', (tester) async {
    final controller = SketchController(initialElements: [_rect('on-canvas')]);
    addTearDown(controller.dispose);

    await _open(tester, controller);
    await _paste(tester, SketchSerializer.serialize([_rect('pasted')]));
    await tester.tap(find.text('Add to canvas'));
    await tester.pumpAndSettle();

    expect(controller.elements, hasLength(2));
    expect(find.byType(PasteSceneDialog), findsNothing);
    expect(find.text('Imported 1 element'), findsOneWidget);
  });

  testWidgets('replacing swaps the canvas', (tester) async {
    final controller = SketchController(initialElements: [_rect('on-canvas')]);
    addTearDown(controller.dispose);

    await _open(tester, controller);
    await _paste(tester, SketchSerializer.serialize([_rect('pasted')]));
    await tester.tap(find.text('Replace canvas'));
    await tester.pumpAndSettle();

    expect(controller.elements.single.id, 'pasted');
  });

  testWidgets('a partial payload says so instead of quietly arriving short', (
    tester,
  ) async {
    final controller = SketchController();
    addTearDown(controller.dispose);

    await _open(tester, controller);
    await _paste(
      tester,
      '{"version": 1, "elements": ['
      '${_encoded(_rect("good"))}, {"id": "bad", "type": "hexagon"}]}',
    );
    await tester.tap(find.text('Add to canvas'));
    await tester.pumpAndSettle();

    expect(controller.elements, hasLength(1));
    expect(find.textContaining('1 could not be read'), findsOneWidget);
  });

  testWidgets('a bad payload keeps the dialog open with the reason', (
    tester,
  ) async {
    final controller = SketchController();
    addTearDown(controller.dispose);

    await _open(tester, controller);
    await _paste(tester, 'definitely not json');
    await tester.tap(find.text('Add to canvas'));
    await tester.pumpAndSettle();

    // Staying open is the point: the fix is to paste something else.
    expect(find.byType(PasteSceneDialog), findsOneWidget);
    expect(find.text('That file is not valid JSON.'), findsOneWidget);
    expect(controller.elements, isEmpty);
  });

  testWidgets('both import buttons are dead until something is pasted', (
    tester,
  ) async {
    final controller = SketchController();
    addTearDown(controller.dispose);

    await _open(tester, controller);

    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );
  });
}

String _encoded(SketchElement element) {
  final scene = SketchSerializer.serialize([element]);
  // Pull the single element object back out of the wrapper so it can be
  // dropped into a hand-written payload beside a deliberately broken one.
  final start = scene.indexOf('[') + 1;
  return scene.substring(start, scene.lastIndexOf(']'));
}
