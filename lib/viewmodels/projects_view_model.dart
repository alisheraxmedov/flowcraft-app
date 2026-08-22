import 'dart:async';

import 'dart:ui' show AppExitResponse;

import 'package:flutter/widgets.dart' show AppLifecycleListener;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flowcraft/models/flow_project.dart';
import 'package:flowcraft/models/sketch_element.dart';
import 'package:flowcraft/services/project_repository.dart';
import 'package:flowcraft/viewmodels/project_autosave.dart';
import 'package:flowcraft/viewmodels/projects_state.dart';
import 'package:flowcraft/viewmodels/sketch_controller.dart';

/// Storage for saved projects. Overridden in tests with a temp directory so
/// they never write into the real `~/.flowcraft`.
final projectRepositoryProvider = Provider<ProjectRepository>(
  (ref) => ProjectRepository(),
);

/// Owns the saved-project library and which project the canvas is editing.
///
/// The canvas itself stays in [SketchController]; this view model only
/// swaps element lists in and out of it and keeps the matching file up to
/// date via [ProjectAutosave]. It reaches the controller through
/// `ref.read` + the controller's own listener (never `ref.watch`) because
/// `sketchControllerProvider` is a non-reactive DI-only provider — see the
/// Riverpod 3 gotcha in CLAUDE.md.
class ProjectsViewModel extends Notifier<ProjectsState> {
  static const String _defaultProjectName = 'Untitled project';

  // `late final` initialised from `build()`, which is safe only while this
  // notifier never rebuilds. Keep `build()` free of `ref.watch` — a second
  // build would throw LateInitializationError instead of anything legible.
  late final ProjectRepository _repository;
  late final SketchController _controller;
  late final ProjectAutosave _autosave;

  /// Resolves once the startup restore has finished — either a project is
  /// open or the failure is in `state.error`. Lets callers await real
  /// readiness instead of guessing with a delay.
  late final Future<void> ready;

  /// Serialises everything that swaps the canvas. Startup restore runs
  /// unawaited, so a drawer tap can land mid-restore; without this queue the
  /// two interleave and the loser's `replaceAll` fires while autosave is
  /// already bound to the winner's project — writing one project's scene
  /// into the other's file.
  Future<void> _operations = Future<void>.value();

  bool _disposed = false;

  @override
  ProjectsState build() {
    _repository = ref.read(projectRepositoryProvider);
    _controller = ref.read(sketchControllerProvider);
    _autosave = ProjectAutosave(
      repository: _repository,
      controller: _controller,
      onSaved: _onSaved,
      onError: (error) => _fail('Autosave failed', error),
    );

    // Desktop windows can close without any widget being disposed first, so
    // the last debounced edit is flushed from the exit hook rather than
    // from a widget's `dispose`.
    final lifecycle = AppLifecycleListener(
      onExitRequested: () async {
        await flush();
        return AppExitResponse.exit;
      },
    );

    ref.onDispose(() {
      _disposed = true;
      lifecycle.dispose();
      // Best-effort only — `onDispose` can't be async, so this covers hot
      // restart and container teardown without a guarantee. The real
      // guarantee for a user quitting the app is `onExitRequested` above.
      unawaited(_autosave.flush());
      _autosave.dispose();
    });

    ready = _restore();
    return const ProjectsState();
  }

  /// Writes any debounced edit immediately. Safe to call at any time.
  Future<void> flush() => _autosave.flush();

  Future<void> refresh() async {
    try {
      final projects = await _repository.list();
      _set(state.copyWith(projects: projects, isLoading: false));
    } catch (error) {
      _fail('Could not list projects', error);
    }
  }

  /// Loads [id] onto the canvas, saving the outgoing project on the way out.
  Future<void> openProject(String id) => _queue(() => _openProject(id));

  Future<void> createProject(String name) => _queue(() => _createProject(name));

  Future<void> renameProject(String id, String name) =>
      _queue(() => _renameProject(id, name));

  Future<void> deleteProject(String id) => _queue(() => _deleteProject(id));

  /// Clears the last error banner once the user has read it.
  void dismissError() => _set(state.copyWith(clearError: true));

  // ── internals ──────────────────────────────────────────────────────────

