import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flowcraft/flowcraft.dart';
import 'package:flowcraft/models/icon_catalog.dart';
import 'package:flowcraft/views/widgets/toolbar/palette_popover.dart';
import 'package:flowcraft/views/widgets/toolbar/style_popovers.dart';

/// The toolbar's style controls used to write only to
/// `SketchController.currentStyle` — the default for the *next* element —
/// so picking a colour with a shape selected visibly did nothing. Picking a
/// fill colour was doubly invisible: `FillStyle.none` meant the painter
/// skipped the fill even once the colour was set.
Widget _host(
  SketchController controller, {
  ThemeData? theme,
  List<SketchTool> tools = const [SketchTool.select],
}) {
  return MaterialApp(
    theme: theme,
    home: Scaffold(
      // A single tool keeps the bar narrow enough that every style button
      // sits inside the default 800×600 test surface.
      body: Align(
        alignment: Alignment.topLeft,
        child: SketchToolbarRich(controller: controller, tools: tools),
      ),
    ),
  );
}

/// The vertical rail as the whiteboard mounts it, inside a body [height]
/// tall, on a 1280×720 surface.
Widget _rail(SketchController controller, {required double height}) {
  return MaterialApp(
    home: Scaffold(
      body: Align(
        alignment: Alignment.topLeft,
        child: SizedBox(
          height: height,
          child: SketchToolbarRich(
            controller: controller,
            orientation: Axis.vertical,
          ),
        ),
      ),
    ),
  );
}

SketchRectangle _rect({required String id, double left = 0}) =>
    SketchRectangle.create(id: id, rect: Rect.fromLTWH(left, 0, 100, 60));

/// Opens [tooltip]'s palette popover and taps the swatch at [index].
Future<void> _pick(WidgetTester tester, String tooltip, int index) async {
  await tester.tap(find.byTooltip(tooltip));
  await tester.pumpAndSettle();
  await tester.tap(
    find
        .descendant(
          of: find.byType(
            tooltip == 'Fill color' ? FillPalettePopover : PalettePopover,
          ),
          matching: find.byType(Swatch),
        )
        .at(index),
  );
  await tester.pumpAndSettle();
}

