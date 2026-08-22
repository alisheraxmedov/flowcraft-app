import 'dart:io';

import 'package:flowcraft/flowcraft.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

const Duration _debounce = Duration(milliseconds: 20);

SketchRectangle _rect(String id) {
  return SketchRectangle.create(id: id, rect: const Rect.fromLTWH(0, 0, 4, 4));
}

Future<void> _pastDebounce() =>
    Future<void>.delayed(_debounce * 4);

/// Stretches a save long enough to still be in flight when `detach` is
/// called, which is the window a delete has to race.
class _SlowRepository extends ProjectRepository {
  _SlowRepository({super.directoryPath});

  @override
  Future<FlowProject> save({
    required String id,
    required List<SketchElement> elements,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    return super.save(id: id, elements: elements);
  }
}

void main() {
  late Directory tempDir;
  late ProjectRepository repository;
  late SketchController controller;
  late ProjectAutosave autosave;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('fc_autosave_');
    repository = ProjectRepository(directoryPath: tempDir.path);
    controller = SketchController();
    autosave = ProjectAutosave(
      repository: repository,
      controller: controller,
      debounce: _debounce,
    );
  });

  tearDown(() {
    autosave.dispose();
    controller.dispose();
    tempDir.deleteSync(recursive: true);
  });

  test('coalesces a burst of edits into a single write', () async {
    final project = await repository.create('A');
    autosave.bind(project.id);

    for (var i = 0; i < 20; i++) {
      controller.add(_rect('e$i'));
    }
    expect(autosave.hasPendingWrite, isTrue);

    await _pastDebounce();
    await autosave.flush();

    expect((await repository.load(project.id)).elements, hasLength(20));
  });

  test('writes nothing while unbound', () async {
    final project = await repository.create('A');

    controller.add(_rect('a'));
    await _pastDebounce();
    await autosave.flush();

    expect((await repository.load(project.id)).elements, isEmpty);
  });

  test('unbind flushes the pending edit to the outgoing project', () async {
    final project = await repository.create('A');
    autosave.bind(project.id);
    controller.add(_rect('a'));

    // Deliberately *before* the debounce elapses.
    await autosave.unbind();

    expect(autosave.activeId, isNull);
    expect((await repository.load(project.id)).elements, hasLength(1));
  });

  test('a timer armed for the old project cannot fire into the new one',
      () async {
    final a = await repository.create('A');
    final b = await repository.create('B');

    autosave.bind(a.id);
    controller.add(_rect('from-a'));

    // The switch sequence the view model performs: flush + detach, swap the
    // canvas, then bind. The canvas swap notifies while unbound.
    await autosave.unbind();
    controller.replaceAll(const []);
    autosave.bind(b.id);

    await _pastDebounce();
    await autosave.flush();

    expect((await repository.load(a.id)).elements.single.id, 'from-a');
    expect((await repository.load(b.id)).elements, isEmpty);
  });

  test('detach abandons pending edits, for a project being deleted',
      () async {
    final project = await repository.create('A');
    autosave.bind(project.id);
    controller.add(_rect('a'));

    autosave.detach();
    await _pastDebounce();
    await autosave.flush();

    expect((await repository.load(project.id)).elements, isEmpty);
  });

  test('detach does not return while a write is still in flight', () async {
    // The delete that follows a detach must not race a save that already
    // started — so detach has to drain the queue, not just cancel the timer.
    final slow = _SlowRepository(directoryPath: tempDir.path);
    var saveCompleted = false;
    final saver = ProjectAutosave(
      repository: slow,
      controller: controller,
      debounce: _debounce,
      onSaved: (_) => saveCompleted = true,
    );
    addTearDown(saver.dispose);
    autosave.dispose(); // Only one autosave may watch the controller here.

    final project = await slow.create('A');
    saver.bind(project.id);
    controller.add(_rect('a'));
    await _pastDebounce(); // Timer has fired; the slow save is running.
    expect(saveCompleted, isFalse, reason: 'precondition: write in flight');

    await saver.detach();

    expect(saveCompleted, isTrue);
  });

  test('binding over a live project is refused, in release builds too', () {
    autosave.bind('proj_a');

    expect(() => autosave.bind('proj_b'), throwsA(isA<StateError>()));
  });

  test('a selection change is not an edit and schedules no write', () async {
    // The bug: `_schedule` hung off every ChangeNotifier notification, and
    // selecting notifies — so clicking a shape queued a write of an
    // unmodified scene, bumping `updatedAt` and re-sorting the sidebar.
    final project = await repository.create('A');
    controller.add(_rect('a'));
    autosave.bind(project.id);
    expect(autosave.hasPendingWrite, isFalse,
        reason: 'binding adopts the scene it was just handed');

    controller.select('a');
    controller.currentTool = SketchTool.rectangle;
    controller.clearSelection();

    expect(autosave.hasPendingWrite, isFalse);
  });

  test('a real edit still schedules, after a selection change', () async {
    final project = await repository.create('A');
    autosave.bind(project.id);

    controller.add(_rect('a'));
    controller.select('a');

    expect(autosave.hasPendingWrite, isTrue);
    await _pastDebounce();
    await autosave.flush();
    expect((await repository.load(project.id)).elements, hasLength(1));
  });

  group('partially-loaded scenes', () {
    test('will not overwrite the file the missing elements are still in',
        () async {
      final project = await repository.create('A');
      await repository.save(id: project.id, elements: [_rect('a'), _rect('b')]);
      final file = File('${tempDir.path}/${project.id}.json');
      final before = file.readAsStringSync();

      // What opening a file with one unreadable element leaves behind.
      controller.loadScene([_rect('a')], droppedOnLoad: 1);
      autosave.bind(project.id);
      controller.add(_rect('c'));

      expect(autosave.hasPendingWrite, isFalse);
      await _pastDebounce();
      await autosave.flush();

      expect(file.readAsStringSync(), before);
    });

    test('accepting the loss saves the edits made in the meantime', () async {
      final project = await repository.create('A');
      await repository.save(id: project.id, elements: [_rect('a'), _rect('b')]);

      controller.loadScene([_rect('a')], droppedOnLoad: 1);
      autosave.bind(project.id);
      controller.add(_rect('c'));

      controller.acknowledgePartialScene();

      // The edit predates the acknowledgement, so re-arming has to notice it
      // rather than waiting for the *next* stroke.
      expect(autosave.hasPendingWrite, isTrue);
      await _pastDebounce();
      await autosave.flush();

      final saved = await repository.load(project.id);
      expect(saved.elements.map((e) => e.id), ['a', 'c']);
    });
  });

  test('reports write failures instead of throwing into the caller',
      () async {
    Object? reported;
    final failing = ProjectAutosave(
      repository: repository,
      controller: controller,
      debounce: _debounce,
      onError: (error) => reported = error,
    );
    addTearDown(failing.dispose);

    failing.bind('proj_does_not_exist');
    controller.add(_rect('a'));
    await _pastDebounce();
    await failing.flush();

    expect(reported, isA<StateError>());
  });
}
