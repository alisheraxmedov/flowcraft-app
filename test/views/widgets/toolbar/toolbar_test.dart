import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flowcraft/flowcraft.dart';
import 'package:flowcraft/views/widgets/toolbar/palette_popover.dart';
import 'package:flowcraft/views/widgets/toolbar/style_popovers.dart';

/// The toolbar's style controls used to write only to
/// `SketchController.currentStyle` — the default for the *next* element —
/// so picking a colour with a shape selected visibly did nothing. Picking a
/// fill colour was doubly invisible: `FillStyle.none` meant the painter
/// skipped the fill even once the colour was set.
Widget _host(SketchController controller) {
  return MaterialApp(
    home: Scaffold(
      // A single tool keeps the bar narrow enough that every style button
      // sits inside the default 800×600 test surface.
      body: Align(
        alignment: Alignment.topLeft,
        child: SketchToolbarRich(
          controller: controller,
          tools: const [SketchTool.select],
        ),
      ),
    ),
  );
}

SketchRectangle _rect({required String id, double left = 0}) =>
    SketchRectangle.create(
      id: id,
      rect: Rect.fromLTWH(left, 0, 100, 60),
    );

/// Opens [tooltip]'s palette popover and taps the swatch at [index].
Future<void> _pick(WidgetTester tester, String tooltip, int index) async {
  await tester.tap(find.byTooltip(tooltip));
  await tester.pumpAndSettle();
  await tester.tap(
    find
        .descendant(
          of: find.byType(tooltip == 'Fill color'
              ? FillPalettePopover
              : PalettePopover),
          matching: find.byType(GestureDetector),
        )
        .at(index),
  );
  await tester.pumpAndSettle();
}

