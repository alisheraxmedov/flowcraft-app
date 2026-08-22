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
}
