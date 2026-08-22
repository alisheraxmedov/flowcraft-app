import 'dart:convert';

import 'package:flowcraft/flowcraft.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

FlowProject _project({String name = 'Roadmap'}) {
  return FlowProject(
    id: 'proj_1',
    name: name,
    createdAt: DateTime(2026, 1, 1, 10),
    updatedAt: DateTime(2026, 2, 3, 11, 30),
    elementCount: 2,
  );
}

void main() {
  group('ProjectSerializer scenes', () {
    test('round-trips metadata and elements', () {
      final scene = FlowProjectScene(
        project: _project(),
        elements: [
          SketchRectangle.create(
            id: 'a',
            rect: const Rect.fromLTWH(0, 0, 10, 20),
          ),
          SketchText.create(id: 'b', position: Offset.zero, text: 'hello'),
        ],
      );

      final decoded =
          ProjectSerializer.decodeScene(ProjectSerializer.encodeScene(scene));

      expect(decoded.project, _project());
      expect(decoded.elements.map((e) => e.id), ['a', 'b']);
      expect((decoded.elements[1] as SketchText).text, 'hello');
    });

    test('decodeHeader reads metadata without the element list', () {
      final encoded = ProjectSerializer.encodeScene(
        FlowProjectScene(
          project: _project(),
          elements: [
            SketchRectangle.create(rect: const Rect.fromLTWH(0, 0, 1, 1)),
          ],
        ),
      );

      expect(ProjectSerializer.decodeHeader(encoded).name, 'Roadmap');
    });

    test('refuses a schema newer than this build understands', () {
      expect(
        () => ProjectSerializer.decodeScene('{"version": 99}'),
        throwsA(isA<StateError>()),
      );
    });

    test('a double version field is accepted', () {
      final encoded = ProjectSerializer.encodeScene(
        FlowProjectScene(project: _project(), elements: const []),
      ).replaceFirst('"version":1', '"version":1.0');
      expect(encoded, contains('"version":1.0'), reason: 'precondition');

      expect(ProjectSerializer.decodeHeader(encoded).name, 'Roadmap');
      expect(ProjectSerializer.decodeScene(encoded).elements, isEmpty);
    });

    test('replaceHeader swaps the header and copies the scene verbatim', () {
      final source = jsonEncode({
        'version': 1,
        'project': _project(name: 'Old').toJson(),
        'scene': {
          'version': 1,
          'elements': [
            SketchRectangle.create(
              id: 'a',
              rect: const Rect.fromLTWH(0, 0, 1, 1),
            ).toJson(),
            {'type': 'hologram', 'id': 'b', 'depth': 3},
          ],
        },
        'extra': 'kept',
      });

      final renamed = ProjectSerializer.replaceHeader(
        source,
        _project(name: 'New'),
      );

      final map = jsonDecode(renamed) as Map<String, dynamic>;
      expect((map['project'] as Map<String, dynamic>)['name'], 'New');
      expect(map['scene'], jsonDecode(source)['scene'],
          reason: 'the scene — unknown element included — is untouched');
      expect(map['extra'], 'kept');
      expect(ProjectSerializer.decodeScene(renamed).droppedCount, 1,
          reason: 'the hologram is still there for a build that can read it');
    });

    test('the autosave path writes freedraw points as they are', () {
      // Strokes are simplified once, on commit, by the gesture handler at
      // the same tolerance; re-running RDP on every autosave was ~40% of
      // the encode on a stroke-heavy board. Explicit export still
      // simplifies — see `SketchSerializer.serialize`.
      final points = <Offset>[
        for (var i = 0; i < 50; i++) Offset(i.toDouble(), 0),
      ];
      final stroke = SketchFreedraw.create(id: 'f', points: points);

      final encoded = ProjectSerializer.encodeScene(
        FlowProjectScene(project: _project(), elements: [stroke]),
      );

      final decoded = ProjectSerializer.decodeScene(encoded);
      expect((decoded.elements.single as SketchFreedraw).points, points);
      expect(
        (SketchSerializer.toMap([stroke])['elements'] as List).single['points'],
        hasLength(lessThan(points.length)),
        reason: 'the export path is still the simplifying one',
      );
    });
  });

  group('ProjectSerializer index', () {
    test('round-trips a project list', () {
      final decoded = ProjectSerializer.decodeIndex(
        ProjectSerializer.encodeIndex([_project(), _project(name: 'Second')]),
      );

      expect(decoded.map((p) => p.name), ['Roadmap', 'Second']);
    });

    test('drops broken placeholders — they are recovery state, not data', () {
      final encoded = ProjectSerializer.encodeIndex([
        _project(),
        FlowProject.broken(id: 'proj_bad'),
      ]);

      expect(ProjectSerializer.decodeIndex(encoded), hasLength(1));
    });
  });
}
