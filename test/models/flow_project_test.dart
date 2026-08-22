import 'package:flowcraft/flowcraft.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FlowProject', () {
    test('create stamps both timestamps and starts empty', () {
      final now = DateTime(2026, 4, 1, 8, 30);

      final project = FlowProject.create(name: 'Sprint board', now: now);

      expect(project.name, 'Sprint board');
      expect(project.createdAt, now);
      expect(project.updatedAt, now);
      expect(project.elementCount, 0);
      expect(project.isBroken, isFalse);
      expect(project.id, startsWith('proj_'));
    });

    test('round-trips through JSON', () {
      final project = FlowProject(
        id: 'proj_1',
        name: 'Roadmap',
        createdAt: DateTime(2026, 1, 1, 9),
        updatedAt: DateTime(2026, 2, 2, 10),
        elementCount: 7,
      );

      expect(FlowProject.fromJson(project.toJson()), project);
    });

    test('tolerates a header missing its optional fields', () {
      final project = FlowProject.fromJson({'id': 'proj_1'});

      expect(project.name, 'Untitled');
      expect(project.elementCount, 0);
    });

    test('copyWith keeps id and createdAt immutable', () {
      final original = FlowProject.create(name: 'A', now: DateTime(2026));
      final renamed = original.copyWith(name: 'B', elementCount: 3);

      expect(renamed.id, original.id);
      expect(renamed.createdAt, original.createdAt);
      expect(renamed.name, 'B');
      expect(renamed.elementCount, 3);
    });

    test('refuses an id that could name a file outside the library', () {
      // A project file carries its own id, and the repository turns that id
      // into a path — so a shared file is an untrusted source for it.
      const escapes = [
        '../../../../.config/foo/config',
        r'..\..\secret',
        'proj/nested',
        '/etc/passwd',
        '..',
        '.',
        '',
        'proj.1',
        'proj 1',
      ];

      for (final id in escapes) {
        expect(FlowProject.isValidId(id), isFalse, reason: '"$id" is not an id');
        expect(
          () => FlowProject.fromJson({'id': id}),
          throwsA(isA<FormatException>()),
          reason: '"$id" must not survive parsing',
        );
      }
    });

    test('accepts the ids IdGenerator actually produces', () {
      expect(FlowProject.isValidId(IdGenerator.generate('proj')), isTrue);
      expect(FlowProject.isValidId(FlowProject.create(name: 'A').id), isTrue);
    });

    test('broken placeholders are flagged and named after their file', () {
      final broken = FlowProject.broken(id: 'proj_bad');

      expect(broken.isBroken, isTrue);
      expect(broken.name, 'proj_bad');
    });
  });
}
