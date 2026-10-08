import 'package:flowcraft/flowcraft.dart';

/// In-memory stand-in for [ProjectRepository], for widget tests.
///
/// `testWidgets` runs its body inside a fake-async zone that never pumps the
/// real event loop, so a `dart:io`-backed repository would deadlock the
/// moment a tap triggered a file write. This fake resolves through
/// microtasks instead, which the fake clock does drain.
///
/// Timestamps come from a monotonic fake clock rather than `DateTime.now()`,
/// so "most recently updated" ordering is deterministic instead of depending
/// on how fast the machine ran the test.
class FakeProjectRepository implements ProjectRepository {
  final Map<String, FlowProjectScene> _scenes = <String, FlowProjectScene>{};

  /// Ids whose file would fail to parse — surfaced as broken entries.
  final Set<String> brokenIds = <String>{};

  DateTime _clock = DateTime(2026, 1, 1);

  DateTime _tick() => _clock = _clock.add(const Duration(seconds: 1));

  @override
  void Function(Object error)? onMirrorError;

  @override
  String get directoryPath => 'memory';

  @override
  Future<List<FlowProject>> list() async {
    return <FlowProject>[
      for (final scene in _scenes.values) scene.project,
      for (final id in brokenIds) FlowProject.broken(id: id),
    ]..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  }

  @override
  Future<FlowProjectScene> load(String id) async {
    final scene = _scenes[id];
    if (scene == null) throw StateError('No project with id "$id".');
    return scene;
  }

  @override
  Future<FlowProject> save({
    required String id,
    required List<SketchElement> elements,
  }) async {
    final existing = (await load(id)).project;
    final updated = existing.copyWith(
      updatedAt: _tick(),
      elementCount: elements.length,
    );
    _scenes[id] = FlowProjectScene(
      project: updated,
      elements: List<SketchElement>.of(elements),
    );
    return updated;
  }

  @override
  Future<FlowProject> create(String name) async {
    final project = FlowProject.create(
      name: ProjectRepository.normalizeName(name),
      now: _tick(),
    );
    _scenes[project.id] = FlowProjectScene(
      project: project,
      elements: const <SketchElement>[],
    );
    return project;
  }

  @override
  Future<FlowProject> rename(String id, String name) async {
    final scene = await load(id);
    final renamed = scene.project.copyWith(
      name: ProjectRepository.normalizeName(name),
      updatedAt: _tick(),
    );
    _scenes[id] = FlowProjectScene(project: renamed, elements: scene.elements);
    return renamed;
  }

  /// Only the extension rule is simulated — path policy belongs to the real
  /// repository's tests.
  @override
  Future<FlowProject> link(String id, String path) async {
    if (!path.endsWith('.flowcraft') && !path.endsWith('.json')) {
      throw const ExportPathException('file must end in .flowcraft or .json');
    }
    final scene = await load(id);
    final linked = scene.project.copyWith(linkedPath: path, updatedAt: _tick());
    _scenes[id] = FlowProjectScene(project: linked, elements: scene.elements);
    return linked;
  }

  @override
  Future<FlowProject> unlink(String id) async {
    final scene = await load(id);
    final plain = scene.project.copyWith(clearLinkedPath: true);
    _scenes[id] = FlowProjectScene(project: plain, elements: scene.elements);
    return plain;
  }

  @override
  Future<void> delete(String id) async {
    _scenes.remove(id);
    brokenIds.remove(id);
  }
}
