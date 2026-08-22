import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flowcraft/flowcraft.dart';

import '../support/fake_project_repository.dart';

/// Pure-data stand-in so the card renders "running" without binding a
/// socket — the same shape `mcp_card_test.dart` uses.
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
    sketch.add(SketchRectangle.create(
      id: 'box',
      rect: const Rect.fromLTWH(300, 200, 160, 100),
    ));
  }

  /// Every edit arms the 800 ms autosave debounce; a test that edited has
  /// to let it fire (into the in-memory repository) before the tree is torn
  /// down, or the binding reports the pending timer.
  Future<void> settleAutosave(WidgetTester tester) =>
      tester.pump(const Duration(seconds: 1));

  Future<void> pumpScreen(WidgetTester tester, {Size size = const Size(1280, 720)}) async {
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

  testWidgets('the properties panel and the MCP card never overlap',
      (tester) async {
    // The two used to be anchored independently — panel to the top-right,
    // card to the bottom-right — and met in the middle on any window
    // shorter than ~780 px, with the card painting over the panel's
    // typography dropdown and "Edit JSON" button.
    await pumpScreen(tester);
    addBox();
    sketch.select('box');
    await tester.pump();

    expect(find.text('PROPERTIES'), findsOneWidget);
    expect(find.text('Status: Online'), findsOneWidget);

    final panel = tester.getRect(find.byType(PropertiesPanel));
    final card = tester.getRect(find.byType(McpCard));

    expect(panel.overlaps(card), isFalse,
        reason: 'panel $panel vs card $card');
    expect(panel.bottom, lessThanOrEqualTo(card.top));
    // Both still inside the window, card still pinned to the bottom.
    expect(card.bottom, 720 - AppSpacing.gutter, reason: 'pinned to the bottom');
    expect(panel.top, greaterThanOrEqualTo(56), reason: 'below the app bar');
    await settleAutosave(tester);
  });

  testWidgets("the panel's last control is reachable by scrolling, not hidden",
      (tester) async {
    await pumpScreen(tester);
    addBox();
    sketch.select('box');
    await tester.pump();

    // The panel shrank to fit above the card, so its bottom control may be
    // below the fold — but inside its own scroll view, never under the
    // card.
    // `.first`: the panel's own scroll view, above the text fields' own.
    final scrollable = find
        .descendant(
          of: find.byType(PropertiesPanel),
          matching: find.byType(Scrollable),
        )
        .first;
    await tester.scrollUntilVisible(find.text('Edit JSON'), 200,
        scrollable: scrollable);
    await tester.pump();

    final button = tester.getRect(find.text('Edit JSON'));
    final card = tester.getRect(find.byType(McpCard));
    expect(button.overlaps(card), isFalse);
    await settleAutosave(tester);
  });

  testWidgets('every rail control sits inside the window', (tester) async {
    await pumpScreen(tester);

    for (final tool in SketchTool.values) {
      final rect = tester.getRect(find.byTooltip(ToolShortcuts.tooltip(tool)));
      expect(rect.bottom, lessThanOrEqualTo(720), reason: '$tool');
    }
    expect(tester.getRect(find.byTooltip('Clear sketches')).bottom,
        lessThanOrEqualTo(720));
  });

  testWidgets('a tool key works after Enter in the inline editor',
      (tester) async {
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
