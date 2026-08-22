import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flowcraft/flowcraft.dart';

Widget _host(SketchController controller) {
  return MaterialApp(
    home: Scaffold(
      body: PropertiesPanel(controller: controller),
    ),
  );
}

SketchRectangle _rect({String? id, Rect rect = const Rect.fromLTWH(10, 20, 100, 50)}) {
  return SketchRectangle.create(id: id, rect: rect);
}

void main() {
  group('PropertiesPanel visibility', () {
    testWidgets('renders nothing when there is no selection', (tester) async {
      final controller = SketchController(initialElements: [_rect()]);
      addTearDown(controller.dispose);

      await tester.pumpWidget(_host(controller));

      expect(find.text('PROPERTIES'), findsNothing);
      expect(find.byType(TextField), findsNothing);
    });

    testWidgets('renders nothing when multiple elements are selected',
        (tester) async {
      final a = _rect(id: 'a');
      final b = _rect(id: 'b', rect: const Rect.fromLTWH(200, 200, 40, 40));
      final controller = SketchController(initialElements: [a, b]);
      addTearDown(controller.dispose);
      controller.selectMany(['a', 'b']);

      await tester.pumpWidget(_host(controller));

      expect(find.text('PROPERTIES'), findsNothing);
    });

    testWidgets('renders the panel when exactly one element is selected',
        (tester) async {
      final controller = SketchController(initialElements: [_rect(id: 'a')]);
      addTearDown(controller.dispose);
      controller.select('a');

      await tester.pumpWidget(_host(controller));

      expect(find.text('PROPERTIES'), findsOneWidget);
      expect(find.byKey(const ValueKey('properties_field_X')), findsOneWidget);
      expect(find.byKey(const ValueKey('properties_field_Y')), findsOneWidget);
      expect(find.byKey(const ValueKey('properties_field_W')), findsOneWidget);
      expect(find.byKey(const ValueKey('properties_field_H')), findsOneWidget);

      TextField fieldByKey(String key) => tester.widget<TextField>(
            find.byKey(ValueKey(key)),
          );

      expect(fieldByKey('properties_field_X').controller!.text, '10');
      expect(fieldByKey('properties_field_Y').controller!.text, '20');
      expect(fieldByKey('properties_field_W').controller!.text, '100');
      expect(fieldByKey('properties_field_H').controller!.text, '50');
    });

    testWidgets('hides again once the selection is cleared', (tester) async {
      final controller = SketchController(initialElements: [_rect(id: 'a')]);
      addTearDown(controller.dispose);
      controller.select('a');

      await tester.pumpWidget(_host(controller));
      expect(find.text('PROPERTIES'), findsOneWidget);

      controller.clearSelection();
      await tester.pump();

      expect(find.text('PROPERTIES'), findsNothing);
    });
  });

  group('PropertiesPanel typography', () {
    SketchText text({String? fontFamily}) => SketchText.create(
          id: 't',
          position: Offset.zero,
          text: 'hello',
          fontSize: 16,
          fontFamily: fontFamily,
        );

    testWidgets('an unknown font family does not break the panel',
        (tester) async {
      // Reachable from "Edit JSON", "Paste JSON…" and "Import from file…":
      // any hand-edited scene. `DropdownButton` asserts when its value is
      // not among its items, and in release rendered a blank control.
      final controller = SketchController(initialElements: [text(fontFamily: 'Arial')]);
      addTearDown(controller.dispose);
      controller.select('t');

      await tester.pumpWidget(_host(controller));

      expect(tester.takeException(), isNull);
      expect(find.text('PROPERTIES'), findsOneWidget);
      expect(find.text('Arial'), findsOneWidget);
    });

    testWidgets('a text with no family reads as Inter, which is what paints it',
        (tester) async {
      final controller = SketchController(initialElements: [text()]);
      addTearDown(controller.dispose);
      controller.select('t');

      await tester.pumpWidget(_host(controller));

      expect(find.text(TextMetrics.resolveFontFamily(null)), findsOneWidget);
      expect(find.text('Inter'), findsOneWidget);
    });
  });

  group('PropertiesPanel stroke width', () {
    testWidgets('a half-step width keeps its own label', (tester) async {
      // The toolbar slider steps by 0.5; rounding every label to an integer
      // put "2px" (1.5) next to "2px" (2.0).
      final controller = SketchController(initialElements: [
        SketchRectangle.create(
          id: 'a',
          rect: const Rect.fromLTWH(0, 0, 100, 50),
          style: const SketchStyle(strokeWidth: 1.5),
        ),
      ]);
      addTearDown(controller.dispose);
      controller.select('a');

      await tester.pumpWidget(_host(controller));

      expect(find.text('1.5px'), findsOneWidget);
      expect(find.text('2px', skipOffstage: false), findsOneWidget);
    });
  });

  group('PropertiesPanel dimension edits', () {
    testWidgets('submitting X/Y/W/H fields resizes the element via the controller',
        (tester) async {
      final controller = SketchController(initialElements: [_rect(id: 'a')]);
      addTearDown(controller.dispose);
      controller.select('a');

      await tester.pumpWidget(_host(controller));

      Future<void> submit(String key, String value) async {
        await tester.tap(find.byKey(ValueKey(key)));
        await tester.enterText(find.byKey(ValueKey(key)), value);
        await tester.testTextInput.receiveAction(TextInputAction.done);
        await tester.pump();
      }

      await submit('properties_field_X', '30');
      await submit('properties_field_Y', '40');
      await submit('properties_field_W', '300');
      await submit('properties_field_H', '150');

      final updated = controller.elements.single as SketchRectangle;
      expect(updated.rect, const Rect.fromLTWH(30, 40, 300, 150));

      // Each field commit must be undoable — a Properties Panel edit that
      // can't be undone would silently break the app's undo history.
      expect(controller.canUndo, isTrue);
      while (controller.canUndo) {
        controller.undo();
      }
      final reverted = controller.elements.single as SketchRectangle;
      expect(reverted.rect, const Rect.fromLTWH(10, 20, 100, 50));
    });

    testWidgets(
        'dimension fields are disabled (not resizable) for elements without a rect',
        (tester) async {
      final line = SketchLine.create(
        id: 'line',
        start: const Offset(0, 0),
        end: const Offset(50, 50),
      );
      final controller = SketchController(initialElements: [line]);
      addTearDown(controller.dispose);
      controller.select('line');

      await tester.pumpWidget(_host(controller));

      expect(find.text('PROPERTIES'), findsOneWidget);
      final field = tester.widget<TextField>(
        find.byKey(const ValueKey('properties_field_X')),
      );
      expect(field.enabled, isFalse);
    });
  });
}