  /// Runs [operation] after every previously-queued one. Errors are absorbed
  /// into the chain (each operation reports its own via [_fail]) so one
  /// failure can't wedge every later switch.
  Future<void> _queue(Future<void> Function() operation) {
    final result = _operations.then((_) => operation());
    _operations = result.catchError((Object _) {});
    return result;
  }

  Future<void> _openProject(String id) async {
    if (state.activeId == id) return;
    try {
      // Read the file *before* unbinding: strokes and MCP draw calls that
      // land while the disk is busy still belong to the outgoing project,
      // and unbind's flush is what captures them. Unbinding first would
      // leave that whole window unautosaved and then wipe it.
      final scene = await _repository.load(id);
      await _autosave.unbind();
      _replaceCanvas(scene.elements);
      _autosave.bind(id);
      _set(state.copyWith(activeId: id, clearError: true));
    } catch (error) {
      // Nothing was unbound if the load threw, so the outgoing project is
      // still being autosaved — no repair needed.
      _fail('Could not open project', error);
    }
    await refresh();
  }

  Future<void> _createProject(String name) async {
    try {
      final project = await _repository.create(name);
      await _autosave.unbind();
      _replaceCanvas(const <SketchElement>[]);
      _autosave.bind(project.id);
      _set(state.copyWith(activeId: project.id, clearError: true));
    } catch (error) {
      _fail('Could not create project', error);
    }
    await refresh();
  }

  Future<void> _renameProject(String id, String name) async {
    try {
      // Flush first: `rename` rewrites the scene file from what is on disk,
      // so an unwritten edit would be rolled back by the rename.
      if (state.activeId == id) await _autosave.flush();
      await _repository.rename(id, name);
      _set(state.copyWith(clearError: true));
    } catch (error) {
      _fail('Could not rename project', error);
    }
    await refresh();
  }

  Future<void> _deleteProject(String id) async {
    final wasActive = state.activeId == id;
    // `detach`, not `unbind` — flushing would recreate the file we are about
    // to remove. Awaited, so an already-started write finishes before the
    // delete rather than resurrecting the file afterwards.
    if (wasActive) await _autosave.detach();
    try {
      await _repository.delete(id);
      if (wasActive) _set(state.copyWith(clearActive: true, clearError: true));
    } catch (error) {
      if (wasActive) _autosave.bind(id);
      _fail('Could not delete project', error);
      return;
    }
    await refresh();
    if (wasActive) await _openMostRecent();
  }

  /// Queued as one unit so a drawer tap arriving mid-restore lands *after*
  /// the resumed project is on screen, rather than racing it.
  Future<void> _restore() {
    return _queue(() async {
      await refresh();
      if (state.activeId == null) await _openMostRecent();
    });
  }

  /// Resumes the newest readable project, or starts a fresh one. Auto-
  /// creating matters: without an active project autosave has no target,
  /// and the very problem this feature fixes is work vanishing on quit.
  ///
  /// Calls the unqueued forms — every caller is already inside [_queue], and
  /// re-entering it here would wait on the operation that is running.
  Future<void> _openMostRecent() async {
    for (final project in state.projects) {
      if (project.isBroken) continue;
      await _openProject(project.id);
      return;
    }
    await _createProject(_defaultProjectName);
  }

  void _replaceCanvas(List<SketchElement> elements) {
    // `loadScene`, not `replaceAll` — the latter snapshots the outgoing scene
    // into undo history, so an undo straight after a project switch would
    // pull the previous project's elements onto this canvas and autosave
    // would persist them into the wrong file.
    _controller.loadScene(elements);
  }

  void _onSaved(FlowProject saved) {
    _set(state.copyWith(
      projects: [
        saved,
        for (final project in state.projects)
          if (project.id != saved.id) project,
      ]..sort((a, b) => b.updatedAt.compareTo(a.updatedAt)),
    ));
  }

  void _fail(String summary, Object error) {
    _set(state.copyWith(isLoading: false, error: '$summary: $error'));
  }

  void _set(ProjectsState next) {
    if (_disposed) return;
    state = next;
  }
}

final projectsViewModelProvider =
    NotifierProvider<ProjectsViewModel, ProjectsState>(
  ProjectsViewModel.new,
);
