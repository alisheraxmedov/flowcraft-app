import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flowcraft/flowcraft.dart';
import 'package:flowcraft/core/theme/canvas_ink.dart';
import 'package:flowcraft/core/theme/fc_tokens.dart';
import 'package:flowcraft/models/icon_catalog.dart';
import 'package:flowcraft/views/widgets/toolbar/tool_button.dart';

/// The tool tooltip is rich (name + a key chip), so its plain text is the
/// name followed by the chip's placeholder character, not "Name · K".
Finder _tool(SketchTool tool) =>
    find.byTooltip(RegExp('^${RegExp.escape(ToolShortcuts.labels[tool]!)}￼\$'));

Widget _host(
  SketchController controller, {
  ThemeData? theme,
  List<SketchTool>? tools,
  double? width,
}) {
  final bar = tools == null
      ? SketchToolbarRich(controller: controller)
      : SketchToolbarRich(controller: controller, tools: tools);
  return MaterialApp(
    theme: theme,
    home: Scaffold(
      body: Align(
        alignment: Alignment.topLeft,
        child: width == null ? bar : SizedBox(width: width, child: bar),
      ),
    ),
  );
}

/// Sizes the test surface like a laptop window, restored on teardown.
void _laptopWindow(WidgetTester tester, {double height = 720}) {
  tester.view.physicalSize = Size(1280, height);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  group('the tool pill', () {
    testWidgets('is 52 high with 40x40 tool buttons, and fits 1280', (
      tester,
    ) async {
      _laptopWindow(tester);
      final controller = SketchController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(_host(controller));

      expect(tester.getSize(find.byType(SketchToolbarRich)).height, 52);
      final scrollable = tester.state<ScrollableState>(
        find.descendant(
          of: find.byType(SketchToolbarRich),
          matching: find.byType(Scrollable),
        ),
      );
      expect(scrollable.position.maxScrollExtent, 0);

      for (final tool in SketchTool.values) {
        final rect = tester.getRect(_tool(tool));
        expect(rect.size, const Size.square(40), reason: tool.name);
        expect(rect.right, lessThanOrEqualTo(1280), reason: tool.name);
      }
    });

    testWidgets('scrolls instead of overflowing when the window is narrow', (
      tester,
    ) async {
      _laptopWindow(tester);
      final controller = SketchController();
      addTearDown(controller.dispose);
      // Roughly what a 900px window leaves the Expanded slot between the
      // top-left and top-right islands.
      await tester.pumpWidget(_host(controller, width: 300));

      final scrollable = tester.state<ScrollableState>(
        find.descendant(
          of: find.byType(SketchToolbarRich),
          matching: find.byType(Scrollable),
        ),
      );
      expect(scrollable.position.maxScrollExtent, greaterThan(0));
      expect(tester.takeException(), isNull);
    });

    testWidgets('has no style, undo/redo or clear controls any more', (
      tester,
    ) async {
      final controller = SketchController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(_host(controller));

      for (final tooltip in [
        'Stroke color',
        'Fill color',
        'Stroke width',
        'Roughness',
        'Stroke style',
        'Fill style',
        'Undo',
        'Redo',
        'Clear sketches',
      ]) {
        expect(find.byTooltip(tooltip), findsNothing, reason: tooltip);
      }
    });

    testWidgets('the selected tool is the raised accent-text chip', (
      tester,
    ) async {
      final controller = SketchController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(_host(controller));

      final t = FcTokens.light;
      Color glyphColor(SketchTool tool) => tester
          .widget<FcIconGlyph>(
            find.descendant(
              of: find.ancestor(
                of: _tool(tool),
                matching: find.byType(ToolButton),
              ),
              matching: find.byType(FcIconGlyph),
            ),
          )
          .color!;

      expect(controller.currentTool, SketchTool.select);
      expect(glyphColor(SketchTool.select), t.accentText);
      expect(glyphColor(SketchTool.hand), t.text);

      await tester.tap(_tool(SketchTool.hand));
      await tester.pumpAndSettle();
      expect(controller.currentTool, SketchTool.hand);
      expect(glyphColor(SketchTool.hand), t.accentText);
      expect(glyphColor(SketchTool.select), t.text);
    });

    testWidgets('draws the mockup eraser, not the Material Symbols one', (
      tester,
    ) async {
      final controller = SketchController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(_host(controller));

      expect(toolIcons[SketchTool.eraser], same(FcIcons.eraser));
      expect(
        find.descendant(
          of: find.byType(SketchToolbarRich),
          matching: find.byType(Icon),
        ),
        findsNothing,
        reason: 'every tool glyph is an FcIconGlyph; no Material Icon left',
      );
    });
  });

  group('tool tooltips', () {
    testWidgets('name the tool and show its key as a chip', (tester) async {
      final controller = SketchController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(_host(controller));

      for (final tool in SketchTool.values) {
        expect(
          find.byTooltip(tool.name),
          findsNothing,
          reason: '"${tool.name}" is a Dart identifier, not a label',
        );
        expect(_tool(tool), findsOneWidget, reason: tool.name);
      }

      // Hover Rectangle: the tooltip shows "Rectangle" and a chip "R".
      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      addTearDown(gesture.removePointer);
      await gesture.addPointer(location: Offset.zero);
      await gesture.moveTo(tester.getCenter(_tool(SketchTool.rectangle)));
      await tester.pump(const Duration(seconds: 2));
      await tester.pump();

      expect(
        find.textContaining('Rectangle', findRichText: true),
        findsOneWidget,
      );
      expect(find.text('R'), findsOneWidget);
    });
  });

  group('theme-aware default stroke', () {
    const light = Color(0xFF1E1E1E);
    final darkInk = inkFor(Brightness.dark);

    testWidgets('a fresh controller on the dark theme draws in the dark ink', (
      tester,
    ) async {
      final controller = SketchController();
      addTearDown(controller.dispose);
      expect(
        controller.currentStyle.strokeColor,
        light,
        reason: "the model's own default is the light theme's ink",
      );

      await tester.pumpWidget(_host(controller, theme: AppTheme.dark()));
      await tester.pump();

      expect(controller.currentStyle.strokeColor, darkInk);
      expect(darkInk, isNot(light));
    });

    testWidgets('the default follows a theme toggle, both ways', (
      tester,
    ) async {
      // `MaterialApp` cross-fades between themes, so each switch is settled.
      final controller = SketchController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(_host(controller, theme: AppTheme.light()));
      await tester.pumpAndSettle();
      expect(controller.currentStyle.strokeColor, light);

      await tester.pumpWidget(_host(controller, theme: AppTheme.dark()));
      await tester.pumpAndSettle();
      expect(controller.currentStyle.strokeColor, darkInk);

      await tester.pumpWidget(_host(controller, theme: AppTheme.light()));
      await tester.pumpAndSettle();
      expect(controller.currentStyle.strokeColor, light);
    });

    testWidgets('a colour the user picked is left alone', (tester) async {
      final controller = SketchController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(_host(controller, theme: AppTheme.light()));
      await tester.pumpAndSettle();
      const red = Color(0xFFE03131);
      controller.currentStyle = controller.currentStyle.copyWith(
        strokeColor: red,
      );

      await tester.pumpWidget(_host(controller, theme: AppTheme.dark()));
      await tester.pumpAndSettle();

      expect(controller.currentStyle.strokeColor, red);
    });
  });

  group('frame and icon tools', () {
    testWidgets('every SketchTool has a pill button', (tester) async {
      _laptopWindow(tester);
      final controller = SketchController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(_host(controller));

      for (final tool in SketchTool.values) {
        expect(_tool(tool), findsOneWidget, reason: tool.name);
      }
    });

    testWidgets('icon popover lists the catalog and picking one selects the '
        'icon tool', (tester) async {
      _laptopWindow(tester);
      final controller = SketchController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(_host(controller));

      await tester.tap(_tool(SketchTool.icon));
      await tester.pumpAndSettle();
      for (final name in iconCatalog.keys) {
        expect(find.byTooltip(name), findsOneWidget, reason: name);
      }

      await tester.tap(find.byTooltip('cloud'));
      await tester.pumpAndSettle();
      expect(controller.currentTool, SketchTool.icon);
      expect(controller.currentIcon, 'cloud');
      expect(find.byTooltip('cloud'), findsNothing, reason: 'closed on pick');
    });
  });
}
