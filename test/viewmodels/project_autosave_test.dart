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
