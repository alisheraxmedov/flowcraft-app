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
///
/// Two further rules decide whether a notification is worth a write at all:
/// it must have moved [SketchController.paintGen] (selection changes notify
/// but change no content), and the canvas must not be a partial read of its
/// own file (see [SketchController.sceneIsPartial]). Both live in
/// [_needsWrite].
class ProjectAutosave {
  ProjectAutosave({
    required ProjectRepository repository,
    required SketchController controller,
    this.debounce = const Duration(milliseconds: 800),
    this.retryDelay = const Duration(seconds: 2),
    this.maxRetryDelay = const Duration(seconds: 30),
    this.onSaved,
    this.onError,
  }) : _repository = repository,
       _controller = controller,
       _nextRetryDelay = retryDelay {
    _controller.addListener(_schedule);
  }

  final ProjectRepository _repository;
  final SketchController _controller;
  final Duration debounce;

  /// How long after a failed write the next unprompted attempt waits. Each
  /// further failure doubles it, up to [maxRetryDelay]; a success resets it.
  ///
  /// Transient failures are routine — an antivirus holding the freshly
  /// written temp file during the rename on Windows, a disk that is full
  /// for a moment — and a user who draws one stroke and then steps away
  /// must not need a *second* stroke for the first one to be retried.
  final Duration retryDelay;
  final Duration maxRetryDelay;

  final void Function(FlowProject saved)? onSaved;
  final void Function(Object error)? onError;

  String? _activeId;
  Timer? _timer;
  Timer? _retryTimer;
  Duration _nextRetryDelay;

  /// [SketchController.paintGen] the bound project's file is believed to
  /// hold. Anything else on the canvas means unsaved content.
  ///
  /// A generation rather than a dirty flag, because the flag would have to
  /// be cleared at exactly the moment a write captures the scene — and a
  /// stroke drawn *during* that write would clear with it and never be
  /// saved. Comparing generations makes the later edit visibly newer than
  /// what was captured, so it schedules its own write.
  int _savedGen = -1;

  /// Whether the most recent write to finish threw. [flush] uses it to stop
  /// re-enqueueing against a disk that is persistently refusing — one
  /// attempt per flush is the retry; the backoff timer takes it from there.
  bool _lastWriteFailed = false;

  /// Serialises writes so a queued save can't overtake an earlier one and
  /// leave the older scene as the file's final state.
  Future<void> _writes = Future<void>.value();

  /// Project currently being autosaved, or `null` while detached.
  String? get activeId => _activeId;

  /// Whether a debounced write is waiting to fire.
  bool get hasPendingWrite => _timer != null;

  /// Whether a failed write is waiting for its backoff retry.
  bool get hasPendingRetry => _retryTimer != null;

  /// Starts tracking [projectId]. The caller must have [unbind]ed or
  /// [detach]ed the previous project first.
  ///
  /// A real throw rather than an `assert`, because the invariant it guards
  /// is a data-loss one and asserts are compiled out of the release builds
  /// users actually run.
  void bind(String projectId) {
    _bind(projectId);
    // Binding follows the `loadScene` that put this project's own file on
    // the canvas, so the two already agree — adopting the generation here
    // stops that load from being mistaken for an edit and written straight
    // back, which would bump `updatedAt` on a project merely opened.
    _savedGen = _controller.paintGen;
  }

  /// Re-attaches to [projectId] after a [detach] that turned out to be
  /// premature — a delete that failed — *without* adopting the canvas as
  /// saved. Whatever was unsaved when the detach discarded its timer is
  /// still unsaved, and this schedules it again.
  void rebind(String projectId) {
    _bind(projectId);
    _schedule();
  }

  void _bind(String projectId) {
    if (_activeId != null) {
      throw StateError(
        'Autosave is still bound to "$_activeId" — unbind() before binding '
        '"$projectId", or the next write could target the wrong project.',
      );
    }
    _activeId = projectId;
  }

  /// Writes any pending edits to the current project, then detaches.
  ///
  /// The id is cleared only once [flush] has converged — a stroke landing
  /// while the outgoing write is on disk must still reach the outgoing
  /// file, and clearing earlier would leave it with nowhere to go.
  Future<void> unbind() async {
    await flush();
    _cancelTimers();
    _activeId = null;
  }