/// Sizes the test surface like a laptop window, restored on teardown.
void _laptopWindow(WidgetTester tester, {double height = 720}) {
  tester.view.physicalSize = Size(1280, height);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  // Index 1 of the default fill palette — index 0 is the "none" sentinel.
  final fill = SketchToolbarRich.defaultFillPalette[1]!;
  final stroke = SketchToolbarRich.defaultPalette[1];

  group('SketchToolbarRich fill colour', () {
    testWidgets('recolours the selected shape and makes the fill visible', (
      tester,
    ) async {
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

    testWidgets('one undo reverts the pick across a multi-element selection', (
      tester,
    ) async {
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

    testWidgets('touches only currentStyle when nothing is selected', (
      tester,
    ) async {
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
        tester.widget<T>(
          find.descendant(
            of: find.byTooltip(tooltip),
            matching: find.byType(T),
          ),
        );

    testWidgets('shows the selected element, not the pending default', (
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
      // toolbar shows from it would be describing the wrong element.
      expect(controller.currentStyle.strokeColor, isNot(stroke));
      expect(anchor<SwatchCircle>(tester, 'Stroke color').color, stroke);
      expect(anchor<StrokeWidthGlyph>(tester, 'Stroke width').width, 6);
    });

    testWidgets('falls back to currentStyle when nothing is selected', (
      tester,
    ) async {
      final controller = SketchController(
        initialElements: [
          styled('a', SketchStyle(strokeColor: stroke, strokeWidth: 6)),
        ],
      );
      addTearDown(controller.dispose);

      await tester.pumpWidget(_host(controller));

      final current = controller.currentStyle;
      expect(
        anchor<SwatchCircle>(tester, 'Stroke color').color,
        current.strokeColor,
      );
      expect(
        anchor<StrokeWidthGlyph>(tester, 'Stroke width').width,
        current.strokeWidth,
      );
    });

    testWidgets('follows the selection as it changes', (tester) async {
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

      await tester.pumpWidget(_host(controller));

      controller.select('a');
      await tester.pump();
      expect(anchor<SwatchCircle>(tester, 'Stroke color').color, stroke);

      controller.select('b');
      await tester.pump();
      expect(
        anchor<SwatchCircle>(tester, 'Stroke color').color,
        const Color(0xFF0CA678),
      );
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

    testWidgets('a mixed field marks no swatch as current in its popover', (
      tester,
    ) async {
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

      expect(
        tester.widget<PalettePopover>(find.byType(PalettePopover)).selected,
        isNull,
      );
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
    testWidgets('recolours the selected shape and is undone in one step', (
      tester,
    ) async {
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

  group('the vertical rail fits the window', () {
    // The rail used to size its tool grid against the *whole* body height,
    // forgetting the style anchors and actions stacked under it: at 720 px
    // it chose single-column, ran off the bottom of the window, and left
    // "Clear" reachable only by a wheel-scroll nobody knew was there.
    Future<void> expectFits(WidgetTester tester, double height) async {
      _laptopWindow(tester);
      final controller = SketchController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(_rail(controller, height: height));

      final scrollable = tester.state<ScrollableState>(
        find.descendant(
          of: find.byType(SketchToolbarRich),
          matching: find.byType(Scrollable),
        ),
      );
      expect(
        scrollable.position.maxScrollExtent,
        0,
        reason: 'nothing left to scroll to at $height px',
      );

      final clear = tester.getRect(find.byTooltip('Clear sketches'));
      expect(
        clear.bottom,
        lessThanOrEqualTo(height),
        reason: 'the last control is inside the body at $height px',
      );
      for (final tool in SketchTool.values) {
        final rect = tester.getRect(
          find.byTooltip(ToolShortcuts.tooltip(tool)),
        );
        expect(rect.bottom, lessThanOrEqualTo(height));
      }
    }

    testWidgets('at a 1280×720 window (664 px body)', (tester) async {
      await expectFits(tester, 664);
    });

    testWidgets('at a 600 px body', (tester) async {
      await expectFits(tester, 600);
    });

    testWidgets('keeps one tool per row when there is room', (tester) async {
      // A single-column rail is ~870 px with its anchors and actions (the
      // frame and icon tools added two rows); a desktop-height window still
      // gets the source design's one-per-row.
      _laptopWindow(tester, height: 1000);
      final controller = SketchController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(_rail(controller, height: 950));

      // Single-column: every tool button shares one x.
      final lefts = {
        for (final tool in SketchTool.values)
          tester.getRect(find.byTooltip(ToolShortcuts.tooltip(tool))).left,
      };
      expect(lefts, hasLength(1));
    });
  });

  group('tool tooltips', () {
    testWidgets('name the tool and its key, never the enum identifier', (
      tester,
    ) async {
      final controller = SketchController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(_host(controller, tools: SketchTool.values));

      for (final tool in SketchTool.values) {
        expect(
          find.byTooltip(tool.name),
          findsNothing,
          reason: '"${tool.name}" is a Dart identifier, not a label',
        );
        expect(find.byTooltip(ToolShortcuts.tooltip(tool)), findsOneWidget);
      }
      // The reference sheet's wording, plus the key it teaches.
      expect(find.byTooltip('Draw · P'), findsOneWidget);
      expect(find.byTooltip('Sticky note · N'), findsOneWidget);
    });
  });

  group('theme-aware default stroke', () {
    const lightInk = Color(0xFF1E1E1E);
    final darkInk = AppTheme.dark().colorScheme.onSurface;

    testWidgets('a fresh controller on the dark theme draws in onSurface', (
      tester,
    ) async {
      final controller = SketchController();
      addTearDown(controller.dispose);
      expect(
        controller.currentStyle.strokeColor,
        lightInk,
        reason: "the model's own default is the light theme's ink",
      );

      await tester.pumpWidget(_host(controller, theme: AppTheme.dark()));
      await tester.pump();

      expect(controller.currentStyle.strokeColor, darkInk);
      expect(darkInk, isNot(lightInk));
    });

    testWidgets('the default follows a theme toggle, both ways', (
      tester,
    ) async {
      // `MaterialApp` cross-fades between themes, so each switch is settled
      // — the stroke tracks the lerp frame by frame and lands on the exact
      // token at the end.
      final controller = SketchController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(_host(controller, theme: AppTheme.light()));
      await tester.pumpAndSettle();
      expect(controller.currentStyle.strokeColor, lightInk);

      await tester.pumpWidget(_host(controller, theme: AppTheme.dark()));
      await tester.pumpAndSettle();
      expect(controller.currentStyle.strokeColor, darkInk);

      await tester.pumpWidget(_host(controller, theme: AppTheme.light()));
      await tester.pumpAndSettle();
      expect(controller.currentStyle.strokeColor, lightInk);
    });

    testWidgets('a colour the user picked is left alone', (tester) async {
      final controller = SketchController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(_host(controller, theme: AppTheme.light()));
      await tester.pumpAndSettle();
      controller.currentStyle = controller.currentStyle.copyWith(
        strokeColor: stroke,
      );

      await tester.pumpWidget(_host(controller, theme: AppTheme.dark()));
      await tester.pumpAndSettle();

      expect(controller.currentStyle.strokeColor, stroke);
    });

    testWidgets("the palette's first swatch is the theme's ink", (
      tester,
    ) async {
      final controller = SketchController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(_host(controller, theme: AppTheme.dark()));
      await tester.pump();

      await tester.tap(find.byTooltip('Stroke color'));
      await tester.pumpAndSettle();

      final first = tester.widget<Swatch>(find.byType(Swatch).first);
      expect(first.color, darkInk);
      expect(first.current, isTrue, reason: 'it is what is being drawn with');
    });
  });

  group('popovers', () {
    testWidgets('Escape closes the popover instead of deselecting', (
      tester,
    ) async {
      final controller = SketchController(initialElements: [_rect(id: 'a')]);
      addTearDown(controller.dispose);
      controller.select('a');
      await tester.pumpWidget(_host(controller));

      await tester.tap(find.byTooltip('Stroke color'));
      await tester.pumpAndSettle();
      expect(find.byType(PalettePopover), findsOneWidget);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();

      expect(find.byType(PalettePopover), findsNothing);
      expect(controller.selectedIds, {'a'});
    });

    testWidgets('swatches are named controls', (tester) async {
      final controller = SketchController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(_host(controller));

      await tester.tap(find.byTooltip('Stroke color'));
      await tester.pumpAndSettle();

      expect(find.byTooltip('#E03131'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(PalettePopover),
          matching: find.byType(InkWell),
        ),
        findsNWidgets(SketchToolbarRich.defaultPalette.length),
      );
    });

    testWidgets('the stroke-width slider follows a change of selection', (
      tester,
    ) async {
      final controller = SketchController(
        initialElements: [
          SketchRectangle.create(
            id: 'a',
            rect: const Rect.fromLTWH(0, 0, 100, 60),
            style: const SketchStyle(strokeWidth: 6),
          ),
          SketchRectangle.create(
            id: 'b',
            rect: const Rect.fromLTWH(200, 0, 100, 60),
            style: const SketchStyle(strokeWidth: 2),
          ),
        ],
      );
      addTearDown(controller.dispose);
      controller.select('a');
      await tester.pumpWidget(_host(controller));

      await tester.tap(find.byTooltip('Stroke width'));
      await tester.pumpAndSettle();
      expect(find.text('6.0'), findsOneWidget);

      controller.select('b');
      await tester.pumpAndSettle();

      expect(find.text('2.0'), findsOneWidget);
      expect(find.text('6.0'), findsNothing);
    });

    testWidgets('style chips read as words, not identifiers', (tester) async {
      final controller = SketchController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(_host(controller));

      await tester.tap(find.byTooltip('Fill style'));
      await tester.pumpAndSettle();

      expect(find.text('Cross-hatch'), findsOneWidget);
      expect(find.text('crossHatch'), findsNothing);
    });
  });

  testWidgets('Clear says what it did and offers the way back', (tester) async {
    final controller = SketchController(
      initialElements: [
        _rect(id: 'a'),
        _rect(id: 'b', left: 200),
      ],
    );
    addTearDown(controller.dispose);
    await tester.pumpWidget(_host(controller));

    await tester.tap(find.byTooltip('Clear sketches'));
    await tester.pumpAndSettle();

    expect(controller.elements, isEmpty);
    expect(find.text('Cleared 2 elements'), findsOneWidget);

    await tester.tap(find.text('Undo'));
    await tester.pump();

    expect(controller.elements, hasLength(2));
  });

  group('frame and icon tools', () {
    testWidgets('every SketchTool has a rail button', (tester) async {
      _laptopWindow(tester, height: 900);
      final controller = SketchController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(_rail(controller, height: 850));

      for (final tool in SketchTool.values) {
        expect(
          find.byTooltip(ToolShortcuts.tooltip(tool)),
          findsOneWidget,
          reason: tool.name,
        );
      }
    });

    testWidgets('icon popover lists the catalog and picking one selects the '
        'icon tool', (tester) async {
      _laptopWindow(tester, height: 900);
      final controller = SketchController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(_rail(controller, height: 850));

      await tester.tap(find.byTooltip(ToolShortcuts.tooltip(SketchTool.icon)));
      await tester.pumpAndSettle();
      for (final name in iconCatalog.keys) {
        expect(find.byTooltip(name), findsOneWidget, reason: name);
      }

      await tester.tap(find.byTooltip('cloud'));
      await tester.pumpAndSettle();
      expect(controller.currentTool, SketchTool.icon);
      expect(controller.currentIcon, 'cloud');
    });
  });
}
