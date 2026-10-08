import 'package:flowcraft/core/theme/fc_tokens.dart';
import 'package:flowcraft/flowcraft.dart';
import 'package:flowcraft/views/widgets/insert_image_dialog.dart';
import 'package:flutter/material.dart';
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

    Finder hint(String label, String keys) => find.descendant(
      of: find.ancestor(
        of: find.text(label),
        matching: find.byType(MenuItemButton),
      ),
      matching: find.text(keys),
    );
    expect(hint('Duplicate', '⌘D'), findsOneWidget);
    expect(hint('Bring to front', '⇧⌘]'), findsOneWidget);
  });

  testWidgets('groups carry mockup headers and no History group', (
    tester,
  ) async {
    final controller = SketchController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(_host(controller));
    await _openMenu(tester);

    for (final header in ['EDIT', 'ARRANGE', 'CANVAS', 'HELP']) {
      expect(find.text(header), findsOneWidget, reason: header);
    }
    expect(find.text('HISTORY'), findsNothing);
    final copy = find.ancestor(
      of: find.text('Copy'),
      matching: find.byType(MenuItemButton),
    );
    expect(tester.getSize(copy).height, 30, reason: 'mockup rows are h30');
  });

  testWidgets('has no Undo / Redo items — the bottom island owns them', (
    tester,
  ) async {
    final controller = SketchController(initialElements: [_rect('a')]);
    addTearDown(controller.dispose);
    controller.add(_rect('b'));

    await tester.pumpWidget(_host(controller));
    await _openMenu(tester);

    expect(controller.canUndo, isTrue);
    expect(find.text('Undo'), findsNothing);
    expect(find.text('Redo'), findsNothing);
  });

  testWidgets('Clear canvas clears, and the snackbar offers Undo', (
    tester,
  ) async {
    final controller = SketchController(
      initialElements: [_rect('a'), _rect('b', x: 20)],
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(_host(controller));
    await _openMenu(tester);
    await tester.tap(find.text('Clear canvas'));
    await tester.pumpAndSettle();

    expect(controller.elements, isEmpty);
    expect(find.text('Cleared 2 elements'), findsOneWidget);

    await tester.tap(find.text('Undo'));
    await tester.pump();

    expect(controller.elements, hasLength(2));
  });

  testWidgets('Clear canvas is danger-coloured and disabled when empty', (
    tester,
  ) async {
    final controller = SketchController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(_host(controller));
    await _openMenu(tester);

    expect(_item(tester, 'Clear canvas').onPressed, isNull);

    controller.add(_rect('a'));
    await tester.pump();
    expect(_item(tester, 'Clear canvas').onPressed, isNotNull);

    final text = tester.widget<Text>(find.text('Clear canvas'));
    final style = DefaultTextStyle.of(
      tester.element(find.text('Clear canvas')),
    );
    expect(
      (text.style?.color ?? style.style.color),
      FcTokens.light.danger,
      reason: 'the label is painted in the danger token',
    );
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

  testWidgets('align and distribute wait for 2 and 3 selected shapes', (
    tester,
  ) async {
    final controller = SketchController(
      initialElements: [_rect('a'), _rect('b', x: 20), _rect('c', x: 40)],
    );
    addTearDown(controller.dispose);
    controller.select('a');

    await tester.pumpWidget(_host(controller));
    await _openMenu(tester);
    expect(_item(tester, 'Align left').onPressed, isNull);
    expect(_item(tester, 'Distribute horizontally').onPressed, isNull);

    controller.selectMany(['a', 'b']);
    await tester.pump();
    expect(_item(tester, 'Align left').onPressed, isNotNull);
    expect(_item(tester, 'Distribute horizontally').onPressed, isNull);

    controller.selectMany(['a', 'b', 'c']);
    await tester.pump();
    expect(_item(tester, 'Distribute horizontally').onPressed, isNotNull);
  });

  testWidgets('zoom to fit is disabled on an empty canvas', (tester) async {
    final controller = SketchController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(_host(controller));
    await _openMenu(tester);
    expect(_item(tester, 'Zoom to fit').onPressed, isNull);

    controller.add(_rect('a'));
    await tester.pump();
    expect(_item(tester, 'Zoom to fit').onPressed, isNotNull);
  });

  testWidgets('Insert image from file… opens the dialog', (tester) async {
    final controller = SketchController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(_host(controller));
    await _openMenu(tester);
    await tester.tap(find.text('Insert image from file…'));
    await tester.pumpAndSettle();

    expect(find.byType(InsertImageDialog), findsOneWidget);
  });
}
