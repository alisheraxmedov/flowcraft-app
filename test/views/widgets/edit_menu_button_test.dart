import 'dart:io';
import 'dart:typed_data';

import 'package:flowcraft/core/theme/fc_tokens.dart';
import 'package:flowcraft/flowcraft.dart';
import 'package:flowcraft/views/widgets/insert_image_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show FontLoader;
import 'package:flutter_test/flutter_test.dart';

SketchRectangle _rect(String id, {double x = 0}) {
  return SketchRectangle.create(id: id, rect: Rect.fromLTWH(x, 0, 10, 10));
}

/// The menu only works inside the layer that supplies its `Actions`, which
/// is exactly how it is mounted in the top bar.
Widget _host(SketchController controller, {double top = 0}) {
  return MaterialApp(
    theme: ThemeData(platform: TargetPlatform.macOS),
    home: Scaffold(
      body: CanvasShortcuts(
        controller: controller,
        child: Align(
          alignment: Alignment.topLeft,
          child: Padding(
            padding: EdgeInsets.only(top: top),
            child: EditMenuButton(controller: controller),
          ),
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

Future<void> _openAlign(WidgetTester tester) async {
  await tester.tap(find.text('Align & distribute'));
  await tester.pumpAndSettle();
}

void main() {
  // The test engine measures with the Ahem box font (1em per glyph) unless
  // the real faces are registered, which would make every label overflow a
  // 224px row that holds it comfortably in Geist.
  setUpAll(() async {
    for (final (family, file) in [
      ('Geist', 'Geist-Regular.ttf'),
      ('Geist', 'Geist-Medium.ttf'),
      ('Geist Mono', 'GeistMono-Regular.ttf'),
    ]) {
      final loader = FontLoader(family)
        ..addFont(
          Future.value(
            ByteData.sublistView(File('assets/fonts/$file').readAsBytesSync()),
          ),
        );
      await loader.load();
    }
  });

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

    // Help's row lives under CANVAS (see EditMenuButton) so the menu fits 720px.
    for (final header in ['EDIT', 'ARRANGE', 'CANVAS']) {
      expect(find.text(header), findsOneWidget, reason: header);
    }
    expect(find.text('HISTORY'), findsNothing);
    expect(find.text('HELP'), findsNothing);
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
    await _openAlign(tester);
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

  testWidgets('Align & distribute submenu lists the 8 actions', (tester) async {
    final controller = SketchController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(_host(controller));
    await _openMenu(tester);
    expect(find.text('Align left'), findsNothing, reason: 'folded away');
    await _openAlign(tester);

    for (final label in [
      'Align left',
      'Align right',
      'Align top',
      'Align bottom',
      'Center horizontally',
      'Center vertically',
      'Distribute horizontally',
      'Distribute vertically',
    ]) {
      expect(find.text(label), findsOneWidget, reason: label);
    }
  });

  testWidgets('Align & distribute row shows a single trailing chevron', (
    tester,
  ) async {
    final controller = SketchController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(_host(controller));
    await _openMenu(tester);

    final row = find.byType(SubmenuButton);
    expect(row, findsOneWidget);
    expect(
      find.descendant(of: row, matching: find.byType(Icon)),
      findsNothing,
      reason: 'no Material arrow_right',
    );
    expect(
      find.descendant(of: row, matching: find.byType(FcIconGlyph)),
      findsOneWidget,
    );
  });

  testWidgets('edit menu fits in 1280x720 without scrolling, Clear canvas '
      'visible', (tester) async {
    final controller = SketchController(initialElements: [_rect('a')]);
    addTearDown(controller.dispose);
    tester.view.physicalSize = const Size(1280, 720);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    // The real pill sits 24px from the top (16 gutter + 1 border + 7).
    await tester.pumpWidget(_host(controller, top: 24));
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();

    for (final label in [
      'Clear canvas',
      'Keyboard shortcuts',
      'Insert image from file…',
    ]) {
      final rect = tester.getRect(find.text(label));
      expect(rect.bottom, lessThanOrEqualTo(712), reason: label);
      expect(rect.top, greaterThanOrEqualTo(0), reason: label);
    }
    final panel = tester.getRect(
      find.ancestor(
        of: find.text('Clear canvas'),
        matching: find.byType(SingleChildScrollView),
      ),
    );
    // No scrolling: the scroll view is exactly as tall as its content.
    final scroll = tester.state<ScrollableState>(
      find.descendant(
        of: find.ancestor(
          of: find.text('Clear canvas'),
          matching: find.byType(SingleChildScrollView),
        ),
        matching: find.byType(Scrollable),
      ),
    );
    expect(scroll.position.maxScrollExtent, 0, reason: 'panel $panel');
    // ...and it did not have to slide up over the Edit pill to fit.
    expect(panel.top, greaterThanOrEqualTo(56), reason: 'panel $panel');
    // Label never truncates next to its hint.
    expect(
      tester.getSize(find.text('Insert image from file…')).width,
      greaterThan(120),
    );
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
