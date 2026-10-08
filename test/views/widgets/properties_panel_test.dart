import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flowcraft/flowcraft.dart';
import 'package:flowcraft/core/theme/canvas_ink.dart';
import 'package:flowcraft/core/theme/fc_tokens.dart';
import 'package:flowcraft/views/widgets/toolbar/palette_popover.dart';

Widget _host(SketchController controller, {ThemeData? theme}) {
  return MaterialApp(
    theme: theme ?? AppTheme.light(),
    home: Scaffold(
      body: Align(
        alignment: Alignment.topLeft,
        child: PropertiesPanel(controller: controller),
      ),
    ),
  );
}

/// The inspector is taller than the default 800x600 surface; a viewport that
/// is too short would leave the lower sections un-hittable.
void panelTest(String name, Future<void> Function(WidgetTester) body) {
  testWidgets(name, (tester) async {
    tester.view.physicalSize = const Size(1000, 1800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await body(tester);
  });
}

/// The panel island itself.
final _island = find.byType(GlassIsland);

SketchRectangle _rect({
  String? id,
  Rect rect = const Rect.fromLTWH(10, 20, 100, 50),
}) {
  return SketchRectangle.create(id: id, rect: rect);
}

void main() {
  group('PropertiesPanel visibility', () {
    panelTest('renders nothing when there is no selection', (tester) async {
      final controller = SketchController(initialElements: [_rect()]);
      addTearDown(controller.dispose);

      await tester.pumpWidget(_host(controller));

      expect(_island, findsNothing);
      expect(find.byType(TextField), findsNothing);
    });

    panelTest('renders the panel when exactly one element is selected', (
      tester,
    ) async {
      final controller = SketchController(initialElements: [_rect(id: 'a')]);
      addTearDown(controller.dispose);
      controller.select('a');

      await tester.pumpWidget(_host(controller));

      expect(_island, findsOneWidget);
      expect(find.text('Rectangle'), findsOneWidget);
      expect(find.text('PROPERTIES'), findsNothing);
      expect(find.byKey(const ValueKey('properties_field_X')), findsOneWidget);
      expect(find.byKey(const ValueKey('properties_field_Y')), findsOneWidget);
      expect(find.byKey(const ValueKey('properties_field_W')), findsOneWidget);
      expect(find.byKey(const ValueKey('properties_field_H')), findsOneWidget);

      TextField fieldByKey(String key) =>
          tester.widget<TextField>(find.byKey(ValueKey(key)));

      expect(fieldByKey('properties_field_X').controller!.text, '10');
      expect(fieldByKey('properties_field_Y').controller!.text, '20');
      expect(fieldByKey('properties_field_W').controller!.text, '100');
      expect(fieldByKey('properties_field_H').controller!.text, '50');
    });

    panelTest('hides again once the selection is cleared', (tester) async {
      final controller = SketchController(initialElements: [_rect(id: 'a')]);
      addTearDown(controller.dispose);
      controller.select('a');

      await tester.pumpWidget(_host(controller));
      expect(_island, findsOneWidget);

      controller.clearSelection();
      await tester.pump();

      expect(_island, findsNothing);
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

    panelTest('an unknown font family does not break the panel', (
      tester,
    ) async {
      // Reachable from "Edit JSON", "Paste JSON…" and "Import from file…":
      // any hand-edited scene. `DropdownButton` asserts when its value is
      // not among its items, and in release rendered a blank control.
      final controller = SketchController(
        initialElements: [text(fontFamily: 'Arial')],
      );
      addTearDown(controller.dispose);
      controller.select('t');

      await tester.pumpWidget(_host(controller));

      expect(tester.takeException(), isNull);
      expect(_island, findsOneWidget);
      expect(find.text('Arial'), findsOneWidget);
    });

    panelTest('a text with no family reads as Inter, which is what paints it', (
      tester,
    ) async {
      final controller = SketchController(initialElements: [text()]);
      addTearDown(controller.dispose);
      controller.select('t');

      await tester.pumpWidget(_host(controller));

      expect(find.text(TextMetrics.resolveFontFamily(null)), findsOneWidget);
      expect(find.text('Inter'), findsOneWidget);
    });
  });

  group('PropertiesPanel stroke width', () {
    panelTest('sliders have no tick marks and span the content width', (
      tester,
    ) async {
      final c = SketchController(initialElements: [_rect(id: 'a')]);
      addTearDown(c.dispose);
      c.select('a');
      await tester.pumpWidget(_host(c));
      final theme = SliderTheme.of(tester.element(find.byType(Slider).first));
      expect(theme.tickMarkShape, SliderTickMarkShape.noTickMark);
      expect(theme.overlayShape, SliderComponentShape.noOverlay);
      final slider = tester.getRect(find.byType(Slider).first);
      final box = tester.renderObject<RenderBox>(find.byType(Slider).first);
      final rect = theme.trackShape!.getPreferredRect(
        parentBox: box,
        sliderTheme: theme,
      );
      expect(rect.width, slider.width);
      expect(rect.left, 0);
    });

    panelTest('a half-step width keeps its own label', (tester) async {
      // The slider steps by 0.5; rounding the label to an integer would
      // show 1.5 as "2".
      final controller = SketchController(
        initialElements: [
          SketchRectangle.create(
            id: 'a',
            rect: const Rect.fromLTWH(0, 0, 100, 50),
            style: const SketchStyle(strokeWidth: 1.5),
          ),
        ],
      );
      addTearDown(controller.dispose);
      controller.select('a');

      await tester.pumpWidget(_host(controller));

      // The slider steps by halves; the mono value keeps one decimal.
      expect(find.text('1.5'), findsOneWidget);
    });
  });

  group('PropertiesPanel dimension edits', () {
    panelTest(
      'submitting X/Y/W/H fields resizes the element via the controller',
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
      },
    );

    panelTest(
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

        expect(_island, findsOneWidget);
        final field = tester.widget<TextField>(
          find.byKey(const ValueKey('properties_field_X')),
        );
        expect(field.enabled, isFalse);
      },
    );
  });

  group('PropertiesPanel kind-specific controls', () {
    SketchController seeded(SketchElement el) {
      final c = SketchController(initialElements: [el])..select(el.id);
      addTearDown(c.dispose);
      return c;
    }

    SketchElement only(SketchController c) => c.elements.single;

    panelTest('elbow switch toggles elbowed', (tester) async {
      final c = seeded(
        SketchArrow.create(
          id: 'a',
          start: Offset.zero,
          end: const Offset(100, 50),
        ),
      );
      await tester.pumpWidget(_host(c));
      await tester.tap(find.byKey(const ValueKey('properties_elbow')));
      await tester.pump();
      expect((only(c) as SketchArrow).elbowed, isTrue);
      c.undo();
      expect((only(c) as SketchArrow).elbowed, isFalse);
    });

    panelTest('head picker sets endHead', (tester) async {
      final c = seeded(
        SketchArrow.create(
          id: 'a',
          start: Offset.zero,
          end: const Offset(100, 50),
        ),
      );
      await tester.pumpWidget(_host(c));
      await tester.tap(find.byKey(const ValueKey('properties_end_head')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Zero or many').last);
      await tester.pumpAndSettle();
      expect((only(c) as SketchArrow).endHead, ArrowheadStyle.zeroOrMany);
    });

    panelTest('bold toggle updates element', (tester) async {
      final c = seeded(
        SketchText.create(id: 't', position: Offset.zero, text: 'hi'),
      );
      await tester.pumpWidget(_host(c));
      await tester.tap(find.byKey(const ValueKey('properties_bold')));
      await tester.pump();
      expect((only(c) as SketchText).bold, isTrue);
    });

    panelTest('align segment updates text', (tester) async {
      final c = seeded(
        SketchText.create(id: 't', position: Offset.zero, text: 'a\nbbb'),
      );
      await tester.pumpWidget(_host(c));
      await tester.tap(find.byTooltip('Align right'));
      await tester.pump();
      expect((only(c) as SketchText).align, TextAlign.right);
    });

    panelTest('frame name edit', (tester) async {
      final c = seeded(
        SketchFrame.create(
          id: 'f',
          rect: const Rect.fromLTWH(0, 0, 200, 100),
          name: 'Frame 1',
        ),
      );
      await tester.pumpWidget(_host(c));
      await tester.enterText(
        find.byKey(const ValueKey('properties_name')),
        'API',
      );
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      expect((only(c) as SketchFrame).name, 'API');
    });

    panelTest('entity attributes textarea parses rows and refits height', (
      tester,
    ) async {
      final c = seeded(
        SketchEntity.create(
          id: 'e',
          rect: const Rect.fromLTWH(0, 0, 200, 100),
          name: 'User',
        ),
      );
      await tester.pumpWidget(_host(c));
      await tester.enterText(
        find.byKey(const ValueKey('properties_attributes')),
        'id int PK\n\nteam_id int FK\nemail',
      );
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pump();

      final e = only(c) as SketchEntity;
      expect(e.attributes.map((a) => a.name), ['id', 'team_id', 'email']);
      expect(e.attributes[0].primaryKey, isTrue);
      expect(e.attributes[0].type, 'int');
      expect(e.attributes[1].foreignKey, isTrue);
      expect(e.rect.height, e.fittedHeight);
    });
  });

  group('PropertiesPanel commits to the edited element', () {
    SketchEntity entity(String id) => SketchEntity.create(
      id: id,
      rect: const Rect.fromLTWH(0, 0, 200, 100),
      name: id,
    );

    panelTest('typing in entity A then selecting B commits to A, not B', (
      tester,
    ) async {
      final c = SketchController(initialElements: [entity('a'), entity('b')]);
      addTearDown(c.dispose);
      c.select('a');
      await tester.pumpWidget(_host(c));
      await tester.enterText(
        find.byKey(const ValueKey('properties_attributes')),
        'id int',
      );
      c.select('b');
      await tester.pump();

      final a = c.elements.firstWhere((e) => e.id == 'a') as SketchEntity;
      final b = c.elements.firstWhere((e) => e.id == 'b') as SketchEntity;
      expect(a.attributes.map((x) => x.name), ['id']);
      expect(b.attributes, isEmpty);
    });

    panelTest('clearing selection mid-edit still commits to the element', (
      tester,
    ) async {
      final c = SketchController(initialElements: [entity('a')]);
      addTearDown(c.dispose);
      c.select('a');
      await tester.pumpWidget(_host(c));
      await tester.enterText(
        find.byKey(const ValueKey('properties_attributes')),
        'id int',
      );
      c.clearSelection();
      await tester.pump();

      expect((c.elements.single as SketchEntity).attributes.single.name, 'id');
    });

    panelTest('frame name edit survives selection change', (tester) async {
      final f = SketchFrame.create(
        id: 'f',
        rect: const Rect.fromLTWH(0, 0, 200, 100),
        name: 'Frame 1',
      );
      final c = SketchController(
        initialElements: [
          f,
          _rect(id: 'r'),
        ],
      );
      addTearDown(c.dispose);
      c.select('f');
      await tester.pumpWidget(_host(c));
      await tester.enterText(
        find.byKey(const ValueKey('properties_name')),
        'API',
      );
      c.select('r');
      await tester.pump();

      expect((c.elements.first as SketchFrame).name, 'API');
    });

    panelTest('duplicate attribute names show an error and do not commit', (
      tester,
    ) async {
      final c = SketchController(initialElements: [entity('a')]);
      addTearDown(c.dispose);
      c.select('a');
      await tester.pumpWidget(_host(c));
      await tester.enterText(
        find.byKey(const ValueKey('properties_attributes')),
        'id int\nid text',
      );
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pump();

      expect(find.text('Duplicate attribute name'), findsOneWidget);
      expect((c.elements.single as SketchEntity).attributes, isEmpty);
    });
  });

  // ── style sections (ported from the toolbar's popover tests) ────────────

  // Index 1 of the default fill palette — index 0 is the "none" sentinel.
  final fill = defaultFillPalette[1]!;
  final stroke = defaultPalette[1];

  SketchRectangle styled(String id, SketchStyle style, {double left = 0}) =>
      SketchRectangle.create(
        id: id,
        rect: Rect.fromLTWH(left, 0, 100, 60),
        style: style,
      );

  // The stroke grid comes first (10 swatches), then the fill grid.
  Finder strokeSwatch(int i) => find.byType(Swatch).at(i);
  Finder fillSwatch(int i) => find.byType(Swatch).at(defaultPalette.length + i);

  Future<void> pickFill(WidgetTester tester, int i) async {
    await tester.tap(fillSwatch(i));
    await tester.pumpAndSettle();
  }

  Future<void> pickStroke(WidgetTester tester, int i) async {
    await tester.tap(strokeSwatch(i));
    await tester.pumpAndSettle();
  }

  bool strokeCurrent(WidgetTester tester, int i) =>
      tester.widget<Swatch>(strokeSwatch(i)).current;

  group('PropertiesPanel fill colour', () {
    panelTest('recolours the selected shape and makes the fill visible', (
      tester,
    ) async {
      final controller = SketchController(initialElements: [_rect(id: 'a')]);
      addTearDown(controller.dispose);
      controller.select('a');

      await tester.pumpWidget(_host(controller));
      expect(controller.elements.single.style.fillColor, isNull);
      expect(controller.elements.single.style.fillStyle, FillStyle.none);

      await pickFill(tester, 1);

      final style = controller.elements.single.style;
      expect(style.fillColor, fill);
      // Without the promotion the painter skips the fill entirely.
      expect(style.fillStyle, FillStyle.solid);
      // The pick is still the default for the next element drawn, too.
      expect(controller.currentStyle.fillColor, fill);
      expect(controller.currentStyle.fillStyle, FillStyle.solid);
    });

    panelTest('one undo reverts the pick across a multi-element selection', (
      tester,
    ) async {
      final controller = SketchController(
        initialElements: [
          _rect(id: 'a'),
          _rect(id: 'b', rect: const Rect.fromLTWH(200, 0, 100, 60)),
          _rect(id: 'c', rect: const Rect.fromLTWH(400, 0, 100, 60)),
        ],
      );
      addTearDown(controller.dispose);
      controller.selectMany({'a', 'b'});

      await tester.pumpWidget(_host(controller));
      expect(controller.canUndo, isFalse);

      await pickFill(tester, 1);

      expect(controller.elements[0].style.fillColor, fill);
      expect(controller.elements[1].style.fillColor, fill);
      expect(controller.elements[2].style.fillColor, isNull);

      controller.undo();

      expect(
        controller.elements.map((e) => e.style.fillColor),
        everyElement(isNull),
      );
      expect(
        controller.elements.map((e) => e.style.fillStyle),
        everyElement(FillStyle.none),
      );
      expect(controller.canUndo, isFalse);
    });

    panelTest('the "none" swatch clears the fill again', (tester) async {
      final controller = SketchController(
        initialElements: [
          styled('a', SketchStyle(fillColor: fill, fillStyle: FillStyle.solid)),
        ],
      );
      addTearDown(controller.dispose);
      controller.select('a');

      await tester.pumpWidget(_host(controller));
      await pickFill(tester, 0);

      final style = controller.elements.single.style;
      expect(style.fillColor, isNull);
      expect(style.fillStyle, FillStyle.none);
    });

    panelTest('nothing selected + rectangle tool edits only currentStyle', (
      tester,
    ) async {
      final controller = SketchController(initialElements: [_rect(id: 'a')]);
      addTearDown(controller.dispose);
      controller.currentTool = SketchTool.rectangle;

      await tester.pumpWidget(_host(controller));
      expect(find.text('Rectangle tool'), findsOneWidget);
      // Style sections only: no geometry, no Edit JSON.
      expect(find.byKey(const ValueKey('properties_field_X')), findsNothing);
      expect(find.text('Edit JSON'), findsNothing);

      await pickFill(tester, 1);

      expect(controller.currentStyle.fillColor, fill);
      expect(controller.elements.single.style.fillColor, isNull);
      // Nothing changed on the canvas, so nothing to undo.
      expect(controller.canUndo, isFalse);
    });

    panelTest('hidden again with a non-drawing tool and no selection', (
      tester,
    ) async {
      final controller = SketchController();
      addTearDown(controller.dispose);
      controller.currentTool = SketchTool.rectangle;
      await tester.pumpWidget(_host(controller));
      expect(_island, findsOneWidget);

      controller.currentTool = SketchTool.eraser;
      await tester.pump();
      expect(_island, findsNothing);
    });
  });

  group('PropertiesPanel stroke colour', () {
    panelTest('recolours the selected shape and is undone in one step', (
      tester,
    ) async {
      final controller = SketchController(initialElements: [_rect(id: 'a')]);
      addTearDown(controller.dispose);
      controller.select('a');

      final before = controller.elements.single.style.strokeColor;
      await tester.pumpWidget(_host(controller));

      await pickStroke(tester, 1);

      expect(controller.elements.single.style.strokeColor, stroke);
      expect(controller.currentStyle.strokeColor, stroke);

      controller.undo();
      expect(controller.elements.single.style.strokeColor, before);
      expect(controller.canUndo, isFalse);
    });

    panelTest('a hex typed with several shapes selected restyles all', (
      tester,
    ) async {
      final controller = SketchController(
        initialElements: [
          _rect(id: 'a'),
          _rect(id: 'b', rect: const Rect.fromLTWH(200, 0, 100, 60)),
        ],
      );
      addTearDown(controller.dispose);
      controller.selectMany({'a', 'b'});
      await tester.pumpWidget(_host(controller));

      await tester.enterText(
        find.byKey(const ValueKey('properties_hex_Stroke')),
        '#E03131',
      );
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();

      expect(
        controller.elements.map((e) => e.style.strokeColor),
        everyElement(stroke),
      );
      controller.undo();
      expect(controller.canUndo, isFalse);
    });
  });

  group('PropertiesPanel reflects the selection', () {
    panelTest('shows the selected element, not the pending default', (
      tester,
    ) async {
      final controller = SketchController(
        initialElements: [
          styled('a', SketchStyle(strokeColor: stroke, strokeWidth: 6)),
        ],
      );
      addTearDown(controller.dispose);
      controller.select('a');

      await tester.pumpWidget(_host(controller));

      // `currentStyle` is still the untouched default here, so anything the
      // panel shows from it would be describing the wrong element.
      expect(controller.currentStyle.strokeColor, isNot(stroke));
      expect(strokeCurrent(tester, 1), isTrue);
      expect(strokeCurrent(tester, 0), isFalse);
      expect(find.text('6.0'), findsOneWidget);
    });

    panelTest('falls back to currentStyle when nothing is selected', (
      tester,
    ) async {
      final controller = SketchController(
        initialElements: [
          styled('a', SketchStyle(strokeColor: stroke, strokeWidth: 6)),
        ],
      );
      addTearDown(controller.dispose);
      controller.currentTool = SketchTool.ellipse;

      await tester.pumpWidget(_host(controller));

      expect(find.text('Ellipse tool'), findsOneWidget);
      expect(find.text('6.0'), findsNothing);
      expect(
        find.text(controller.currentStyle.strokeWidth.toStringAsFixed(1)),
        findsOneWidget,
      );
    });

    panelTest('follows the selection as it changes', (tester) async {
      final controller = SketchController(
        initialElements: [
          styled('a', SketchStyle(strokeColor: stroke)),
          styled(
            'b',
            const SketchStyle(strokeColor: Color(0xFF0CA678)),
            left: 200,
          ),
        ],
      );
      addTearDown(controller.dispose);
      controller.select('a');
      await tester.pumpWidget(_host(controller));
      expect(strokeCurrent(tester, 1), isTrue);

      controller.select('b');
      await tester.pump();
      expect(strokeCurrent(tester, 1), isFalse);
      expect(strokeCurrent(tester, 6), isTrue); // #0CA678
    });

    panelTest('a disagreeing multi-selection reads as mixed', (tester) async {
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

      // No stroke swatch is ringed, and the hex field says why.
      for (var i = 0; i < defaultPalette.length; i++) {
        expect(strokeCurrent(tester, i), isFalse, reason: 'swatch $i');
      }
      expect(find.text('mixed'), findsOneWidget);
      // The shared width still reads out; the slider is not mixed.
      expect(find.text('6.0'), findsOneWidget);
    });

    panelTest('a mixed slider reads as a dash, not the first value', (
      tester,
    ) async {
      final controller = SketchController(
        initialElements: [
          styled('a', const SketchStyle(strokeWidth: 6)),
          styled('b', const SketchStyle(strokeWidth: 2), left: 200),
        ],
      );
      addTearDown(controller.dispose);
      controller.selectMany({'a', 'b'});

      await tester.pumpWidget(_host(controller));

      expect(find.text('—'), findsOneWidget);
      expect(find.text('6.0'), findsNothing);
    });

    panelTest('an agreeing multi-selection is not mixed', (tester) async {
      final controller = SketchController(
        initialElements: [
          styled('a', SketchStyle(strokeColor: stroke)),
          styled('b', SketchStyle(strokeColor: stroke), left: 200),
        ],
      );
      addTearDown(controller.dispose);
      controller.selectMany({'a', 'b'});

      await tester.pumpWidget(_host(controller));

      expect(find.text('mixed'), findsNothing);
      expect(strokeCurrent(tester, 1), isTrue);
    });

    panelTest('multi-selection shows only the style sections', (tester) async {
      final controller = SketchController(
        initialElements: [
          _rect(id: 'a'),
          _rect(id: 'b', rect: const Rect.fromLTWH(200, 0, 100, 60)),
        ],
      );
      addTearDown(controller.dispose);
      controller.selectMany({'a', 'b'});

      await tester.pumpWidget(_host(controller));

      expect(find.text('2 selected'), findsOneWidget);
      expect(find.byType(Swatch), findsNWidgets(20));
      expect(find.byType(Slider), findsNWidgets(2));
      expect(find.byKey(const ValueKey('properties_field_X')), findsNothing);
      expect(find.text('Edit JSON'), findsNothing);
      expect(find.text('FONT'), findsNothing);
    });
  });

  group('PropertiesPanel theme and layout', () {
    panelTest("the stroke palette's first swatch is the theme's ink", (
      tester,
    ) async {
      final dark = FcTokens.dark;
      final controller = SketchController(
        initialElements: [
          styled('a', SketchStyle(strokeColor: inkFor(Brightness.dark))),
        ],
      );
      addTearDown(controller.dispose);
      controller.select('a');

      await tester.pumpWidget(_host(controller, theme: AppTheme.dark()));
      await tester.pumpAndSettle();

      final first = tester.widget<Swatch>(find.byType(Swatch).first);
      expect(first.color, inkFor(Brightness.dark));
      expect(
        first.dot,
        dark.swatchInk,
        reason: 'painted in the swatchInk token',
      );
      expect(first.current, isTrue, reason: 'it is what the shape is drawn in');
    });

    panelTest('inspector matches the mockup width of 264', (tester) async {
      final controller = SketchController(initialElements: [_rect(id: 'a')]);
      addTearDown(controller.dispose);
      controller.select('a');

      await tester.pumpWidget(_host(controller));

      expect(tester.getSize(_island).width, 264);
    });

    panelTest('swatches are named controls', (tester) async {
      final controller = SketchController(initialElements: [_rect(id: 'a')]);
      addTearDown(controller.dispose);
      controller.select('a');
      await tester.pumpWidget(_host(controller));

      expect(find.byTooltip('#E03131'), findsOneWidget);
      expect(find.byTooltip('No fill'), findsOneWidget);
      expect(find.byType(Swatch), findsNWidgets(20));
    });

    panelTest('the stroke-width slider follows a change of selection', (
      tester,
    ) async {
      final controller = SketchController(
        initialElements: [
          styled('a', const SketchStyle(strokeWidth: 6)),
          styled('b', const SketchStyle(strokeWidth: 2), left: 200),
        ],
      );
      addTearDown(controller.dispose);
      controller.select('a');
      await tester.pumpWidget(_host(controller));
      expect(find.text('6.0'), findsOneWidget);

      controller.select('b');
      await tester.pumpAndSettle();

      expect(find.text('2.0'), findsOneWidget);
      expect(find.text('6.0'), findsNothing);
    });

    panelTest('dragging a slider is one undo entry', (tester) async {
      final controller = SketchController(
        initialElements: [
          _rect(id: 'a'),
          _rect(id: 'b', rect: const Rect.fromLTWH(200, 0, 100, 60)),
        ],
      );
      addTearDown(controller.dispose);
      controller.selectMany({'a', 'b'});
      await tester.pumpWidget(_host(controller));

      await tester.drag(find.byType(Slider).first, const Offset(60, 0));
      await tester.pumpAndSettle();
      expect(controller.elements[0].style.strokeWidth, greaterThan(2));

      controller.undo();
      expect(controller.elements[0].style.strokeWidth, 2);
      expect(controller.elements[1].style.strokeWidth, 2);
      expect(controller.canUndo, isFalse);
    });

    panelTest('style choices read as words, not identifiers', (tester) async {
      final controller = SketchController(initialElements: [_rect(id: 'a')]);
      addTearDown(controller.dispose);
      controller.select('a');
      await tester.pumpWidget(_host(controller));

      expect(find.text('Cross-hatch'), findsOneWidget);
      expect(find.text('crossHatch'), findsNothing);
      expect(find.text('Dashed'), findsOneWidget);
    });

    panelTest('stroke and fill style segments restyle the selection', (
      tester,
    ) async {
      final controller = SketchController(initialElements: [_rect(id: 'a')]);
      addTearDown(controller.dispose);
      controller.select('a');
      await tester.pumpWidget(_host(controller));

      await tester.tap(find.text('Dashed'));
      await tester.pump();
      expect(controller.elements.single.style.strokeStyle, StrokeStyle.dashed);

      await tester.tap(find.text('Hachure'));
      await tester.pump();
      expect(controller.elements.single.style.fillStyle, FillStyle.hachure);
    });
  });
}
