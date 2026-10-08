import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flowcraft/flowcraft.dart';

import '../support/fake_project_repository.dart';

/// Pure-data stand-in so the card renders "running" without binding a
/// socket — the same shape `agents_popover_test.dart` uses.
class _FakeMcpViewModel extends McpViewModel {
  _FakeMcpViewModel(this.initial);

  final McpServerStatus initial;

  @override
  McpServerStatus build() => initial;

  @override
  void toggle() {}

  @override
  void retry() {}
}

/// The screen that composes everything, at a laptop window size. Every
/// other test pumps it (if at all) on the default 800×600 surface and asks
/// only whether things exist; the layout bugs live at 1280×720.
void main() {
  const running = McpServerStatus.running(port: 5199, token: 'test-token');

  late SketchController sketch;

  setUp(() => sketch = SketchController());

  tearDown(() => sketch.dispose());

  /// Added only once the screen is up: the projects view model restores a
  /// project on start and `loadScene`s it, which would wipe anything seeded
  /// into the controller beforehand.
  ///
  void addBox() {
    sketch.add(
      SketchRectangle.create(
        id: 'box',
        rect: const Rect.fromLTWH(300, 200, 160, 100),
      ),
    );
  }

  /// Every edit arms the 800 ms autosave debounce; a test that edited has
  /// to let it fire (into the in-memory repository) before the tree is torn
  /// down, or the binding reports the pending timer.
  Future<void> settleAutosave(WidgetTester tester) =>
      tester.pump(const Duration(seconds: 1));

  Future<void> pumpScreen(
    WidgetTester tester, {
    Size size = const Size(1280, 720),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          // Port 0 even though the view model is faked below: reading
          // `mcpViewModelProvider` anywhere else would start a real server,
          // and a fixed port races parallel test files.
          mcpServerPortProvider.overrideWithValue(0),
          mcpViewModelProvider.overrideWith(() => _FakeMcpViewModel(running)),
          projectRepositoryProvider.overrideWithValue(FakeProjectRepository()),
          sketchControllerProvider.overrideWithValue(sketch),
        ],
        child: MaterialApp(
          theme: AppTheme.dark(),
          home: const WhiteboardView(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
  }

  testWidgets('the inspector sits at (16, 80) inside the window', (
    tester,
  ) async {
    await pumpScreen(tester);
    addBox();
    sketch.select('box');
    await tester.pump();

    final panel = tester.getRect(find.byType(PropertiesPanel));
    // Aligned top-left, not stretched down to the bottom gutter.
    expect(panel.topLeft, const Offset(16, 80));
    expect(panel.width, 264);
    expect(
      const Rect.fromLTWH(0, 0, 1280, 720).contains(panel.bottomRight),
      isTrue,
      reason: '$panel',
    );
    await settleAutosave(tester);
  });

  testWidgets("the inspector's last control is reachable by scrolling", (
    tester,
  ) async {
    await pumpScreen(tester, size: const Size(1280, 480));
    addBox();
    sketch.select('box');
    await tester.pump();

    // `.first`: the panel's own scroll view, above the text fields' own.
    final scrollable = find
        .descendant(
          of: find.byType(PropertiesPanel),
          matching: find.byType(Scrollable),
        )
        .first;
    await tester.scrollUntilVisible(
      find.text('Edit JSON'),
      200,
      scrollable: scrollable,
    );
    await tester.pump();

    expect(
      tester.getRect(find.text('Edit JSON')).bottom,
      lessThanOrEqualTo(480 - AppSpacing.gutter),
    );
    await settleAutosave(tester);
  });

  testWidgets('every tool sits inside the window', (tester) async {
    await pumpScreen(tester);

    const window = Rect.fromLTWH(0, 0, 1280, 720);
    for (final tool in SketchTool.values) {
      // The tooltip is rich (name + key chip): its plain text is "Name￼".
      final rect = tester.getRect(
        find.byTooltip(
          RegExp('^${RegExp.escape(ToolShortcuts.labels[tool]!)}￼\$'),
        ),
      );
      expect(window.contains(rect.topLeft), isTrue, reason: '$tool $rect');
      expect(window.contains(rect.bottomRight), isTrue, reason: '$tool $rect');
    }
  });

  testWidgets('Undo, Redo, Grid and Theme each exist exactly once', (
    tester,
  ) async {
    await pumpScreen(tester);

    for (final tooltip in ['Undo', 'Redo', 'Hide grid', 'Dark mode']) {
      expect(find.byTooltip(tooltip), findsOneWidget, reason: tooltip);
    }
  });

  testWidgets('Undo follows the history; Redo gives the edit back', (
    tester,
  ) async {
    await pumpScreen(tester);
    addBox();
    await tester.pump();

    await tester.tap(find.byTooltip('Undo'));
    await tester.pump();
    expect(sketch.elements.any((e) => e.id == 'box'), isFalse);

    await tester.tap(find.byTooltip('Redo'));
    await tester.pump();
    expect(sketch.elements.any((e) => e.id == 'box'), isTrue);
    await settleAutosave(tester);
  });

  testWidgets(
    'no Delete selected or Clear sketches controls; the Edit menu has no Undo',
    (tester) async {
      await pumpScreen(tester);
      addBox();
      sketch.select('box');
      await tester.pump();

      expect(find.byTooltip('Delete selected'), findsNothing);
      expect(find.byTooltip('Clear sketches'), findsNothing);

      await tester.tap(find.text('Edit'));
      await tester.pumpAndSettle();

      expect(find.text('Undo'), findsNothing);
      expect(find.text('Redo'), findsNothing);
      // Delete and Clear live in the menu, once each.
      expect(find.text('Delete'), findsOneWidget);
      expect(find.text('Clear canvas'), findsOneWidget);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      await settleAutosave(tester);
    },
  );

  testWidgets('the Agents chip opens the popover with the server status', (
    tester,
  ) async {
    await pumpScreen(tester);
    expect(find.text('Online'), findsNothing);

    await tester.tap(find.text('Agents'));
    await tester.pumpAndSettle();

    expect(find.text('Online'), findsOneWidget);
  });

  testWidgets('a tool key works after Enter in the inline editor', (
    tester,
  ) async {
    await pumpScreen(tester);
    addBox();
    sketch.beginTextEdit(elementId: 'box');
    await tester.pump();
    await tester.pump();
    expect(
      find.descendant(
        of: find.byType(SketchTextEditor),
        matching: find.byType(EditableText),
      ),
      findsOneWidget,
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(sketch.editingElementId, isNull);

    await tester.sendKeyEvent(LogicalKeyboardKey.keyR);
    await tester.pump();

    expect(sketch.currentTool, SketchTool.rectangle);
    await settleAutosave(tester);
  });
}
