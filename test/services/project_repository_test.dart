import 'dart:io';

import 'package:flowcraft/flowcraft.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

SketchRectangle _rect(String id) {
  return SketchRectangle.create(id: id, rect: const Rect.fromLTWH(0, 0, 8, 8));
}

void main() {
  late Directory tempDir;
  late ProjectRepository repository;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('fc_projects_');
    repository = ProjectRepository(directoryPath: tempDir.path);
  });

  tearDown(() => tempDir.deleteSync(recursive: true));

  File sceneFile(String id) =>
      File('${tempDir.path}${Platform.pathSeparator}$id.json');

  File indexFile() =>
      File('${tempDir.path}${Platform.pathSeparator}index.json');

  group('round trip', () {
    test('create → save → list → load preserves the elements', () async {
      final created = await repository.create('Architecture');
      await repository.save(id: created.id, elements: [_rect('a'), _rect('b')]);

      final listed = await repository.list();
      expect(listed, hasLength(1));
      expect(listed.single.name, 'Architecture');
      expect(listed.single.elementCount, 2);

      final loaded = await repository.load(created.id);
      expect(loaded.elements.map((e) => e.id), ['a', 'b']);
      expect(loaded.project.name, 'Architecture');
    });

    test('listing an absent directory is empty, not an error', () async {
      final missing = ProjectRepository(
        directoryPath: '${tempDir.path}${Platform.pathSeparator}nope',
      );

      expect(await missing.list(), isEmpty);
    });

    test('orders projects by most recent edit', () async {
      final first = await repository.create('First');
      await repository.create('Second');
      await repository.save(id: first.id, elements: [_rect('a')]);

      expect((await repository.list()).first.name, 'First');
    });

    test('normalises whitespace-only names to Untitled', () async {
      final created = await repository.create('   ');
      expect(created.name, 'Untitled');
    });

    test('saving an unknown project fails loudly', () async {
      expect(
        repository.save(id: 'proj_nope', elements: const []),
        throwsA(isA<StateError>()),
      );
    });
  });

  group('resilience', () {
    test('a corrupt project file does not hide the healthy ones', () async {
      final good = await repository.create('Healthy');
      sceneFile('proj_corrupt').writeAsStringSync('{ this is not json');
      // Force a rescan: the index no longer matches what is on disk.
      final listed = await repository.list();

      expect(listed.map((p) => p.name), contains('Healthy'));
      expect(
        listed.singleWhere((p) => p.id == 'proj_corrupt').isBroken,
        isTrue,
      );
      expect(await repository.load(good.id), isNotNull);
    });

    test('rebuilds a deleted index by scanning the scene files', () async {
      final created = await repository.create('Recovered');
      await repository.save(id: created.id, elements: [_rect('a')]);
      indexFile().deleteSync();

      final listed = await repository.list();

      expect(listed.single.name, 'Recovered');
      expect(listed.single.elementCount, 1);
      expect(indexFile().existsSync(), isTrue, reason: 'index rewritten');
    });

    test('rebuilds a corrupt index rather than losing every project',
        () async {
      await repository.create('Survivor');
      indexFile().writeAsStringSync('}{ garbage');

      expect((await repository.list()).single.name, 'Survivor');
    });

    test('picks up a scene file the index never heard about', () async {
      final orphan = FlowProjectScene(
        project: FlowProject.create(name: 'Orphan'),
        elements: const [],
      );
      sceneFile(orphan.project.id)
          .writeAsStringSync(ProjectSerializer.encodeScene(orphan));

      expect((await repository.list()).single.name, 'Orphan');
    });
  });

  group('mutations', () {
    test('rename updates the index and the scene file header', () async {
      final created = await repository.create('Before');
      await repository.rename(created.id, 'After');

      expect((await repository.list()).single.name, 'After');
      // Drop the index so the next listing has to trust the scene header.
      indexFile().deleteSync();
      expect((await repository.list()).single.name, 'After');
    });

    test('delete removes the file and the index entry', () async {
      final kept = await repository.create('Kept');
      final doomed = await repository.create('Doomed');

      await repository.delete(doomed.id);

      expect(sceneFile(doomed.id).existsSync(), isFalse);
      expect((await repository.list()).map((p) => p.id), [kept.id]);
    });

    test('deleting with an unreadable index keeps the other projects',
        () async {
      final kept = await repository.create('Kept');
      final doomed = await repository.create('Doomed');
      indexFile().writeAsStringSync('}{ garbage');

      await repository.delete(doomed.id);

      expect((await repository.list()).map((p) => p.id), [kept.id]);
    });

    test('deleting something already gone is a no-op', () async {
      await expectLater(repository.delete('proj_nope'), completes);
    });

    test('loading a missing project fails loudly', () async {
      expect(repository.load('proj_nope'), throwsA(isA<StateError>()));
    });
  });
}
