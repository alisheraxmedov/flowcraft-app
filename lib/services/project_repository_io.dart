import 'dart:io';

import 'package:flowcraft/core/serialization/project_serializer.dart';
import 'package:flowcraft/models/flow_project.dart';
import 'package:flowcraft/models/sketch_element.dart';

/// File-backed store for saved whiteboards, one JSON file per project under
/// `~/.flowcraft/projects/` — the same config root the MCP control server
/// already writes its token into.
///
/// Layout:
///
/// ```text
/// ~/.flowcraft/projects/
///   index.json          metadata for every project, so listing is one read
///   proj_<id>.json      {version, project, scene} — the full whiteboard
/// ```
///
/// `index.json` is a cache, never the source of truth: [list] cross-checks
/// it against the scene files actually present (a directory listing, no
/// parsing) and rebuilds it from their headers whenever the two disagree or
/// the index is unreadable. Losing the index therefore costs one slow
/// listing, never a user's work.
class ProjectRepository {
  ProjectRepository({String? directoryPath})
      : _directory = Directory(directoryPath ?? defaultDirectoryPath());

  /// `~/.flowcraft/projects` (`%USERPROFILE%\.flowcraft\projects`).
  static String defaultDirectoryPath() {
    final home = Platform.environment['HOME'] ??
        Platform.environment['USERPROFILE'] ??
        '.';
    final sep = Platform.pathSeparator;
    return '$home$sep.flowcraft${sep}projects';
  }

  static const String _indexFileName = 'index.json';
  static const String _sceneExtension = '.json';

  final Directory _directory;

  String get directoryPath => _directory.path;

  /// Every project, newest edit first. Broken files come back as
  /// [FlowProject.broken] entries so one bad file can't hide the rest.
  Future<List<FlowProject>> list() async {
    if (!await _directory.exists()) return const <FlowProject>[];

    final ids = await _sceneIds();
    final indexed = await _readIndex();
    if (indexed != null && _covers(indexed, ids)) return _sorted(indexed);

    final rebuilt = await _rebuild(ids);
    await _writeIndex(rebuilt);
    return _sorted(rebuilt);
  }

  /// Reads one project's full scene. Throws if the file is missing or its
  /// JSON can't be parsed — callers decide whether that's fatal.
  ///
  /// A file whose JSON *is* readable but holds elements this build can't
  /// decode comes back with the good ones and a non-zero
  /// [FlowProjectScene.droppedCount]. Callers must not write that scene
  /// back through [save] without telling the user first: the reduced scene
  /// would overwrite the elements that failed to load.
  Future<FlowProjectScene> load(String id) async {
    final file = _sceneFile(id);
    if (!await file.exists()) {
      throw StateError('No project with id "$id".');
    }
    return ProjectSerializer.decodeScene(await file.readAsString());
  }

  /// Overwrites [id]'s scene with [elements], bumping `updatedAt` and the
  /// element count. Returns the refreshed metadata.
  Future<FlowProject> save({
    required String id,
    required List<SketchElement> elements,
  }) async {
    final existing = await _requireMeta(id);
    final updated = existing.copyWith(
      updatedAt: DateTime.now(),
      elementCount: elements.length,
      isBroken: false,
    );
    await _writeScene(FlowProjectScene(project: updated, elements: elements));
    await _upsertIndex(updated);
    return updated;
  }

  Future<FlowProject> create(String name) async {
    await _directory.create(recursive: true);
    final project = FlowProject.create(name: normalizeName(name));
    await _writeScene(
      FlowProjectScene(project: project, elements: const <SketchElement>[]),
    );
    await _upsertIndex(project);
    return project;
  }

  /// Renames in both places the name lives: the index and the scene file's
  /// own header. Skipping the header would make a rebuilt index silently
  /// revert the rename.
  Future<FlowProject> rename(String id, String name) async {
    final scene = await load(id);
    final renamed = scene.project.copyWith(
      name: normalizeName(name),
      updatedAt: DateTime.now(),
    );
    await _writeScene(
      FlowProjectScene(project: renamed, elements: scene.elements),
    );
    await _upsertIndex(renamed);
    return renamed;
  }

  Future<void> delete(String id) async {
    final file = _sceneFile(id);
    if (await file.exists()) await file.delete();
    // Rebuild rather than assume an empty index when it can't be read —
    // treating "unreadable" as "nothing else exists" would blank the index
    // for every surviving project until the next self-heal.
    final known = await _readIndex() ?? await _rebuild(await _sceneIds());
    await _writeIndex(
      known.where((project) => project.id != id).toList(),
    );
  }

