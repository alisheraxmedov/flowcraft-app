import 'dart:io';

import 'package:flowcraft/flowcraft.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

const Duration _debounce = Duration(milliseconds: 20);

SketchRectangle _rect(String id) {
  return SketchRectangle.create(id: id, rect: const Rect.fromLTWH(0, 0, 4, 4));
}

Future<void> _pastDebounce() => Future<void>.delayed(_debounce * 4);

/// Stretches a save long enough to still be in flight when `detach` is
/// called, which is the window a delete has to race.
class _SlowRepository extends ProjectRepository {
  _SlowRepository({
    super.directoryPath,
    this.delay = const Duration(milliseconds: 300),
  });

  final Duration delay;

  @override
  Future<FlowProject> save({
    required String id,
    required List<SketchElement> elements,
  }) async {
    await Future<void>.delayed(delay);
    return super.save(id: id, elements: elements);
  }
}

/// Fails the first [failures] saves, then behaves — a disk that was full
/// for a moment, an antivirus holding the temp file during the rename.
class _FlakyRepository extends ProjectRepository {
  _FlakyRepository({super.directoryPath, this.failures = 1});

  int failures;
  int attempts = 0;

  @override
  Future<FlowProject> save({
    required String id,
    required List<SketchElement> elements,
  }) async {
    attempts++;
    if (failures > 0) {
      failures--;
      throw const FileSystemException('disk full');
    }
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

  test(
    'a timer armed for the old project cannot fire into the new one',
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
    },
  );

  test('detach abandons pending edits, for a project being deleted', () async {
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
    expect(
      autosave.hasPendingWrite,
      isFalse,
      reason: 'binding adopts the scene it was just handed',
    );

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
    test(
      'will not overwrite the file the missing elements are still in',
      () async {
        final project = await repository.create('A');
        await repository.save(
          id: project.id,
          elements: [_rect('a'), _rect('b')],
        );
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
      },
    );

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

  group('convergence', () {
    test("an edit drawn while unbind's write is in flight still reaches the "
        'outgoing project', () async {
      // Production shape: an 800ms debounce against a ~35ms write. With the
      // debounce *longer* than the write, the timer an in-flight edit arms
      // is still pending when unbind finishes — and used to fire after the
      // canvas had been swapped to the next project, writing nothing of
      // the outgoing one's last stroke anywhere.
      final slow = _SlowRepository(
        directoryPath: tempDir.path,
        delay: const Duration(milliseconds: 150),
      );
      final saver = ProjectAutosave(
        repository: slow,
        controller: controller,
        debounce: const Duration(milliseconds: 500),
      );
      addTearDown(saver.dispose);
      autosave.dispose();

      final a = await slow.create('A');
      final b = await slow.create('B');
      saver.bind(a.id);
      controller.add(_rect('a1'));

      final unbinding = saver.unbind(); // a1's write is now on disk
      await Future<void>.delayed(const Duration(milliseconds: 50));
      controller.add(_rect('a2')); // lands while that write is in flight
      await unbinding;

      controller.loadScene(const []);
      saver.bind(b.id);
      await Future<void>.delayed(const Duration(milliseconds: 600));
      await saver.flush();

      expect((await slow.load(a.id)).elements.map((e) => e.id), ['a1', 'a2']);
      expect((await slow.load(b.id)).elements, isEmpty);
    });

    test('flush converges, not just drains: a stroke during every write '
        'still ends up on disk', () async {
      final slow = _SlowRepository(
        directoryPath: tempDir.path,
        delay: const Duration(milliseconds: 60),
      );
      final saver = ProjectAutosave(
        repository: slow,
        controller: controller,
        debounce: const Duration(seconds: 10), // never fires on its own
      );
      addTearDown(saver.dispose);
      autosave.dispose();

      final project = await slow.create('A');
      saver.bind(project.id);
      controller.add(_rect('e0'));

      final flushing = saver.flush();
      for (var i = 1; i <= 3; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 30));
        controller.add(_rect('e$i'));
      }
      await flushing;

      expect((await slow.load(project.id)).elements.map((e) => e.id), [
        'e0',
        'e1',
        'e2',
        'e3',
      ]);
      expect(
        saver.hasPendingWrite,
        isFalse,
        reason: 'nothing left to write once flush has converged',
      );
    });
  });

  group('failed writes', () {
    test('flush retries a scene whose last write failed', () async {
      final flaky = _FlakyRepository(directoryPath: tempDir.path);
      final errors = <Object>[];
      final saver = ProjectAutosave(
        repository: flaky,
        controller: controller,
        debounce: _debounce,
        retryDelay: const Duration(minutes: 1), // keep the timer out of it
        onError: errors.add,
      );
      addTearDown(saver.dispose);
      autosave.dispose();

      final project = await flaky.create('A');
      saver.bind(project.id);
      controller.add(_rect('a'));
      await _pastDebounce(); // first write: thrown away by the disk
      expect(errors, hasLength(1), reason: 'precondition: the write failed');
      expect((await flaky.load(project.id)).elements, isEmpty);

      // No further edit — the user stepped away, or this is the exit hook.
      await saver.flush();

      expect((await flaky.load(project.id)).elements.single.id, 'a');
      expect(flaky.attempts, 2);
    });

    test('a transient failure is retried on its own, with backoff', () async {
      final flaky = _FlakyRepository(directoryPath: tempDir.path, failures: 2);
      final saver = ProjectAutosave(
        repository: flaky,
        controller: controller,
        debounce: _debounce,
        retryDelay: const Duration(milliseconds: 30),
        maxRetryDelay: const Duration(milliseconds: 40),
      );
      addTearDown(saver.dispose);
      autosave.dispose();

      final project = await flaky.create('A');
      saver.bind(project.id);
      controller.add(_rect('a'));
      await _pastDebounce();
      expect(saver.hasPendingRetry, isTrue);

      // 30ms, then 40ms (capped) — comfortably inside this wait.
      await Future<void>.delayed(const Duration(milliseconds: 300));

      expect(flaky.attempts, 3);
      expect(saver.hasPendingRetry, isFalse);
      expect((await flaky.load(project.id)).elements.single.id, 'a');
    });

    test('flush does not spin against a disk that keeps refusing', () async {
      final errors = <Object>[];
      final saver = ProjectAutosave(
        repository: repository,
        controller: controller,
        debounce: _debounce,
        retryDelay: const Duration(minutes: 1),
        onError: errors.add,
      );
      addTearDown(saver.dispose);
      autosave.dispose();

      saver.bind('proj_does_not_exist');
      controller.add(_rect('a'));

      await saver.flush().timeout(const Duration(seconds: 5));

      expect(errors, hasLength(1));
    });
  });

  test('rebind keeps the unsaved edits a detach abandoned', () async {
    // A delete that failed after `detach()`: the canvas still holds what
    // was unsaved, and binding afresh would adopt it as already written.
    final project = await repository.create('A');
    autosave.bind(project.id);
    controller.add(_rect('a'));
    await autosave.detach();
    expect((await repository.load(project.id)).elements, isEmpty);

    autosave.rebind(project.id);
    expect(autosave.hasPendingWrite, isTrue);
    await _pastDebounce();
    await autosave.flush();

    expect((await repository.load(project.id)).elements.single.id, 'a');
  });

  test('reports write failures instead of throwing into the caller', () async {
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