  /// Detaches without saving — for a project that is being deleted, where
  /// a flush would just recreate the file we are about to remove.
  ///
  /// Still awaits the write queue: cancelling the timer does nothing for a
  /// save that already started, and letting that one land *after* the
  /// delete would recreate the file and resurrect the project.
  Future<void> detach() async {
    _cancelTimers();
    _activeId = null;
    await _writes;
  }

  /// Writes the scene until the file holds what the canvas shows, then
  /// waits for the queue to drain.
  ///
  /// Keyed on the generation rather than on whether a timer was armed: a
  /// timer says an edit is *waiting*, but an edit drawn while an earlier
  /// write was still on disk, or a write that failed, leave the canvas
  /// ahead of the file with no timer to show for it. Each pass captures
  /// the newest scene, so the loop ends at the first quiet moment. A pass
  /// that fails stops the loop — the caller is told through [onError] and
  /// the backoff timer retries — instead of spinning against a dead disk.
  Future<void> flush() async {
    final id = _activeId;
    if (id == null) {
      await _writes;
      return;
    }
    _cancelTimers();
    while (_activeId == id && _needsWrite()) {
      _enqueue(id);
      await _writes;
      if (_lastWriteFailed) break;
    }
    await _writes;
    // Converged: a timer armed by an edit the loop already captured would
    // only find nothing to write.
    if (!_needsWrite()) {
      _timer?.cancel();
      _timer = null;
    }
  }

  /// Whether the canvas holds content the file does not. See the class doc
  /// for why selection changes and partial scenes are excluded.
  bool _needsWrite() {
    if (_controller.paintGen == _savedGen) return false;
    // Refuse to write a scene that is smaller than the file it came from.
    // The elements that failed to decode are still in that file and still
    // recoverable; a debounced write of what did load would overwrite them
    // within a second of opening the project. `acknowledgePartialScene`
    // notifies, so accepting the loss re-enters here and saves the edits
    // made in the meantime.
    if (_controller.sceneIsPartial) return false;
    return true;
  }

  void _schedule() {
    if (_activeId == null) return;

    // Selection is not content. `SketchController` notifies on selection,
    // tool and text-edit changes too, so scheduling off the bare
    // notification meant *clicking* an element queued a disk write of an
    // unmodified scene — which bumped `updatedAt` and re-sorted the project
    // sidebar under the user's cursor. `paintGen` moves only on a visual
    // mutation, so it is the honest "did the scene change" signal.
    if (!_needsWrite()) return;

    _timer?.cancel();
    _timer = Timer(debounce, _onQuiet);
  }

  void _onQuiet() {
    _timer = null;
    final id = _activeId;
    if (id == null || !_needsWrite()) return;
    _enqueue(id);
  }

  void _onRetry() {
    _retryTimer = null;
    final id = _activeId;
    // A project bound since the failure adopted its own generation, so
    // this is a no-op for it — the retry belongs to the scene that failed.
    if (id == null || !_needsWrite()) return;
    _enqueue(id);
  }

  void _enqueue(String id) {
    // Read the scene *now*, on the same turn of the event loop the write was
    // decided on — deferring it into the async body would let a project
    // switch slip in between and hand this write the wrong elements.
    final List<SketchElement> elements = _controller.elements;
    final gen = _controller.paintGen;
    _savedGen = gen;
    _writes = _writes
        .then((_) async {
          final saved = await _repository.save(id: id, elements: elements);
          _lastWriteFailed = false;
          _nextRetryDelay = retryDelay;
          onSaved?.call(saved);
        })
        .catchError((Object error) {
          _lastWriteFailed = true;
          // The file never received this scene, so it must not go on counting
          // as saved — otherwise one failed write would leave every later edit
          // looking already-persisted and nothing would ever retry. `-1` can't
          // equal any real generation, so the next check reschedules. Unless a
          // newer write has been enqueued meanwhile: that one carries a newer
          // scene, and its own outcome decides.
          if (_savedGen == gen) _savedGen = -1;
          _armRetry();
          onError?.call(error);
        });
  }

  void _armRetry() {
    if (_activeId == null) return;
    _retryTimer?.cancel();
    _retryTimer = Timer(_nextRetryDelay, _onRetry);
    final doubled = _nextRetryDelay * 2;
    _nextRetryDelay = doubled > maxRetryDelay ? maxRetryDelay : doubled;
  }

  void _cancelTimers() {
    _timer?.cancel();
    _timer = null;
    _retryTimer?.cancel();
    _retryTimer = null;
  }

  void dispose() {
    _cancelTimers();
    _controller.removeListener(_schedule);
  }
}
