import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';

import 'package:flowcraft/models/sketch_element.dart';
import 'package:flowcraft/models/sketch_style.dart';
import 'package:flowcraft/core/serialization/sketch_serializer.dart';

void main() {
  group('SketchSerializer.serialize / deserialize', () {
    test('round-trips a mixed element list', () {
      final source = <SketchElement>[
        SketchRectangle.create(
          rect: const Rect.fromLTWH(10, 20, 100, 50),
          style: const SketchStyle(roughness: 1.4, seed: 42),
        ),
        SketchEllipse.create(
          rect: const Rect.fromLTWH(0, 0, 80, 80),
          style: const SketchStyle(
            fillStyle: FillStyle.solid,
            fillColor: Color(0xFFFF0000),
          ),
        ),
        SketchLine.create(
          start: const Offset(0, 0),
          end: const Offset(100, 100),
        ),
        SketchArrow.create(
          start: const Offset(0, 0),
          end: const Offset(50, 25),
          arrowSize: 14,
        ),
        SketchFreedraw.create(
          points: const [Offset(0, 0), Offset(10, 5), Offset(20, 0)],
        ),
        SketchText.create(
          position: const Offset(40, 40),
          text: 'hello',
          fontSize: 18,
        ),
      ];

      final json = SketchSerializer.serialize(source);
      final restored = SketchSerializer.deserialize(json);

      expect(restored.length, source.length);
      for (var i = 0; i < source.length; i++) {
        expect(restored[i].runtimeType, source[i].runtimeType);
        expect(restored[i].id, source[i].id);
        expect(restored[i].bounds, source[i].bounds);
        expect(restored[i].style, source[i].style);
      }
    });

    test('rejects newer schema versions', () {
      expect(
        () => SketchSerializer.fromMap({
          'version': SketchSerializer.schemaVersion + 1,
          'elements': const [],
        }),
        throwsStateError,
      );
    });

    test('simplifies freedraw points on write', () {
      // Long noisy polyline whose colinear segments should collapse.
      final points = <Offset>[
        for (var i = 0; i < 50; i++) Offset(i.toDouble(), 0),
      ];
      final original = SketchFreedraw.create(points: points);
      final map = SketchSerializer.toMap([original]);
      final encoded = (map['elements'] as List).first as Map<String, dynamic>;
      final encodedPoints = encoded['points'] as List;
      expect(encodedPoints.length, lessThan(points.length));
      // Everything but the points survives the simplified copy.
      expect(encoded['id'], original.id);
      expect(encoded['style'], original.style.toJson());
    });

    test('a zero tolerance writes freedraw points verbatim', () {
      final points = <Offset>[
        for (var i = 0; i < 50; i++) Offset(i.toDouble(), 0),
      ];
      final map = SketchSerializer.toMap([
        SketchFreedraw.create(points: points),
      ], simplificationTolerance: 0);
      final encoded = (map['elements'] as List).first as Map<String, dynamic>;
      expect(encoded['points'], hasLength(points.length));
    });

    test('a double version field is accepted', () {
      final loaded = SketchSerializer.load({
        'version': 1.0,
        'elements': [
          SketchRectangle.create(
            id: 'a',
            rect: const Rect.fromLTWH(0, 0, 10, 10),
          ).toJson(),
        ],
      });
      expect(loaded.elements.single.id, 'a');
      expect(
        SketchSerializer.fromMap({'version': 1.0, 'elements': const []}),
        isEmpty,
      );
    });

    test('round-trips groupId without a schema bump', () {
      final source = <SketchElement>[
        SketchRectangle.create(
          id: 'a',
          rect: const Rect.fromLTWH(0, 0, 10, 10),
        ).withGroupId('g1'),
        SketchEllipse.create(
          id: 'b',
          rect: const Rect.fromLTWH(0, 0, 10, 10),
        ).withGroupId('g1'),
      ];

      final map = SketchSerializer.toMap(source);
      expect(map['version'], 1);

      final restored = SketchSerializer.fromMap(map);
      expect(restored.map((e) => e.groupId), ['g1', 'g1']);
    });
  });

  group('SketchSerializer.load (tolerant)', () {
    /// A scene of three rectangles whose middle element is [broken].
    Map<String, dynamic> sceneWith(Object broken) => <String, dynamic>{
      'version': SketchSerializer.schemaVersion,
      'elements': <dynamic>[
        SketchRectangle.create(
          id: 'first',
          rect: const Rect.fromLTWH(0, 0, 10, 10),
        ).toJson(),
        broken,
        SketchRectangle.create(
          id: 'last',
          rect: const Rect.fromLTWH(20, 0, 10, 10),
        ).toJson(),
      ],
    };

    const unknownType = <String, dynamic>{
      'type': 'wormhole',
      'id': 'middle',
      'style': <String, dynamic>{},
    };

    test('keeps the readable elements when one has an unknown type', () {
      // The whole point: one bad element used to make the project
      // unopenable, so the user lost every *other* element in the file too.
      final loaded = SketchSerializer.load(sceneWith(unknownType));

      expect(loaded.elements.map((e) => e.id), ['first', 'last']);
      expect(loaded.isComplete, isFalse);
      expect(loaded.droppedCount, 1);
      expect(loaded.errors.single.index, 1);
      expect(loaded.errors.single.id, 'middle');
      expect(loaded.errors.single.type, 'wormhole');
    });

    test('keeps the rest when an element is missing a required field', () {
      final loaded = SketchSerializer.load(
        sceneWith(<String, dynamic>{
          'type': 'rectangle',
          'id': 'middle',
          // no 'style', no 'rect'
        }),
      );

      expect(loaded.elements.map((e) => e.id), ['first', 'last']);
      expect(loaded.errors.single.id, 'middle');
    });

    test('keeps the rest when an entry is not an object at all', () {
      final loaded = SketchSerializer.load(sceneWith('not an element'));

      expect(loaded.elements.map((e) => e.id), ['first', 'last']);
      expect(loaded.errors.single.index, 1);
      expect(loaded.errors.single.id, isNull);
      expect(loaded.errors.single.type, isNull);
    });

    test('reports nothing for a clean scene', () {
      final loaded = SketchSerializer.loadJson(
        SketchSerializer.serialize([
          SketchRectangle.create(
            id: 'a',
            rect: const Rect.fromLTWH(0, 0, 10, 10),
          ),
        ]),
      );

      expect(loaded.elements.single.id, 'a');
      expect(loaded.isComplete, isTrue);
      expect(loaded.droppedCount, 0);
    });

    test('still refuses a newer schema version outright', () {
      // Not one bad element: nothing here knows which parts of a newer
      // payload are safe to keep, and keeping some of it would corrupt the
      // file on the next save.
      expect(
        () => SketchSerializer.load({
          'version': SketchSerializer.schemaVersion + 1,
          'elements': const [],
        }),
        throwsStateError,
      );
    });

    test(
      'fromMap stays strict, so callers that want a loud failure keep it',
      () {
        // The MCP draw path rejects bad input rather than silently dropping
        // the shape the agent asked for.
        expect(
          () => SketchSerializer.fromMap(sceneWith(unknownType)),
          throwsStateError,
        );
      },
    );
  });

  group('collapsible sticky notes did not change the file format', () {
    /// A scene exactly as a build before `SketchSticky.collapsed` existed
    /// wrote it — same keys, same values, same version. Users have files
    /// like this on disk in `~/.flowcraft/projects/`.
    Map<String, dynamic> legacyScene() => <String, dynamic>{
      'version': 1,
      'elements': <Map<String, dynamic>>[
        {
          'type': 'sticky',
          'id': 'note-1',
          'style': const SketchStyle(
            strokeColor: SketchSticky.defaultColor,
            fillColor: SketchSticky.defaultColor,
            fillStyle: FillStyle.solid,
          ).toJson(),
          'rect': {'l': 32.0, 't': 48.0, 'w': 160.0, 'h': 80.0},
          'angle': 0.0,
          'cornerRadius': 4.0,
          'text': 'written last week',
          'fontSize': 20.0,
        },
      ],
    };

    test('the schema version is still 1', () {
      // Adding a field with a `fromJson` default must not bump this — a bump
      // makes every already-saved file unreadable by the build that saved it.
      expect(SketchSerializer.schemaVersion, 1);
    });

    test('a scene saved before the field existed still opens', () {
      final loaded = SketchSerializer.load(legacyScene());
      expect(loaded.isComplete, isTrue);
      expect(loaded.errors, isEmpty);

      final note = loaded.elements.single as SketchSticky;
      expect(note.id, 'note-1');
      expect(note.text, 'written last week');
      expect(note.collapsed, isFalse);
      // Opens exactly as it was drawn, not restyled by this build's defaults.
      expect(note.bounds, const Rect.fromLTWH(32, 48, 160, 80));
      expect(note.cornerRadius, 4.0);
      expect(note.fontSize, 20.0);
    });

    test('re-saving it writes the same payload back', () {
      // The other half of "compatible in both directions": an old file that
      // is opened and saved must not gain a key an older build would then
      // have to ignore.
      final loaded = SketchSerializer.load(legacyScene());
      final rewritten = SketchSerializer.toMap(loaded.elements);
      expect(rewritten['version'], 1);
      final element =
          (rewritten['elements'] as List).single as Map<String, dynamic>;
      expect(element.containsKey('collapsed'), isFalse);
      expect(element, legacyScene()['elements']![0]);
    });

    test('a collapsed note survives a save-and-open cycle', () {
      final collapsed = SketchSticky.create(
        id: 'note-2',
        rect: const Rect.fromLTWH(10, 10, 200, 90),
        text: 'later',
        collapsed: true,
      );
      final restored =
          SketchSerializer.deserialize(
                SketchSerializer.serialize([collapsed]),
              ).single
              as SketchSticky;
      expect(restored.collapsed, isTrue);
      expect(restored.rect, collapsed.rect);
      expect(restored.bounds, collapsed.bounds);
    });
  });
}
