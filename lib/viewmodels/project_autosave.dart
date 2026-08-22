import 'dart:async';

import 'package:flowcraft/models/flow_project.dart';
import 'package:flowcraft/models/sketch_element.dart';
import 'package:flowcraft/services/project_repository.dart';
import 'package:flowcraft/viewmodels/sketch_controller.dart';

/// Keeps the active project's file in step with the live canvas, debounced.
///
/// A freehand stroke fires hundreds of controller notifications; writing on
/// each one would put the disk in the hot path of drawing. Edits are
/// therefore coalesced into one write per [debounce] of quiet.
///
/// The hazard that shapes this class is project switching: a timer armed
/// while project A was open must never fire after project B has been loaded
/// into the same controller, or A's drawing lands in B's file. Two rules
/// prevent it:
///
///  1. [unbind] flushes and detaches *before* the canvas is repopulated, so
///     during the swap there is no target and [_schedule] is inert.
///  2. Writes capture their element list and target id synchronously at
///     enqueue time, so a queued write can never observe a later scene.
class ProjectAutosave {
  ProjectAutosave({
    required ProjectRepository repository,
    required SketchController controller,
    this.debounce = const Duration(milliseconds: 800),
    this.onSaved,
    this.onError,
  })  : _repository = repository,
        _controller = controller {
    _controller.addListener(_schedule);
  }

  final ProjectRepository _repository;
  final SketchController _controller;
  final Duration debounce;
  final void Function(FlowProject saved)? onSaved;
  final void Function(Object error)? onError;

  String? _activeId;
  Timer? _timer;

  /// Serialises writes so a queued save can't overtake an earlier one and
  /// leave the older scene as the file's final state.
  Future<void> _writes = Future<void>.value();

  /// Project currently being autosaved, or `null` while detached.
  String? get activeId => _activeId;

  /// Whether a debounced write is waiting to fire.
  bool get hasPendingWrite => _timer != null;

  /// Starts tracking [projectId]. The caller must have [unbind]ed or
  /// [detach]ed the previous project first.
  ///
  /// A real throw rather than an `assert`, because the invariant it guards
  /// is a data-loss one and asserts are compiled out of the release builds
  /// users actually run.
  void bind(String projectId) {
    if (_activeId != null) {
      throw StateError(
        'Autosave is still bound to "$_activeId" — unbind() before binding '
        '"$projectId", or the next write could target the wrong project.',
      );
    }
    _activeId = projectId;
  }

  /// Writes any pending edits to the current project, then detaches.
  Future<void> unbind() async {
    await flush();
    _activeId = null;
  }

  /// Detaches without saving — for a project that is being deleted, where
  /// a flush would just recreate the file we are about to remove.
  ///
  /// Still awaits the write queue: cancelling the timer does nothing for a
  /// save that already started, and letting that one land *after* the
  /// delete would recreate the file and resurrect the project.
  Future<void> detach() async {
    _timer?.cancel();
    _timer = null;
    _activeId = null;
    await _writes;
  }

  /// Forces the pending write (if any) and waits for the queue to drain.
  Future<void> flush() async {
    final id = _activeId;
    final pending = _timer != null;
    _timer?.cancel();
    _timer = null;
    if (pending && id != null) _enqueue(id);
    await _writes;
  }

  void _schedule() {
    if (_activeId == null) return;
    _timer?.cancel();
    _timer = Timer(debounce, _onQuiet);
  }

  void _onQuiet() {
    _timer = null;
    final id = _activeId;
    if (id == null) return;
    _enqueue(id);
  }

  void _enqueue(String id) {
    // Read the scene *now*, on the same turn of the event loop the write was
    // decided on — deferring it into the async body would let a project
    // switch slip in between and hand this write the wrong elements.
    final List<SketchElement> elements = _controller.elements;
    _writes = _writes.then((_) async {
      final saved = await _repository.save(id: id, elements: elements);
      onSaved?.call(saved);
    }).catchError((Object error) {
      onError?.call(error);
    });
  }

  void dispose() {
    _timer?.cancel();
    _timer = null;
    _controller.removeListener(_schedule);
  }
}
