import 'dart:convert';
import 'dart:io';

import 'package:flowcraft/core/serialization/project_serializer.dart';
import 'package:flowcraft/core/serialization/sketch_serializer.dart';
import 'package:flowcraft/models/flow_project.dart';
import 'package:flowcraft/models/sketch_element.dart';
import 'package:flowcraft/services/export_file_sink_io.dart';
import 'package:flowcraft/services/scene_import_source.dart';

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
    final home =
        Platform.environment['HOME'] ??
        Platform.environment['USERPROFILE'] ??
        '.';
    final sep = Platform.pathSeparator;
    return '$home$sep.flowcraft${sep}projects';
  }

  static const String _indexFileName = 'index.json';
  static const String _sceneExtension = '.json';
  static const String _tempExtension = '.tmp';

  final Directory _directory;

  /// Told about a failure that must not fail the operation it happened in:
  /// a linked-file mirror that could not be written, or a linked file too
  /// damaged to read. The copy under `~/.flowcraft` is the safe one, so
  /// these are warnings for the view model to show, never exceptions.
  void Function(Object error)? onMirrorError;

  /// Headers of every project this instance has read or written, by id.
  ///
  /// [save] runs 800 ms after every edit and needs only the header to
  /// stamp a new `updatedAt` on — reading and `jsonDecode`-ing the whole
  /// previous save to get it cost a dropped frame per autosave on a large
  /// board. Every path that learns a header records it here; a miss falls
  /// back to the index and then the file, so nothing *depends* on the cache.
  final Map<String, FlowProject> _headers = <String, FlowProject>{};

  String get directoryPath => _directory.path;

  /// Every project, newest edit first. Broken files come back as
  /// [FlowProject.broken] entries so one bad file can't hide the rest.
  Future<List<FlowProject>> list() async {
    if (!await _directory.exists()) return const <FlowProject>[];

    final (ids, leftovers) = await _scan();
    await _sweep(leftovers);

    final indexed = await _readIndex();
    if (indexed != null && _covers(indexed, ids)) {
      _remember(indexed);
      return _sorted(indexed);
    }

    final rebuilt = await _rebuild(ids);
    await _writeIndex(rebuilt);
    _remember(rebuilt);
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
    var scene = ProjectSerializer.decodeScene(await file.readAsString());
    final linked = scene.project.linkedPath;
    if (linked != null) scene = await _preferNewer(scene, linked);
    _headers[id] = scene.project;
    return scene;
  }

  /// [local], or the linked file's scene when that file is newer — a repo
  /// pull or an edit in another tool. The slack absorbs the gap between
  /// [save] stamping `updatedAt` and its own mirror landing a moment later,
  /// which would otherwise make every save look like an outside edit.
  /// A linked file that is missing is simply ignored; one that can't be
  /// read falls back to the local scene and is reported.
  Future<FlowProjectScene> _preferNewer(
    FlowProjectScene local,
    String linked,
  ) async {
    try {
      final file = File(linked);
      if (!await file.exists()) return local;
      final newerThan = local.project.updatedAt.add(const Duration(seconds: 2));
      if (!(await file.stat()).modified.isAfter(newerThan)) return local;
      final remote = ProjectSerializer.decodeScene(await file.readAsString());
      return FlowProjectScene(
        project: local.project.copyWith(elementCount: remote.elements.length),
        elements: remote.elements,
        droppedCount: remote.droppedCount,
      );
    } catch (error) {
      onMirrorError?.call('Linked file $linked is unreadable: $error');
      return local;
    }
  }

  /// Overwrites [id]'s scene with [elements], bumping `updatedAt` and the
  /// element count. Returns the refreshed metadata.
  Future<FlowProject> save({
    required String id,
    required List<SketchElement> elements,
  }) async {
    final existing = _headers[id] ?? await _requireMeta(id);
    final updated = existing.copyWith(
      updatedAt: DateTime.now(),
      elementCount: elements.length,
      isBroken: false,
    );
    final source = await _writeScene(
      FlowProjectScene(project: updated, elements: elements),
    );
    _headers[id] = updated;
    await _upsertIndex(updated);
    final linked = updated.linkedPath;
    if (linked != null) {
      try {
        await _mirror(linked, source);
      } catch (error) {
        onMirrorError?.call('Could not update linked file $linked: $error');
      }
    }
    return updated;
  }

  /// Points [id] at [path].
  ///
  /// A path with no file yet gets the current scene written there straight
  /// away, so a bad path is refused now rather than on some later autosave;
  /// that returns `null`. A path that already holds a FlowCraft scene (a
  /// cloned repo's `docs/arch.flowcraft`) is *adopted*: the file is never
  /// written, this project's scene is replaced by its contents, and that
  /// scene is returned so the caller can put it on the canvas. Anything else
  /// there is refused. Nothing is persisted on a refusal.
  Future<FlowProjectScene?> link(String id, String path) async {
    final trimmed = path.trim();
    final lower = trimmed.toLowerCase();
    if (!lower.endsWith('.flowcraft') && !lower.endsWith('.json')) {
      throw const ExportPathException('file must end in .flowcraft or .json');
    }
    final target = SceneImportSource.expandHome(trimmed);
    final file = _sceneFile(id);
    if (!await file.exists()) throw StateError('No project with id "$id".');
    final source = await file.readAsString();
    final linked = ProjectSerializer.decodeHeader(
      source,
    ).copyWith(linkedPath: target, updatedAt: DateTime.now());

    final type = await FileSystemEntity.type(target, followLinks: false);
    if (type == FileSystemEntityType.notFound) {
      final next = ProjectSerializer.replaceHeader(source, linked);
      await _mirror(target, next);
      await _writeAtomic(file, next);
      _headers[id] = linked;
      await _upsertIndex(linked);
      return null;
    }

    final adopted = await _readLinkTarget(target, type, linked);
    await _writeAtomic(file, ProjectSerializer.encodeScene(adopted));
    _headers[id] = adopted.project;
    await _upsertIndex(adopted.project);
    return adopted;
  }

  /// Reads an existing link target as a scene, or throws why it can't be.
  ///
  /// ponytail: the path rules here (absolute, no `..`, not a symlink, not
  /// under the data directory) are a small copy of the ones in
  /// [ExportFileSink.writeTo], which only runs for writes; fold them into
  /// one shared check if a third caller needs them.
  Future<FlowProjectScene> _readLinkTarget(
    String target,
    FileSystemEntityType type,
    FlowProject linked,
  ) async {
    final file = File(target);
    if (!file.isAbsolute || target.split(RegExp(r'[\\/]')).contains('..')) {
      throw const ExportPathException(
        "path must be absolute (or start with ~/) and not contain '..'",
      );
    }
    if (type != FileSystemEntityType.file) {
      throw ExportPathException(
        '$target is a symlink or directory, not a file',
      );
    }
    final resolved = await file.resolveSymbolicLinks();
    final data = _directory.parent.path;
    String fold(String p) => Platform.isLinux ? p : p.toLowerCase();
    final root = fold(
      await Directory(data).exists()
          ? await Directory(data).resolveSymbolicLinks()
          : data,
    );
    if (fold(resolved).startsWith('$root${Platform.pathSeparator}')) {
      throw const ExportPathException(
        'refusing to link inside the FlowCraft data directory (~/.flowcraft)',
      );
    }
    try {
      if ((await file.stat()).size > maxSceneImportBytes) {
        throw const FormatException('too large');
      }
      final map = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      // Our own wrapper nests the scene; a plain export is the scene itself.
      // Anything else (`{}`, some other tool's JSON) is not ours to adopt.
      final scene = map['project'] is Map && map['scene'] is Map
          ? map['scene'] as Map<String, dynamic>
          : map;
      if (scene['elements'] is! List) throw const FormatException('no scene');
      final load = SketchSerializer.load(scene);
      return FlowProjectScene(
        project: linked.copyWith(elementCount: load.elements.length),
        elements: load.elements,
        droppedCount: load.droppedCount,
      );
    } catch (_) {
      throw ExportPathException('$target exists and is not a FlowCraft scene');
    }
  }

  /// Stops mirroring; the linked file is left on disk untouched.
  Future<FlowProject> unlink(String id) async {
    final file = _sceneFile(id);
    if (!await file.exists()) throw StateError('No project with id "$id".');
    final source = await file.readAsString();
    final plain = ProjectSerializer.decodeHeader(
      source,
    ).copyWith(clearLinkedPath: true);
    await _writeAtomic(file, ProjectSerializer.replaceHeader(source, plain));
    _headers[id] = plain;
    await _upsertIndex(plain);
    return plain;
  }

  /// All path policy (absolute, no `..`, parent exists, no symlink, nothing
  /// under the data directory) lives in [ExportFileSink.writeTo]; the data
  /// directory is this repository's own parent, `~/.flowcraft` by default.
  Future<void> _mirror(String path, String source) => ExportFileSink.writeTo(
    path,
    utf8.encode(source),
    overwrite: true,
    protectedDirectoryPath: _directory.parent.path,
  );

  Future<FlowProject> create(String name) async {
    await _directory.create(recursive: true);
    final project = FlowProject.create(name: normalizeName(name));
    await _writeScene(
      FlowProjectScene(project: project, elements: const <SketchElement>[]),
    );
    _headers[project.id] = project;
    await _upsertIndex(project);
    return project;
  }

  /// Renames in both places the name lives: the index and the scene file's
  /// own header. Skipping the header would make a rebuilt index silently
  /// revert the rename.
  ///
  /// Only the header is rewritten. The scene goes through
  /// [ProjectSerializer.replaceHeader] as opaque JSON, never through the
  /// decoder — a decode-and-re-encode would drop every element this build
  /// can't parse, and a user renaming a project a newer FlowCraft saved
  /// would lose those elements on disk without ever having pressed a key
  /// on the canvas.
  Future<FlowProject> rename(String id, String name) async {
    final file = _sceneFile(id);
    if (!await file.exists()) {
      throw StateError('No project with id "$id".');
    }
    final source = await file.readAsString();
    final renamed = ProjectSerializer.decodeHeader(
      source,
    ).copyWith(name: normalizeName(name), updatedAt: DateTime.now());
    await _writeAtomic(file, ProjectSerializer.replaceHeader(source, renamed));
    _headers[id] = renamed;
    await _upsertIndex(renamed);
    return renamed;
  }

  Future<void> delete(String id) async {
    final file = _sceneFile(id);
    if (await file.exists()) await file.delete();
    _headers.remove(id);
    // Rebuild rather than assume an empty index when it can't be read —
    // treating "unreadable" as "nothing else exists" would blank the index
    // for every surviving project until the next self-heal.
    final known = await _readIndex() ?? await _rebuild(await _sceneIds());
    await _writeIndex(known.where((project) => project.id != id).toList());
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
  Future<Set<String>> _sceneIds() async => (await _scan()).$1;

  /// One directory listing: the scene ids present, and the `*.tmp` files
  /// an interrupted [_writeAtomic] left behind.
  Future<(Set<String>, List<File>)> _scan() async {
    final ids = <String>{};
    final leftovers = <File>[];
    await for (final entity in _directory.list(followLinks: false)) {
      if (entity is! File) continue;
      final name = entity.uri.pathSegments.last;
      if (name.endsWith(_tempExtension)) {
        leftovers.add(entity);
        continue;
      }
      if (name == _indexFileName || !name.endsWith(_sceneExtension)) continue;
      final id = name.substring(0, name.length - _sceneExtension.length);
      // Some other JSON file sharing the directory, not a project of ours.
      if (!FlowProject.isValidId(id)) continue;
      ids.add(id);
    }
    return (ids, leftovers);
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
        final header = ProjectSerializer.decodeHeader(
          await _sceneFile(id).readAsString(),
        );
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

  /// Records the readable headers from a listing in [_headers].
  void _remember(List<FlowProject> projects) {
    for (final project in projects) {
      if (!project.isBroken) _headers[project.id] = project;
    }
  }

  /// The header for [id] when [_headers] has not seen it yet — the first
  /// save after launch, typically. The index is a small file and usually
  /// right; the project file itself is the fallback, read and parsed whole.
  /// Either way the file must exist: saving to a project that was never
  /// created is a caller bug and must stay loud.
  Future<FlowProject> _requireMeta(String id) async {
    final file = _sceneFile(id);
    if (!await file.exists()) {
      throw StateError('No project with id "$id".');
    }
    final indexed = await _readIndex();
    if (indexed != null) {
      for (final project in indexed) {
        if (project.id == id && !project.isBroken) return project;
      }
    }
    return ProjectSerializer.decodeHeader(await file.readAsString());
  }

  /// Returns the JSON written, so [save] can mirror the very same bytes.
  Future<String> _writeScene(FlowProjectScene scene) async {
    await _directory.create(recursive: true);
    final source = ProjectSerializer.encodeScene(scene);
    await _writeAtomic(_sceneFile(scene.project.id), source);
    return source;
  }

  /// Write-then-rename so a crash mid-save leaves the previous version
  /// intact instead of a half-written file the next launch can't parse.
  ///
  /// The temp name carries a counter because an autosave and a sidebar
  /// refresh can both be rewriting `index.json` at once; on a shared temp
  /// path the second writer's `rename` finds the file already moved and
  /// throws. A write that throws (disk full, the rename refused) removes
  /// its own temp file; only a crash can leave one, and [list] sweeps those.
  Future<void> _writeAtomic(File file, String contents) async {
    final temp = File('${file.path}.${_tempCounter++}$_tempExtension');
    _inFlightTemps.add(temp.path);
    try {
      await temp.writeAsString(contents, flush: true);
      await temp.rename(file.path);
    } catch (_) {
      await temp.delete().catchError((Object _) => temp);
      rethrow;
    } finally {
      _inFlightTemps.remove(temp.path);
    }
  }

  /// Deletes the `*.tmp` files a crash between write and rename left
  /// behind. [list] is the one moment the whole directory is being looked
  /// at anyway, so that is where it happens.
  ///
  /// Two guards keep it off a write that is merely *in progress*: temp
  /// paths this process is still writing are skipped by name, and anything
  /// modified in the last minute is left alone in case another FlowCraft
  /// process is mid-save in the same directory.
  Future<void> _sweep(List<File> leftovers) async {
    if (leftovers.isEmpty) return;
    final cutoff = DateTime.now().subtract(const Duration(minutes: 1));
    for (final leftover in leftovers) {
      if (_inFlightTemps.contains(leftover.path)) continue;
      try {
        if ((await leftover.stat()).modified.isAfter(cutoff)) continue;
        await leftover.delete();
      } catch (_) {
        // Best effort — a temp file that won't go is a nuisance, not a
        // reason to fail the listing.
      }
    }
  }

  /// Process-wide, because two repository instances on one directory (the
  /// tests do this) must not sweep each other's writes; the counter is
  /// process-wide for the same reason.
  static final Set<String> _inFlightTemps = <String>{};
  static int _tempCounter = 0;

  static bool _covers(List<FlowProject> indexed, Set<String> ids) {
    if (indexed.length != ids.length) return false;
    return indexed.every((project) => ids.contains(project.id));
  }

  static List<FlowProject> _sorted(List<FlowProject> projects) {
    return [...projects]..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  }
}