  /// Collapses whitespace and caps the length so a pasted paragraph can't
  /// become a project name. Empty input becomes `Untitled`.
  static String normalizeName(String name) {
    final cleaned = name.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (cleaned.isEmpty) return 'Untitled';
    return cleaned.length <= 80 ? cleaned : cleaned.substring(0, 80);
  }

  // ── internals ──────────────────────────────────────────────────────────

  File get _indexFile => File(_join(_indexFileName));

  /// Every path this class builds out of an id goes through here, so this
  /// is the gate that keeps a crafted id from naming a file outside the
  /// projects directory — [FlowProject.isValidId] rejecting it at parse
  /// time is the first line, this is the one that cannot be routed around.
  File _sceneFile(String id) {
    if (!FlowProject.isValidId(id)) {
      throw ArgumentError.value(id, 'id', 'Not a usable project id');
    }
    return File(_join('$id$_sceneExtension'));
  }

  String _join(String fileName) =>
      '${_directory.path}${Platform.pathSeparator}$fileName';

  /// Ids of the scene files on disk. Cheap — filenames only, no reads.
  Future<Set<String>> _sceneIds() async {
    final ids = <String>{};
    await for (final entity in _directory.list(followLinks: false)) {
      if (entity is! File) continue;
      final name = entity.uri.pathSegments.last;
      if (name == _indexFileName || !name.endsWith(_sceneExtension)) continue;
      final id = name.substring(0, name.length - _sceneExtension.length);
      // Some other JSON file sharing the directory, not a project of ours.
      if (!FlowProject.isValidId(id)) continue;
      ids.add(id);
    }
    return ids;
  }

  Future<List<FlowProject>?> _readIndex() async {
    final file = _indexFile;
    if (!await file.exists()) return null;
    try {
      return ProjectSerializer.decodeIndex(await file.readAsString());
    } catch (_) {
      // Corrupt index — treated as absent so [list] rebuilds it.
      return null;
    }
  }

  Future<void> _writeIndex(List<FlowProject> projects) async {
    await _directory.create(recursive: true);
    await _writeAtomic(_indexFile, ProjectSerializer.encodeIndex(projects));
  }

  Future<void> _upsertIndex(FlowProject project) async {
    final projects = await _readIndex() ?? await _rebuild(await _sceneIds());
    final next = [
      for (final existing in projects)
        if (existing.id != project.id) existing,
      project,
    ];
    await _writeIndex(next);
  }

  Future<List<FlowProject>> _rebuild(Set<String> ids) async {
    final projects = <FlowProject>[];
    for (final id in ids) {
      try {
        final header =
            ProjectSerializer.decodeHeader(await _sceneFile(id).readAsString());
        // The file name decides which project this is, never the header:
        // the header belongs to whoever wrote the file, and every later
        // `load`/`delete` turns this id straight back into a path. A header
        // that disagrees with its own file name is broken by definition —
        // nothing this app writes can produce one.
        projects.add(header.id == id ? header : FlowProject.broken(id: id));
      } catch (_) {
        // One unreadable file must not abort the scan for the others.
        projects.add(FlowProject.broken(id: id));
      }
    }
    return projects;
  }

  /// Reads one project's header straight from its own file rather than via
  /// [list]. Autosave calls this every 800ms of drawing, and routing it
  /// through a full listing would mean a directory scan plus an index read
  /// per save — and a re-scan of the *whole* library on every save whenever
  /// one unparseable file is present.
  Future<FlowProject> _requireMeta(String id) async {
    final file = _sceneFile(id);
    if (!await file.exists()) {
      throw StateError('No project with id "$id".');
    }
    return ProjectSerializer.decodeHeader(await file.readAsString());
  }

  Future<void> _writeScene(FlowProjectScene scene) async {
    await _directory.create(recursive: true);
    await _writeAtomic(
      _sceneFile(scene.project.id),
      ProjectSerializer.encodeScene(scene),
    );
  }

  /// Write-then-rename so a crash mid-save leaves the previous version
  /// intact instead of a half-written file the next launch can't parse.
  ///
  /// The temp name carries a counter because an autosave and a sidebar
  /// refresh can both be rewriting `index.json` at once; on a shared temp
  /// path the second writer's `rename` finds the file already moved and
  /// throws.
  Future<void> _writeAtomic(File file, String contents) async {
    final temp = File('${file.path}.${_tempCounter++}.tmp');
    await temp.writeAsString(contents, flush: true);
    await temp.rename(file.path);
  }

  static int _tempCounter = 0;

  static bool _covers(List<FlowProject> indexed, Set<String> ids) {
    if (indexed.length != ids.length) return false;
    return indexed.every((project) => ids.contains(project.id));
  }

  static List<FlowProject> _sorted(List<FlowProject> projects) {
    return [...projects]
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  }
}
