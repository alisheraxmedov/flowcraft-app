import 'dart:io';

import 'package:flowcraft/flowcraft.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

SketchRectangle _rect(String id) {
  return SketchRectangle.create(
    id: id,
    rect: const Rect.fromLTWH(0, 0, 10, 10),
  );
}

void main() {
  late Directory tempDir;
  late SketchController controller;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('fc_import_dialog_');
    controller = SketchController(initialElements: [_rect('on-canvas')]);
  });

  tearDown(() {
    controller.dispose();
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  File plant(String name, String contents) {
    return File('${tempDir.path}${Platform.pathSeparator}$name')
      ..writeAsStringSync(contents);
  }

  /// Opens the dialog and waits for its (real, `dart:io`) directory listing.
  ///
  /// Everything runs inside [WidgetTester.runAsync] because this dialog does
  /// genuine file I/O, which the fake-async clock a widget test normally
  /// runs under never completes.
  Future<void> open(WidgetTester tester) async {
    await tester.runAsync(() async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => ImportSceneDialog.show(
                  context,
                  controller,
                  directoryPath: tempDir.path,
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pump();
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await tester.pump();
    });
  }

  Future<void> tap(WidgetTester tester, Finder finder) async {
    await tester.runAsync(() async {
      await tester.tap(finder);
      await tester.pump();
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await tester.pump();
    });
  }

  testWidgets('lists the scenes in the export folder and imports the pick', (
    tester,
  ) async {
    plant('board.flowcraft.json', SketchSerializer.serialize([_rect('a')]));

    await open(tester);
    expect(find.text('board.flowcraft.json'), findsOneWidget);

    await tap(tester, find.text('board.flowcraft.json'));
    await tap(tester, find.text('Add to canvas'));

    expect(controller.elements, hasLength(2));
    expect(find.byType(ImportSceneDialog), findsNothing);
  });

  testWidgets('replacing swaps the canvas for the file', (tester) async {
    plant('board.json', SketchSerializer.serialize([_rect('a'), _rect('b')]));

    await open(tester);
    await tap(tester, find.text('board.json'));
    await tap(tester, find.text('Replace canvas'));

    expect(controller.elements, hasLength(2));
    expect(controller.elements.map((e) => e.id), ['a', 'b']);
  });

  testWidgets('an empty folder points at the paste route instead', (
    tester,
  ) async {
    await open(tester);

    expect(find.textContaining('No .json files here yet'), findsOneWidget);
    // Nothing picked, so neither import button is live.
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );
  });

  testWidgets('a typed path reaches a file outside the export folder', (
    tester,
  ) async {
    final elsewhere = Directory.systemTemp.createTempSync('fc_elsewhere_');
    addTearDown(() => elsewhere.deleteSync(recursive: true));
    final file = File('${elsewhere.path}${Platform.pathSeparator}sent.json')
      ..writeAsStringSync(SketchSerializer.serialize([_rect('from-a-friend')]));

    await open(tester);
    await tester.runAsync(() async {
      await tester.enterText(find.byType(TextField), file.path);
      await tester.pump();
    });
    await tap(tester, find.text('Add to canvas'));

    expect(controller.elements, hasLength(2));
  });

  testWidgets('dismissing the dialog mid-read leaves the canvas alone', (
    tester,
  ) async {
    // Cancel is disabled while busy, but Escape and the barrier still pop
    // the dialog. The import used to land on the canvas anyway once the
    // read finished — silently, since there was no dialog left to report
    // from.
    plant('board.json', SketchSerializer.serialize([_rect('a'), _rect('b')]));

    await open(tester);
    await tap(tester, find.text('board.json'));

    await tester.runAsync(() async {
      // No event-loop turn between the tap and the pop: the file read is
      // real I/O, which completes only once the loop runs, so the dialog
      // is gone before the bytes arrive.
      await tester.tap(find.text('Replace canvas'));
      Navigator.of(tester.element(find.byType(ImportSceneDialog))).pop();
      await tester.pump();
      await Future<void>.delayed(const Duration(milliseconds: 100));
      await tester.pump();
    });

    expect(find.byType(ImportSceneDialog), findsNothing);
    expect(controller.elements.map((e) => e.id), ['on-canvas']);
    expect(tester.takeException(), isNull);
  });

  testWidgets('an unreadable file keeps the dialog open with the reason', (
    tester,
  ) async {
    plant('broken.json', 'not json at all');

    await open(tester);
    await tap(tester, find.text('broken.json'));
    await tap(tester, find.text('Add to canvas'));

    expect(find.byType(ImportSceneDialog), findsOneWidget);
    expect(find.text('That file is not valid JSON.'), findsOneWidget);
    expect(controller.elements, hasLength(1));
  });
}
