import 'dart:convert';
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

    test('save does not re-read the scene file for its header', () async {
      // Autosave calls `save` 800ms after every edit; decoding the whole
      // previous save just to stamp a new `updatedAt` was a dropped frame
      // per autosave on a large board. Corrupting the file first proves
      // the header came from memory.
      final created = await repository.create('Cached');
      sceneFile(created.id).writeAsStringSync('{ not even json');

      final saved = await repository.save(
        id: created.id,
        elements: [_rect('a')],
      );

      expect(saved.name, 'Cached');
      expect(saved.createdAt, created.createdAt);
      expect((await repository.load(created.id)).elements.single.id, 'a');
    });

    test(
      'a fresh instance finds the header in the index, then the file',
      () async {
        final created = await repository.create('Cold');

        final viaIndex = ProjectRepository(directoryPath: tempDir.path);
        expect(
          (await viaIndex.save(id: created.id, elements: [_rect('a')])).name,
          'Cold',
        );

        indexFile().deleteSync();
        final viaFile = ProjectRepository(directoryPath: tempDir.path);
        final saved = await viaFile.save(
          id: created.id,
          elements: [_rect('b')],
        );
        expect(saved.name, 'Cold');
        expect(saved.createdAt, created.createdAt);
        expect((await repository.load(created.id)).elements.single.id, 'b');
      },
    );

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

    test('rebuilds a corrupt index rather than losing every project', () async {
      await repository.create('Survivor');
      indexFile().writeAsStringSync('}{ garbage');

      expect((await repository.list()).single.name, 'Survivor');
    });

    test('a double version field is accepted', () async {
      // A file that went through a tool that writes every number as a
      // double is still schema 1, not a broken project.
      final created = await repository.create('Floaty');
      await repository.save(id: created.id, elements: [_rect('a')]);
      final file = sceneFile(created.id);
      final map = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      map['version'] = 1.0;
      (map['scene'] as Map<String, dynamic>)['version'] = 1.0;
      file.writeAsStringSync(jsonEncode(map));

      final loaded = await repository.load(created.id);

      expect(loaded.elements.single.id, 'a');
      expect(loaded.droppedCount, 0);
    });

    test('sweeps temp files an interrupted write left behind', () async {
      await repository.create('Survivor');
      final stale =
          File(
              '${tempDir.path}${Platform.pathSeparator}'
              'proj_dead.json.7.tmp',
            )
            ..writeAsStringSync('{"half": "written')
            ..setLastModifiedSync(
              DateTime.now().subtract(const Duration(hours: 1)),
            );
      final fresh = File(
        '${tempDir.path}${Platform.pathSeparator}'
        'proj_live.json.8.tmp',
      )..writeAsStringSync('{"still": "being written"}');

      final listed = await repository.list();

      expect(listed.map((p) => p.name), ['Survivor']);
      expect(stale.existsSync(), isFalse, reason: 'an hour-old temp is junk');
      expect(
        fresh.existsSync(),
        isTrue,
        reason: 'a temp modified seconds ago may belong to a live write',
      );
    });

    test('a failed write leaves no temp file', () async {
      final created = await repository.create('Blocked');
      // Replace the scene file with a directory so the rename must fail.
      final file = sceneFile(created.id)..deleteSync();
      Directory(file.path).createSync();

      await expectLater(
        repository.save(id: created.id, elements: [_rect('a')]),
        throwsA(isA<FileSystemException>()),
      );

      final temps = tempDir
          .listSync()
          .where((entity) => entity.path.endsWith('.tmp'))
          .toList();
      expect(temps, isEmpty);
    });

    test('picks up a scene file the index never heard about', () async {
      final orphan = FlowProjectScene(
        project: FlowProject.create(name: 'Orphan'),
        elements: const [],
      );
      sceneFile(
        orphan.project.id,
      ).writeAsStringSync(ProjectSerializer.encodeScene(orphan));

      expect((await repository.list()).single.name, 'Orphan');
    });
  });

  group('planted files', () {
    // One file per project is a format people hand to each other, so a
    // whiteboard someone was asked to "just drop in" is an untrusted input
    // that gets to name a path.
    late Directory root;
    late Directory projects;
    late File outsider;
    late ProjectRepository planted;

    /// `proj_planted.json`, whose header claims to be [claimedId].
    void plant(String claimedId) {
      File(
        '${projects.path}${Platform.pathSeparator}proj_planted.json',
      ).writeAsStringSync(
        jsonEncode({
          'version': 1,
          'project': {
            'id': claimedId,
            'name': 'Shared board',
            // Newest, so a startup restore would reach for it first.
            'createdAt': '2099-01-01T00:00:00.000Z',
            'updatedAt': '2099-01-01T00:00:00.000Z',
            'elementCount': 0,
          },
          'scene': {'version': 1, 'elements': <dynamic>[]},
        }),
      );
    }

    setUp(() {
      final sep = Platform.pathSeparator;
      root = Directory('${tempDir.path}${sep}root')..createSync();
      projects = Directory('${root.path}${sep}projects')..createSync();
      // A readable, deletable `.json` one directory up from the library.
      outsider = File('${root.path}${sep}secret.json')
        ..writeAsStringSync(
          ProjectSerializer.encodeScene(
            FlowProjectScene(
              project: FlowProject(
                id: 'secret',
                name: 'Private notes',
                createdAt: DateTime(2026),
                updatedAt: DateTime(2026),
                elementCount: 1,
              ),
              elements: [_rect('classified')],
            ),
          ),
        );
      planted = ProjectRepository(directoryPath: projects.path);
    });

    test(
      'a header claiming a traversal id is listed as its own file',
      () async {
        plant('..${Platform.pathSeparator}secret');

        final listed = await planted.list();

        // The file name decides the identity, and the mismatch marks it
        // broken — which is also what keeps the startup restore off it.
        expect(listed.single.id, 'proj_planted');
        expect(listed.single.isBroken, isTrue);
      },
    );

    test('a traversal id can neither be read nor deleted', () async {
      final traversal = '..${Platform.pathSeparator}secret';
      plant(traversal);
      await planted.list();

      await expectLater(
        planted.load(traversal),
        throwsA(isA<ArgumentError>()),
        reason: 'arbitrary .json read',
      );
      await expectLater(
        planted.delete(traversal),
        throwsA(isA<ArgumentError>()),
        reason: 'arbitrary .json delete',
      );
      await expectLater(
        planted.save(id: traversal, elements: const []),
        throwsA(isA<ArgumentError>()),
        reason: 'arbitrary .json overwrite',
      );
      expect(outsider.existsSync(), isTrue);
    });

    test('an absolute id is refused too', () async {
      final absolute = '${root.path}${Platform.pathSeparator}secret';
      plant(absolute);

      expect((await planted.list()).single.id, 'proj_planted');
      await expectLater(planted.load(absolute), throwsA(isA<ArgumentError>()));
    });

    test('a header id that simply disagrees with its file is broken, not '
        'followed', () async {
      plant('proj_elsewhere');

      final listed = await planted.list();

      expect(listed.single.id, 'proj_planted');
      expect(listed.single.isBroken, isTrue);
    });

    test('a file whose name is not an id is ignored, not listed', () async {
      File(
        '${projects.path}${Platform.pathSeparator}not-a-project.json',
      ).writeAsStringSync('{}');

      expect(await planted.list(), isEmpty);
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

    test('rename preserves elements this build cannot decode', () async {
      // A project saved by a newer FlowCraft: one element we understand,
      // one we do not. `load` reports the drop; a rename from the sidebar
      // must not turn that report into a rewrite of the reduced scene.
      final created = await repository.create('Future');
      await repository.save(id: created.id, elements: [_rect('known')]);
      final file = sceneFile(created.id);
      final map = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      final scene = map['scene'] as Map<String, dynamic>;
      (scene['elements'] as List).add({
        'type': 'hologram',
        'id': 'from_the_future',
        'depth': 3,
      });
      file.writeAsStringSync(jsonEncode(map));
      expect(
        (await repository.load(created.id)).droppedCount,
        1,
        reason: 'precondition: this build cannot read the hologram',
      );

      await repository.rename(created.id, 'Renamed');

      final after = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      final elements =
          (after['scene'] as Map<String, dynamic>)['elements'] as List<dynamic>;
      expect(elements, hasLength(2));
      expect(
        elements.last,
        {'type': 'hologram', 'id': 'from_the_future', 'depth': 3},
        reason: 'the unknown element is carried over byte-for-byte in meaning',
      );
      expect((after['project'] as Map<String, dynamic>)['name'], 'Renamed');
      expect((await repository.list()).single.name, 'Renamed');
    });

    test('rename keeps every other top-level key of the file', () async {
      // A field a newer build added beside `scene` is part of the file's
      // future, not ours to drop on the way past.
      final created = await repository.create('Keep');
      final file = sceneFile(created.id);
      final map = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      map['layout'] = {'auto': true};
      file.writeAsStringSync(jsonEncode(map));

      await repository.rename(created.id, 'Kept');

      final after = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      expect(after['layout'], {'auto': true});
    });

    test('renaming a missing project fails loudly', () async {
      expect(
        repository.rename('proj_nope', 'Anything'),
        throwsA(isA<StateError>()),
      );
    });

    test('delete removes the file and the index entry', () async {
      final kept = await repository.create('Kept');
      final doomed = await repository.create('Doomed');

      await repository.delete(doomed.id);

      expect(sceneFile(doomed.id).existsSync(), isFalse);
      expect((await repository.list()).map((p) => p.id), [kept.id]);
    });

    test(
      'deleting with an unreadable index keeps the other projects',
      () async {
        final kept = await repository.create('Kept');
        final doomed = await repository.create('Doomed');
        indexFile().writeAsStringSync('}{ garbage');

        await repository.delete(doomed.id);

        expect((await repository.list()).map((p) => p.id), [kept.id]);
      },
    );

    test('deleting something already gone is a no-op', () async {
      await expectLater(repository.delete('proj_nope'), completes);
    });

    test('loading a missing project fails loudly', () async {
      expect(repository.load('proj_nope'), throwsA(isA<StateError>()));
    });
  });

  group('linked file', () {
    late Directory root;
    late Directory out;
    late ProjectRepository linkedRepo;
    late String linkedPath;
    final errors = <Object>[];

    setUp(() {
      root = Directory.systemTemp.createTempSync('fc_link_');
      // Mirrors the real layout: the repo's parent is the protected data dir.
      final projects = Directory('${root.path}/home/.flowcraft/projects')
        ..createSync(recursive: true);
      out = Directory('${root.path}/out')..createSync();
      linkedPath = '${out.path}/board.flowcraft';
      errors.clear();
      linkedRepo = ProjectRepository(directoryPath: projects.path)
        ..onMirrorError = errors.add;
    });

    tearDown(() => root.deleteSync(recursive: true));

    File local(String id) =>
        File('${root.path}/home/.flowcraft/projects/$id.json');

    test('save mirrors to the linked file atomically', () async {
      final p = await linkedRepo.create('Doc');
      await linkedRepo.link(p.id, linkedPath);
      await linkedRepo.save(id: p.id, elements: [_rect('a'), _rect('b')]);

      expect(
        File(linkedPath).readAsStringSync(),
        local(p.id).readAsStringSync(),
      );
      expect(
        out.listSync().map((e) => e.path),
        [linkedPath],
        reason: 'no temp file left beside the target',
      );
      expect(errors, isEmpty);
    });

    test('mirror failure does not fail the main save', () async {
      final p = await linkedRepo.create('Doc');
      await linkedRepo.link(p.id, linkedPath);
      out.deleteSync(recursive: true);

      final saved = await linkedRepo.save(id: p.id, elements: [_rect('a')]);

      expect(saved.elementCount, 1);
      expect((await linkedRepo.load(p.id)).elements.single.id, 'a');
      expect(errors, hasLength(1));
    });

    test('load prefers a newer linked file', () async {
      final p = await linkedRepo.create('Doc');
      await linkedRepo.link(p.id, linkedPath);
      final linked = (await linkedRepo.load(p.id)).project;
      File(linkedPath).writeAsStringSync(
        ProjectSerializer.encodeScene(
          FlowProjectScene(project: linked, elements: [_rect('x'), _rect('y')]),
        ),
      );
      File(
        linkedPath,
      ).setLastModifiedSync(DateTime.now().add(const Duration(minutes: 5)));

      final loaded = await linkedRepo.load(p.id);

      expect(loaded.elements.map((e) => e.id), ['x', 'y']);
      expect(loaded.project.linkedPath, linkedPath);
    });

    test('an older or just-mirrored linked file does not win', () async {
      final p = await linkedRepo.create('Doc');
      await linkedRepo.link(p.id, linkedPath);
      await linkedRepo.save(id: p.id, elements: [_rect('mine')]);

      expect((await linkedRepo.load(p.id)).elements.single.id, 'mine');
    });

    test('corrupt linked file falls back to local', () async {
      final p = await linkedRepo.create('Doc');
      await linkedRepo.link(p.id, linkedPath);
      await linkedRepo.save(id: p.id, elements: [_rect('mine')]);
      File(linkedPath).writeAsStringSync('{ not json');
      File(
        linkedPath,
      ).setLastModifiedSync(DateTime.now().add(const Duration(minutes: 5)));

      final loaded = await linkedRepo.load(p.id);

      expect(loaded.elements.single.id, 'mine');
      expect(errors, hasLength(1));
    });

    test('linking to an existing scene file loads it and leaves the file '
        'untouched (bytes equal)', () async {
      final p = await linkedRepo.create('Doc');
      await linkedRepo.save(id: p.id, elements: [_rect('mine')]);
      final committed = ProjectSerializer.encodeScene(
        FlowProjectScene(
          project: FlowProject.create(name: 'Theirs'),
          elements: [_rect('x'), _rect('y')],
        ),
      );
      File(linkedPath).writeAsStringSync(committed);
      final before = File(linkedPath).readAsBytesSync();

      final adopted = await linkedRepo.link(p.id, linkedPath);

      expect(adopted!.elements.map((e) => e.id), ['x', 'y']);
      expect(File(linkedPath).readAsBytesSync(), before);
      final loaded = await linkedRepo.load(p.id);
      expect(loaded.elements.map((e) => e.id), ['x', 'y']);
      expect(loaded.project.name, 'Doc');
      expect(loaded.project.linkedPath, linkedPath);
    });

    test('linking to an existing non-scene file is refused, nothing '
        'persisted', () async {
      final p = await linkedRepo.create('Doc');
      for (final junk in ['{ not json', '{}', '{"foo": 1}', '[1]']) {
        File(linkedPath).writeAsStringSync(junk);
        await expectLater(
          linkedRepo.link(p.id, linkedPath),
          throwsA(
            isA<ExportPathException>().having(
              (e) => e.message,
              'message',
              contains('is not a FlowCraft scene'),
            ),
          ),
          reason: junk,
        );
        expect(File(linkedPath).readAsStringSync(), junk);
      }
      expect((await linkedRepo.load(p.id)).project.linkedPath, isNull);
    });

    test('linking to a missing file mirrors the current scene', () async {
      final p = await linkedRepo.create('Doc');
      await linkedRepo.save(id: p.id, elements: [_rect('mine')]);

      expect(await linkedRepo.link(p.id, linkedPath), isNull);

      expect(
        ProjectSerializer.decodeScene(
          File(linkedPath).readAsStringSync(),
        ).elements.single.id,
        'mine',
      );
    });

    test('old index/header without linkedPath loads', () async {
      final p = await repository.create('Old');
      final scene = jsonDecode(sceneFile(p.id).readAsStringSync()) as Map;
      expect((scene['project'] as Map).containsKey('linkedPath'), isFalse);
      indexFile().deleteSync();

      final listed = await repository.list();
      expect(listed.single.linkedPath, isNull);
      expect((await repository.load(p.id)).project.linkedPath, isNull);
    });

    test('link survives rename and index rebuild; unlink clears it', () async {
      final p = await linkedRepo.create('Doc');
      await linkedRepo.link(p.id, linkedPath);
      await linkedRepo.rename(p.id, 'Renamed');
      File('${root.path}/home/.flowcraft/projects/index.json').deleteSync();

      expect((await linkedRepo.list()).single.linkedPath, linkedPath);

      await linkedRepo.unlink(p.id);
      expect((await linkedRepo.load(p.id)).project.linkedPath, isNull);
    });
  });
}