void main() {
  // Index 1 of the default fill palette — index 0 is the "none" sentinel.
  final fill = SketchToolbarRich.defaultFillPalette[1]!;
  final stroke = SketchToolbarRich.defaultPalette[1];

  group('SketchToolbarRich fill colour', () {
    testWidgets('recolours the selected shape and makes the fill visible',
        (tester) async {
      final controller = SketchController(initialElements: [_rect(id: 'a')]);
      addTearDown(controller.dispose);
      controller.select('a');

      await tester.pumpWidget(_host(controller));
      expect(controller.elements.single.style.fillColor, isNull);
      expect(controller.elements.single.style.fillStyle, FillStyle.none);

      await _pick(tester, 'Fill color', 1);

      final style = controller.elements.single.style;
      expect(style.fillColor, fill);
      // Without the promotion the painter skips the fill entirely and the
      // shape looks exactly as it did before the pick.
      expect(style.fillStyle, FillStyle.solid);
      // The pick is still the default for the next element drawn, too.
      expect(controller.currentStyle.fillColor, fill);
      expect(controller.currentStyle.fillStyle, FillStyle.solid);
    });

    testWidgets('one undo reverts the pick across a multi-element selection',
        (tester) async {
      final controller = SketchController(
        initialElements: [
          _rect(id: 'a'),
          _rect(id: 'b', left: 200),
          _rect(id: 'c', left: 400),
        ],
      );
      addTearDown(controller.dispose);
      controller.selectMany({'a', 'b'});

      await tester.pumpWidget(_host(controller));
      expect(controller.canUndo, isFalse);

      await _pick(tester, 'Fill color', 1);

      expect(controller.elements[0].style.fillColor, fill);
      expect(controller.elements[1].style.fillColor, fill);
      expect(controller.elements[2].style.fillColor, isNull);

      controller.undo();

      expect(controller.elements.map((e) => e.style.fillColor),
          everyElement(isNull));
      expect(controller.elements.map((e) => e.style.fillStyle),
          everyElement(FillStyle.none));
      expect(controller.canUndo, isFalse);
    });

    testWidgets('the "none" swatch clears the fill again', (tester) async {
      final controller = SketchController(
        initialElements: [
          SketchRectangle.create(
            id: 'a',
            rect: const Rect.fromLTWH(0, 0, 100, 60),
            style: SketchStyle(fillColor: fill, fillStyle: FillStyle.solid),
          ),
        ],
      );
      addTearDown(controller.dispose);
      controller.select('a');

      await tester.pumpWidget(_host(controller));
      await _pick(tester, 'Fill color', 0);

      final style = controller.elements.single.style;
      expect(style.fillColor, isNull);
      expect(style.fillStyle, FillStyle.none);
    });

    testWidgets('touches only currentStyle when nothing is selected',
        (tester) async {
      final controller = SketchController(initialElements: [_rect(id: 'a')]);
      addTearDown(controller.dispose);

      await tester.pumpWidget(_host(controller));
      await _pick(tester, 'Fill color', 1);

      expect(controller.currentStyle.fillColor, fill);
      expect(controller.elements.single.style.fillColor, isNull);
      // Nothing changed on the canvas, so nothing to undo.
      expect(controller.canUndo, isFalse);
    });
  });

  group('SketchToolbarRich reflects the selection', () {
    SketchRectangle styled(String id, SketchStyle style, {double left = 0}) =>
        SketchRectangle.create(
          id: id,
          rect: Rect.fromLTWH(left, 0, 100, 60),
          style: style,
        );

    T anchor<T extends Widget>(WidgetTester tester, String tooltip) =>
        tester.widget<T>(find.descendant(
          of: find.byTooltip(tooltip),
          matching: find.byType(T),
        ));

    testWidgets('shows the selected element, not the pending default',
        (tester) async {
      final controller = SketchController(
        initialElements: [
          styled('a', SketchStyle(strokeColor: stroke, strokeWidth: 6)),
        ],
      );
      addTearDown(controller.dispose);
      controller.select('a');

      await tester.pumpWidget(_host(controller));

      // `currentStyle` is still the untouched default here, so anything the
      // toolbar shows from it would be describing the wrong element.
      expect(controller.currentStyle.strokeColor, isNot(stroke));
      expect(anchor<SwatchCircle>(tester, 'Stroke color').color, stroke);
      expect(anchor<StrokeWidthGlyph>(tester, 'Stroke width').width, 6);
    });

    testWidgets('falls back to currentStyle when nothing is selected',
        (tester) async {
      final controller = SketchController(
        initialElements: [
          styled('a', SketchStyle(strokeColor: stroke, strokeWidth: 6)),
        ],
      );
      addTearDown(controller.dispose);

      await tester.pumpWidget(_host(controller));

      final current = controller.currentStyle;
      expect(anchor<SwatchCircle>(tester, 'Stroke color').color,
          current.strokeColor);
      expect(anchor<StrokeWidthGlyph>(tester, 'Stroke width').width,
          current.strokeWidth);
    });

    testWidgets('follows the selection as it changes', (tester) async {
      final controller = SketchController(
        initialElements: [
          styled('a', SketchStyle(strokeColor: stroke)),
          styled('b', const SketchStyle(strokeColor: Color(0xFF0CA678)),
              left: 200),
        ],
      );
      addTearDown(controller.dispose);

      await tester.pumpWidget(_host(controller));

      controller.select('a');
      await tester.pump();
      expect(anchor<SwatchCircle>(tester, 'Stroke color').color, stroke);

      controller.select('b');
      await tester.pump();
      expect(anchor<SwatchCircle>(tester, 'Stroke color').color,
          const Color(0xFF0CA678));
    });

    testWidgets('a disagreeing multi-selection reads as mixed', (tester) async {
      final controller = SketchController(
        initialElements: [
          // Same stroke width, different stroke colour: one field is mixed,
          // the other is genuinely shared and must still show its value.
          styled('a', SketchStyle(strokeColor: stroke, strokeWidth: 6)),
          styled('b', const SketchStyle(strokeWidth: 6), left: 200),
        ],
      );
      addTearDown(controller.dispose);
      controller.selectMany({'a', 'b'});

      await tester.pumpWidget(_host(controller));

      // Neutral glyph + flagged tooltip rather than element 'a' speaking for
      // both of them.
      expect(find.byTooltip('Stroke color — mixed'), findsOneWidget);
      expect(find.byTooltip('Stroke color'), findsNothing);
      expect(
        find.descendant(
          of: find.byTooltip('Stroke color — mixed'),
          matching: find.byType(SwatchCircle),
        ),
        findsNothing,
      );

      expect(find.byTooltip('Stroke width'), findsOneWidget);
      expect(anchor<StrokeWidthGlyph>(tester, 'Stroke width').width, 6);
    });

    testWidgets('a mixed field marks no swatch as current in its popover',
        (tester) async {
      final controller = SketchController(
        initialElements: [
          styled('a', SketchStyle(strokeColor: stroke)),
          styled('b', const SketchStyle(), left: 200),
        ],
      );
      addTearDown(controller.dispose);
      controller.selectMany({'a', 'b'});

      await tester.pumpWidget(_host(controller));
      await tester.tap(find.byTooltip('Stroke color — mixed'));
      await tester.pumpAndSettle();

      expect(tester.widget<PalettePopover>(find.byType(PalettePopover)).selected,
          isNull);
    });

    testWidgets('an agreeing multi-selection is not mixed', (tester) async {
      final controller = SketchController(
        initialElements: [
          styled('a', SketchStyle(strokeColor: stroke)),
          styled('b', SketchStyle(strokeColor: stroke), left: 200),
        ],
      );
      addTearDown(controller.dispose);
      controller.selectMany({'a', 'b'});

      await tester.pumpWidget(_host(controller));

      expect(find.byTooltip('Stroke color — mixed'), findsNothing);
      expect(anchor<SwatchCircle>(tester, 'Stroke color').color, stroke);
    });
  });

  group('SketchToolbarRich stroke colour', () {
    testWidgets('recolours the selected shape and is undone in one step',
        (tester) async {
      final controller = SketchController(initialElements: [_rect(id: 'a')]);
      addTearDown(controller.dispose);
      controller.select('a');

      final before = controller.elements.single.style.strokeColor;
      await tester.pumpWidget(_host(controller));

      await _pick(tester, 'Stroke color', 1);

      expect(controller.elements.single.style.strokeColor, stroke);
      expect(controller.currentStyle.strokeColor, stroke);

      controller.undo();
      expect(controller.elements.single.style.strokeColor, before);
      expect(controller.canUndo, isFalse);
    });
  });
}
