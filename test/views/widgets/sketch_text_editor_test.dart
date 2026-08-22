import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flowcraft/flowcraft.dart';

/// The editor overlay used to pin its *outer* box to the element's origin
/// and then inset the glyphs by its own padding and border, so the text
/// visibly jumped a few pixels the instant editing started and jumped back
/// on commit. The box is now offset by that chrome, putting the editable
/// glyphs exactly where `SketchPainter` draws the committed ones.
Widget _host(SketchController controller) {
  return MaterialApp(
    home: Scaffold(
      body: Stack(
        children: [
          SketchTextEditor(
            controller: controller,
            viewport: const FlowViewport(),
          ),
        ],
      ),
    ),
  );
}

/// The editor's decorated box — the thing that either grows with its text
/// (a note) or stays put (a shape). `EditableText` itself grows inside a
/// fixed box too, up to the box's cap, so it is the wrong thing to measure.
Finder _composer() => find.ancestor(
      of: find.byType(EditableText),
      matching: find.byType(Container),
    );

void main() {
  testWidgets('a SketchText edits in place, on its own position',
      (tester) async {
    final controller = SketchController();
    addTearDown(controller.dispose);
    controller.add(SketchText.create(
      id: 'greeting',
      position: const Offset(120, 60),
      text: 'Hello',
      fontSize: 16,
    ));

    await tester.pumpWidget(_host(controller));
    controller.beginTextEdit(elementId: 'greeting');
    await tester.pump();

    // The painter draws this element's glyphs from `position`; so must the
    // editor.
    expect(tester.getTopLeft(find.byType(EditableText)), const Offset(120, 60));
  });

  testWidgets('a SketchText edits in its own font family', (tester) async {
    final controller = SketchController();
    addTearDown(controller.dispose);
    controller.add(SketchText.create(
      id: 'mono',
      position: Offset.zero,
      text: 'Hello',
      fontSize: 16,
      fontFamily: 'JetBrains Mono',
    ));

    await tester.pumpWidget(_host(controller));
    controller.beginTextEdit(elementId: 'mono');
    await tester.pump();

    // The painter honours `fontFamily`; without it here the glyphs reflow
    // the instant the edit ends.
    final editable = tester.widget<EditableText>(find.byType(EditableText));
    expect(editable.style.fontFamily, 'JetBrains Mono');
  });

  testWidgets("a shape's label edits over the shape's own bounds",
      (tester) async {
    final controller = SketchController();
    addTearDown(controller.dispose);
    controller.add(SketchRectangle.create(
      id: 'box',
      rect: const Rect.fromLTWH(40, 80, 160, 100),
      text: 'Label',
    ));

    await tester.pumpWidget(_host(controller));
    controller.beginTextEdit(elementId: 'box');
    await tester.pump();

    // A centred label stays centred only if the editor's content box lines
    // up with the shape's bounds rather than being shrunk by its chrome.
    final content = tester.getRect(find.byType(EditableText));
    expect(content.left, 40);
    expect(content.width, 160);
    expect(content.center.dy, 130);
  });

  testWidgets("a note's label edits inside the bubble's own text box",
      (tester) async {
    const rect = Rect.fromLTWH(60, 120, 200, 100);
    final controller = SketchController();
    addTearDown(controller.dispose);
    controller.add(SketchSticky.create(
      id: 'note',
      rect: rect,
      text: 'remember this',
    ));

    await tester.pumpWidget(_host(controller));
    controller.beginTextEdit(elementId: 'note');
    await tester.pump();

    // Compared against the shared geometry rather than against numbers typed
    // in here: `SketchPainter._drawStickyLabel` lays the committed label out
    // from this same call, so agreeing with it is the property that stops the
    // glyphs jumping when editing starts. A hardcoded expectation would go
    // stale the moment the bubble's padding changed, which is exactly the
    // drift this pins.
    final expected = StickyBubbleGeometry.textBoxOf(rect);
    final content = tester.getRect(find.byType(EditableText));
    expect(content.topLeft, expected.topLeft);
    expect(content.width, expected.width);
  });

  testWidgets('a small note edits inside the padding it actually has',
      (tester) async {
    // The bubble's padding is not a constant: on a note too small to give up
    // 8px on every side it shrinks so there is still a box left to write in.
    // An editor carrying its own copy of "inset by 8" agrees with the
    // painter on a large note by luck and drifts on this one, which is why
    // the assertion is against the shared source rather than a number.
    const rect = Rect.fromLTWH(10, 10, 40, 30);
    final controller = SketchController();
    addTearDown(controller.dispose);
    controller.add(SketchSticky.create(id: 'note', rect: rect, text: 'hi'));

    await tester.pumpWidget(_host(controller));
    controller.beginTextEdit(elementId: 'note');
    await tester.pump();

    final expected = StickyBubbleGeometry.textBoxOf(rect);
    expect(expected.topLeft, isNot(rect.deflate(8.0).topLeft),
        reason: 'the two formulas have to disagree for this to prove anything');

    final content = tester.getRect(find.byType(EditableText));
    expect(content.left, moreOrLessEquals(expected.left, epsilon: 0.01));
    expect(content.top, moreOrLessEquals(expected.top, epsilon: 0.01));
    // Width is deliberately not asserted: the editor floors its box at 60px
    // so a narrow note still has somewhere to type.
  });

  testWidgets("a note's composer grows as lines are typed", (tester) async {
    // The bubble grows to fit on commit; if the editor did not grow while
    // typing, the third line would scroll out of sight inside a box sized
    // for two.
    const rect = Rect.fromLTWH(60, 120, 180, 72);
    final controller = SketchController();
    addTearDown(controller.dispose);
    controller.add(SketchSticky.create(id: 'note', rect: rect, text: 'one'));

    await tester.pumpWidget(_host(controller));
    controller.beginTextEdit(elementId: 'note');
    await tester.pump();

    final before = tester.getRect(_composer());
    await tester.enterText(
      find.byType(EditableText),
      'one\ntwo\nthree\nfour\nfive\nsix',
    );
    await tester.pump();
    final after = tester.getRect(_composer());

    expect(after.top, before.top, reason: 'anchored where it was');
    expect(after.height, greaterThan(before.height));
  });

  testWidgets("a shape's composer keeps its fixed box", (tester) async {
    // The mirror of the above: a centred label needs a fixed box to be
    // centred in.
    final controller = SketchController();
    addTearDown(controller.dispose);
    controller.add(SketchRectangle.create(
      id: 'box',
      rect: const Rect.fromLTWH(40, 80, 160, 100),
      text: 'Label',
    ));

    await tester.pumpWidget(_host(controller));
    controller.beginTextEdit(elementId: 'box');
    await tester.pump();

    final before = tester.getRect(_composer());
    await tester.enterText(
      find.byType(EditableText),
      'one\ntwo\nthree\nfour\nfive\nsix\nseven\neight',
    );
    await tester.pump();
    expect(tester.getRect(_composer()).height, before.height);
  });

  testWidgets("a note's editable glyphs are legible against its paper",
      (tester) async {
    // A sticky's stroke colour *is* its paper colour, so editing in it used
    // to mean typing pale yellow onto pale yellow.
    final controller = SketchController();
    addTearDown(controller.dispose);
    final note = SketchSticky.create(
      id: 'note',
      rect: const Rect.fromLTWH(0, 0, 200, 100),
    );
    controller.add(note);

    await tester.pumpWidget(_host(controller));
    controller.beginTextEdit(elementId: 'note');
    await tester.pump();

    final editable = tester.widget<EditableText>(find.byType(EditableText));
    expect(editable.style.color, note.inkColor);
    expect(editable.style.color, isNot(note.style.fillColor));
  });
}
