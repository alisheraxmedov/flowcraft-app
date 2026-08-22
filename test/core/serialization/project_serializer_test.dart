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
