import 'dart:convert';
import 'dart:io';

import 'package:flowcraft/flowcraft.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

SketchRectangle _rect(String id) {
  return SketchRectangle.create(id: id, rect: const Rect.fromLTWH(0, 0, 4, 4));
}

void main() {
  // `AppLifecycleListener` (used for the flush-on-quit hook) needs a binding.
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late ProviderContainer container;
  late ProjectRepository repository;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('fc_projects_vm_');
    repository = ProjectRepository(directoryPath: tempDir.path);
    container = ProviderContainer(
      overrides: [projectRepositoryProvider.overrideWithValue(repository)],
    );
  });

  tearDown(() async {
    await container.read(projectsViewModelProvider.notifier).flush();
    container.dispose();
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  ProjectsViewModel model() =>
      container.read(projectsViewModelProvider.notifier);

  ProjectsState state() => container.read(projectsViewModelProvider);

  SketchController canvas() => container.read(sketchControllerProvider);

  group('startup', () {
    test(
      'starts a project when the library is empty, so edits are saved',
      () async {
        await model().ready;

        expect(state().isLoading, isFalse);
        expect(state().projects, hasLength(1));
        expect(state().active?.name, 'Untitled project');
      },
    );

    test('resumes the most recently edited project', () async {
      final old = await repository.create('Old');
      await repository.save(id: old.id, elements: const []);
      final recent = await repository.create('Recent');

      await model().ready;

      expect(state().activeId, recent.id);
    });

    test('loads the resumed project onto the canvas', () async {
      final project = await repository.create('Saved');
      await repository.save(id: project.id, elements: [_rect('a')]);

      await model().ready;

      expect(canvas().elements.single.id, 'a');
    });

    test('lists a corrupt project without letting it become active', () async {
      File(
        '${tempDir.path}${Platform.pathSeparator}proj_bad.json',
      ).writeAsStringSync('not json');

      await model().ready;

      expect(state().projects.where((p) => p.isBroken), hasLength(1));
      expect(state().active?.isBroken, isFalse);
    });
  });

  group('switching projects', () {
    test(
      'a debounced edit lands in the outgoing project, never the new one',
      () async {
        await model().ready;
        final first = state().activeId!;
        await model().createProject('Second');
        final second = state().activeId!;
        await model().openProject(first);

        // Arms the 800ms debounce, then switches long before it could fire.
        canvas().add(_rect('drawn-in-first'));
        await model().openProject(second);
        await model().flush();

        expect(
          (await repository.load(first)).elements.single.id,
          'drawn-in-first',
        );
        expect((await repository.load(second)).elements, isEmpty);
        expect(canvas().elements, isEmpty);
      },
    );

    test('overlapping switches serialize instead of crossing scenes', () async {
      await model().ready;
      final a = state().activeId!;
      await model().createProject('B');
      final b = state().activeId!;
      await model().createProject('C');
      final c = state().activeId!;
      await model().openProject(a);
      canvas().add(_rect('in-a'));

      // Both fired without awaiting the first — the shape of a sidebar tap
      // landing while another switch is still reading from disk.
      await Future.wait([model().openProject(b), model().openProject(c)]);
      await model().flush();

      expect(state().activeId, c);
      expect((await repository.load(a)).elements.single.id, 'in-a');
      expect((await repository.load(b)).elements, isEmpty);
      expect((await repository.load(c)).elements, isEmpty);
      expect(canvas().elements, isEmpty);
    });

    test(
      'a tap landing mid-restore does not race the resumed project',
      () async {
        final older = await repository.create('Older');
        await repository.save(id: older.id, elements: [_rect('a')]);
        await repository.create('Newest');

        // Deliberately not awaiting `ready` first.
        final tap = model().openProject(older.id);
        await model().ready;
        await tap;

        expect(state().activeId, older.id);
        expect(canvas().elements.single.id, 'a');
        expect(state().error, isNull);
      },
    );

    test('opening a project swaps the canvas contents', () async {
      await model().ready;
      final first = state().activeId!;
      canvas().add(_rect('a'));
      await model().createProject('Second');

      expect(canvas().elements, isEmpty);

      await model().openProject(first);
      expect(canvas().elements.single.id, 'a');
    });

    test('re-opening the active project is a no-op', () async {
      await model().ready;
      final active = state().activeId!;
      canvas().add(_rect('a'));

      await model().openProject(active);

      expect(canvas().elements.single.id, 'a');
    });

    test(
      'a failed open keeps the canvas and keeps saving to the old project',
      () async {
        await model().ready;
        final active = state().activeId!;
        canvas().add(_rect('a'));

        await model().openProject('proj_missing');

        expect(state().error, contains('Could not open project'));
        expect(state().activeId, active);
        expect(canvas().elements.single.id, 'a');

        await model().flush();
        expect((await repository.load(active)).elements, hasLength(1));
      },
    );
  });

  group('mutations', () {
    test('rename flushes first so the pending edit survives', () async {
      await model().ready;
      final active = state().activeId!;
      canvas().add(_rect('a'));

      await model().renameProject(active, 'Renamed');

      expect(state().active?.name, 'Renamed');
      expect((await repository.load(active)).elements, hasLength(1));
    });

    test('deleting the active project opens the next one', () async {
      await model().ready;
      final first = state().activeId!;
      await model().createProject('Second');
      final second = state().activeId!;

      await model().deleteProject(second);

      expect(state().activeId, first);
      expect(state().projects.map((p) => p.id), [first]);
    });

    test('deleting the last project starts a fresh one', () async {
      await model().ready;

      await model().deleteProject(state().activeId!);

      expect(state().projects, hasLength(1));
      expect(state().active?.name, 'Untitled project');
    });

    test(
      'deleting does not resurrect the file via a pending autosave',
      () async {
        await model().ready;
        final doomed = state().activeId!;
        canvas().add(_rect('a'));

        await model().deleteProject(doomed);
        await model().flush();

        expect(
          File(
            '${tempDir.path}${Platform.pathSeparator}$doomed.json',
          ).existsSync(),
          isFalse,
        );
      },
    );
  });

  group('partially-readable project files', () {
    /// Plants a project file holding one element this build understands and
    /// one it does not — a scene saved by a newer FlowCraft, or a file a
    /// user hand-edited.
    Future<(FlowProject, File)> plantPartial() async {
      final project = await repository.create('Partial');
      final file = File(
        '${tempDir.path}${Platform.pathSeparator}${project.id}.json',
      );
      file.writeAsStringSync(
        jsonEncode({
          'version': 1,
          'project': project.toJson(),
          'scene': {
            'version': 1,
            'elements': [
              _rect('keeps-loading').toJson(),
              {'id': 'from_the_future', 'type': 'hexagon'},
            ],
          },
        }),
      );
      return (project, file);
    }

    test('opens what it can and says how much it could not', () async {
      final (project, _) = await plantPartial();

      await model().ready;

      expect(state().activeId, project.id);
      expect(canvas().elements.single.id, 'keeps-loading');
      expect(canvas().droppedOnLoad, 1);
      expect(canvas().sceneIsPartial, isTrue);
    });

    test('editing one does not overwrite the file on disk', () async {
      // The data-loss case this guard exists for: without it the ~800ms
      // autosave rewrites the reduced scene within a second of opening,
      // and the element that merely failed to *load* is gone for good.
      final (_, file) = await plantPartial();
      final before = file.readAsStringSync();

      await model().ready;
      canvas().add(_rect('drawn-after-opening'));
      // Comfortably past the real debounce this view model wires up.
      await Future<void>.delayed(const Duration(milliseconds: 1200));
      await model().flush();

      expect(file.readAsStringSync(), before);
      expect(before, contains('from_the_future'));
    });

    test('accepting the loss lets saving resume', () async {
      final (project, file) = await plantPartial();

      await model().ready;
      canvas().add(_rect('drawn-after-opening'));
      canvas().acknowledgePartialScene();
      await Future<void>.delayed(const Duration(milliseconds: 1200));
      await model().flush();

      expect(file.readAsStringSync(), isNot(contains('from_the_future')));
      expect((await repository.load(project.id)).elements.map((e) => e.id), [
        'keeps-loading',
        'drawn-after-opening',
      ]);
    });
  });

  group('linking a file', () {
    late Directory root;
    late String linkedPath;

    setUp(() {
      root = Directory.systemTemp.createTempSync('fc_link_vm_');
      final projects = Directory('${root.path}/home/.flowcraft/projects')
        ..createSync(recursive: true);
      Directory('${root.path}/out').createSync();
      linkedPath = '${root.path}/out/board.flowcraft';
      // Rebuild the container on a repo whose parent is the data dir.
      container.dispose();
      repository = ProjectRepository(directoryPath: projects.path);
      container = ProviderContainer(
        overrides: [projectRepositoryProvider.overrideWithValue(repository)],
      );
    });

    tearDown(() async {
      // The outer tearDown disposes the container once this has run.
      await container.read(projectsViewModelProvider.notifier).flush();
      root.deleteSync(recursive: true);
    });

    test('linkProject persists and mirrors', () async {
      await model().ready;
      final id = state().activeId!;
      canvas().add(_rect('a'));

      expect(await model().linkProject(id, linkedPath), isNull);

      expect(state().active?.linkedPath, linkedPath);
      expect(File(linkedPath).existsSync(), isTrue);
      expect(
        ProjectSerializer.decodeScene(
          File(linkedPath).readAsStringSync(),
        ).elements.map((e) => e.id),
        ['a'],
      );
      expect((await repository.list()).single.linkedPath, linkedPath);
    });

    test(
      'link refuses bad extension / missing parent / ~/.flowcraft path',
      () async {
        await model().ready;
        final id = state().activeId!;
        final data = '${root.path}/home/.flowcraft';

        for (final bad in [
          '${root.path}/out/board.txt',
          '${root.path}/missing/board.flowcraft',
          '$data/stolen.flowcraft',
          'relative/board.flowcraft',
        ]) {
          expect(await model().linkProject(id, bad), isNotNull, reason: bad);
        }
        expect(state().active?.linkedPath, isNull);
        expect(File('$data/stolen.flowcraft').existsSync(), isFalse);
      },
    );

    test('unlink stops mirroring', () async {
      await model().ready;
      final id = state().activeId!;
      await model().linkProject(id, linkedPath);
      await model().unlinkProject(id);
      File(linkedPath).deleteSync();

      canvas().add(_rect('later'));
      await model().flush();

      expect(state().active?.linkedPath, isNull);
      expect(File(linkedPath).existsSync(), isFalse);
    });
  });
}
