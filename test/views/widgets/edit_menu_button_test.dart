import 'package:flowcraft/flowcraft.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

SketchRectangle _rect(String id, {double x = 0}) {
  return SketchRectangle.create(id: id, rect: Rect.fromLTWH(x, 0, 10, 10));
}

/// The menu only works inside the layer that supplies its `Actions`, which
/// is exactly how it is mounted in the top bar.
Widget _host(SketchController controller) {
  return MaterialApp(
    theme: ThemeData(platform: TargetPlatform.macOS),
    home: Scaffold(
      body: CanvasShortcuts(
        controller: controller,
        child: Align(
          alignment: Alignment.topLeft,
          child: EditMenuButton(controller: controller),
        ),
      ),
    ),
  );
}

MenuItemButton _item(WidgetTester tester, String label) {
  return tester.widget<MenuItemButton>(
    find.ancestor(of: find.text(label), matching: find.byType(MenuItemButton)),
  );
}

Future<void> _openMenu(WidgetTester tester) async {
  // A desktop Edit menu is ~16 items tall; the default 800×600 test surface
  // pushes the last of them past the bottom of the (scrollable) menu panel,
  // where `tap` can't reach them.
  tester.view.physicalSize = const Size(1200, 1400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpAndSettle();

  await tester.tap(find.text('Edit'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('runs the same action the keystroke does', (tester) async {
    final controller = SketchController(initialElements: [_rect('a')]);
    addTearDown(controller.dispose);
    controller.select('a');

    await tester.pumpWidget(_host(controller));
    await _openMenu(tester);
    await tester.tap(find.text('Duplicate'));
    await tester.pumpAndSettle();

    expect(controller.elements, hasLength(2));
  });

  testWidgets('prints each command\'s real key beside it', (tester) async {
    // The menu is how people discover the shortcuts, so the hint has to be
    // the binding that is actually live — hence both come from one table.
    final controller = SketchController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(_host(controller));
    await _openMenu(tester);

    // Compared field by field: `SingleActivator` has no `==`, so two
    // identical activators are never equal objects.
    final duplicate = _item(tester, 'Duplicate').shortcut! as SingleActivator;
    expect(duplicate.trigger, LogicalKeyboardKey.keyD);
    expect(duplicate.meta, isTrue);
    expect(duplicate.control, isFalse, reason: 'macOS uses Cmd, not Ctrl');

    final front = _item(tester, 'Bring to front').shortcut! as SingleActivator;
    expect(front.trigger, LogicalKeyboardKey.bracketRight);
    expect(front.meta, isTrue);
    expect(front.shift, isTrue);
  });

  testWidgets('greys out what a selectionless canvas cannot do', (
    tester,
  ) async {
    final controller = SketchController(initialElements: [_rect('a')]);
    addTearDown(controller.dispose);

    await tester.pumpWidget(_host(controller));
    await _openMenu(tester);

    expect(_item(tester, 'Copy').onPressed, isNull);
    expect(_item(tester, 'Group').onPressed, isNull);
    expect(_item(tester, 'Undo').onPressed, isNull);
    // Always available: they are how a selection gets made in the first
    // place, and how a scene arrives.
    expect(_item(tester, 'Select all').onPressed, isNotNull);
    expect(_item(tester, 'Paste').onPressed, isNotNull);
  });

  testWidgets('wakes up as soon as something is selected', (tester) async {
    final controller = SketchController(initialElements: [_rect('a')]);
    addTearDown(controller.dispose);

    await tester.pumpWidget(_host(controller));
    controller.select('a');
    await tester.pump();
    await _openMenu(tester);

    expect(_item(tester, 'Copy').onPressed, isNotNull);
  });

  testWidgets('offers the reference sheet, since ? is unguessable', (
    tester,
  ) async {
    final controller = SketchController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(_host(controller));
    await _openMenu(tester);
    await tester.tap(find.text('Keyboard shortcuts'));
    await tester.pumpAndSettle();

    expect(find.byType(ShortcutsHelpDialog), findsOneWidget);
  });

  testWidgets('leaves the tool keys out — the tool rail already has them', (
    tester,
  ) async {
    final controller = SketchController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(_host(controller));
    await _openMenu(tester);

    expect(find.text('Rectangle'), findsNothing);
    expect(find.text('Nudge'), findsNothing);
  });
}
