import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flowcraft/flowcraft.dart';
import 'package:flowcraft/views/widgets/insert_image_dialog.dart';

Future<void> _open(WidgetTester tester, SketchController controller) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => InsertImageDialog.show(context, controller),
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

/// The insert does real file I/O and image decoding, which the fake-async
/// test zone never advances on its own.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 20; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pump();
  }
  await tester.pumpAndSettle();
}

void main() {
  late Directory tempDir;
  setUp(() => tempDir = Directory.systemTemp.createTempSync('fc_ins_'));
  tearDown(() => tempDir.deleteSync(recursive: true));

  testWidgets('valid temp PNG path inserts an image below content, selected, '
      'one undo entry', (tester) async {
    final controller = SketchController(
      initialElements: [
        SketchRectangle.create(
          id: 'r',
          rect: const Rect.fromLTWH(20, 10, 100, 100),
        ),
      ],
    );
    addTearDown(controller.dispose);
    final file = File('${tempDir.path}/pic.png');
    await tester.runAsync(() async {
      final recorder = ui.PictureRecorder();
      ui.Canvas(recorder).drawRect(
        const ui.Rect.fromLTWH(0, 0, 3, 2),
        ui.Paint()..color = const ui.Color(0xFFFF0000),
      );
      final image = await recorder.endRecording().toImage(3, 2);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      await file.writeAsBytes(data!.buffer.asUint8List());
    });

    await _open(tester, controller);
    await tester.enterText(find.byType(TextField), file.path);
    await tester.tap(find.text('Insert'));
    await _settle(tester);

    expect(find.byType(InsertImageDialog), findsNothing);
    final image = controller.elements.last as SketchImage;
    expect(image.rect.left, 20);
    expect(image.rect.top, 110 + 48);
    expect(controller.selectedIds, {image.id});
    controller.undo();
    expect(controller.elements, hasLength(1));
  });

  testWidgets('bad path shows inline error and inserts nothing', (
    tester,
  ) async {
    final controller = SketchController();
    addTearDown(controller.dispose);

    await _open(tester, controller);
    await tester.enterText(
      find.byType(TextField),
      '${tempDir.path}/missing.png',
    );
    await tester.tap(find.text('Insert'));
    await _settle(tester);

    expect(find.textContaining('does not exist'), findsOneWidget);
    expect(find.byType(InsertImageDialog), findsOneWidget);
    expect(controller.elements, isEmpty);
  });
}
