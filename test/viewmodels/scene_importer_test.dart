import 'dart:convert';

import 'package:flowcraft/flowcraft.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

SketchRectangle _rect(String id, {double x = 0}) {
  return SketchRectangle.create(id: id, rect: Rect.fromLTWH(x, 0, 10, 10));
}

String _scene(List<SketchElement> elements) =>
    SketchSerializer.serialize(elements);

/// Fails the test if the importer hands the raw text back to be parsed a
/// second time, and counts what it hands over instead.
class _SpyController extends SketchController {
  _SpyController() : super(initialElements: [_rect('on-canvas')]);

  int pastedBatches = 0;

  @override
  int pasteFromJson(String json, {Offset? offset}) {
    fail('add mode must paste the already-decoded elements, not re-parse');
  }

  @override
  int pasteElements(List<SketchElement> elements, {Offset? offset}) {
    pastedBatches++;
    return super.pasteElements(elements, offset: offset);
  }
}

void main() {
  late SketchController controller;

  setUp(() => controller = SketchController(initialElements: [_rect('on-canvas')]));
  tearDown(() => controller.dispose());

  group('add', () {
    test('keeps what is already there', () {
      final result = SceneImporter.import(
        controller,
        _scene([_rect('imported')]),
        mode: SceneImportMode.add,
      );

      expect(result.succeeded, isTrue);
      expect(result.imported, 1);
      expect(controller.elements, hasLength(2));
    });

    test('parses the payload once', () {
      // A multi-megabyte file was decoded in `loadJson` to count the drops
      // and then decoded *again* inside `pasteFromJson` — both on the UI
      // isolate.
      final spy = _SpyController();
      addTearDown(spy.dispose);

      final result = SceneImporter.import(
        spy,
        _scene([_rect('imported'), _rect('also', x: 40)]),
        mode: SceneImportMode.add,
      );

      expect(result.imported, 2);
      expect(spy.pastedBatches, 1);
      expect(spy.elements, hasLength(3));
    });

    test('re-identifies, so a file exported from this board can come back',
        () {
      // The ids in the payload are already on the canvas. Reusing them would
      // give two elements one id, and hit-testing/selection a single handle
      // for both.
      SceneImporter.import(
        controller,
        _scene([_rect('on-canvas')]),
        mode: SceneImportMode.add,
      );

      final ids = controller.elements.map((e) => e.id).toSet();
      expect(controller.elements, hasLength(2));
      expect(ids, hasLength(2));
    });
  });

  group('replace', () {
    test('swaps the canvas for the imported scene', () {
      final result = SceneImporter.import(
        controller,
        _scene([_rect('imported'), _rect('also', x: 40)]),
        mode: SceneImportMode.replace,
      );

      expect(result.imported, 2);
      expect(controller.elements.map((e) => e.id), ['imported', 'also']);
    });

    test('is undoable — a replace that traps you is not a replace', () {
      SceneImporter.import(
        controller,
        _scene([_rect('imported')]),
        mode: SceneImportMode.replace,
      );

      controller.undo();

      expect(controller.elements.single.id, 'on-canvas');
    });

    test('does not mark the canvas partial — no file is being overwritten',
        () {
      final payload = jsonEncode({
        'version': 1,
        'elements': [
          _rect('good').toJson(),
          {'id': 'bad', 'type': 'hexagon'},
        ],
      });

      final result =
          SceneImporter.import(controller, payload, mode: SceneImportMode.replace);

      expect(result.dropped, 1);
      expect(controller.sceneIsPartial, isFalse);
    });
  });

  group('reporting', () {
    test('counts elements it could not read instead of hiding them', () {
      final payload = jsonEncode({
        'version': 1,
        'elements': [
          _rect('good').toJson(),
          {'id': 'bad', 'type': 'hexagon'},
          const <String, dynamic>{},
        ],
      });

      final result =
          SceneImporter.import(controller, payload, mode: SceneImportMode.add);

      expect(result.imported, 1);
      expect(result.dropped, 2);
    });

    test('explains text that is not JSON', () {
      final result = SceneImporter.import(controller, 'hello there',
          mode: SceneImportMode.add);

      expect(result.succeeded, isFalse);
      expect(result.error, 'That file is not valid JSON.');
      expect(controller.elements, hasLength(1));
    });

    test('explains JSON with no elements in it', () {
      final result = SceneImporter.import(controller, '{"nope": true}',
          mode: SceneImportMode.add);

      expect(result.error, 'That file holds no elements.');
    });

    test('explains JSON shaped nothing like a scene', () {
      // `elements` present but not a list — a cast failure, which must not
      // reach the user as a Dart `TypeError`.
      final result = SceneImporter.import(
          controller, '{"version": 1, "elements": "lots"}',
          mode: SceneImportMode.add);

      expect(result.error, 'That file is not a FlowCraft scene.');
    });

    test('passes the schema-version refusal through verbatim', () {
      final result = SceneImporter.import(controller, '{"version": 99}',
          mode: SceneImportMode.add);

      expect(result.succeeded, isFalse);
      expect(result.error, contains('Unsupported sketch schema version: 99'));
    });

    test('an all-unreadable file is a failure, not an empty success', () {
      final payload = jsonEncode({
        'version': 1,
        'elements': [
          {'id': 'bad', 'type': 'hexagon'},
        ],
      });

      final result =
          SceneImporter.import(controller, payload, mode: SceneImportMode.add);

      expect(result.succeeded, isFalse);
      expect(result.error, contains('None of the 1 elements'));
    });
  });
}
