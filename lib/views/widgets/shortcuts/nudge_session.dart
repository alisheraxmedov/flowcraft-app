import 'dart:async';
import 'dart:ui' show Offset;

import 'package:flowcraft/viewmodels/sketch_controller.dart';

/// Turns a burst of arrow-key nudges into one undo entry.
///
/// Two problems it solves at once. [SketchController.translateSelected]
/// pushes history only through a *drag session* — outside one it moves the
/// selection and records nothing, so a bare nudge would be un-undoable. And
/// a held arrow key repeats at the OS rate, so one entry per keystroke would
/// push fifty snapshots through a fifty-deep history and evict everything
/// the user actually did.
///
/// Opening a drag session and closing it after [window] of quiet gives
/// keyboard moves the same shape as a mouse drag: one entry per gesture,
/// undoing the whole run.
class NudgeSession {
  NudgeSession(
    this._controller, {
    this.window = const Duration(milliseconds: 350),
  });

  final SketchController _controller;

  /// How long after the last nudge the run is considered finished.
  final Duration window;

  Timer? _timer;

  /// Moves the selection by [delta] canvas pixels, joining the run in
  /// progress or starting a new one.
  void nudge(Offset delta) {
    if (!_controller.hasSelection) return;
    _controller.beginDragSession();
    _controller.translateSelected(delta);
    _timer?.cancel();
    _timer = Timer(window, _end);
  }

  void _end() {
    _timer = null;
    _controller.endDragSession();
  }

  /// Closes any open run. Call before the controller goes away.
  void dispose() {
    _timer?.cancel();
    _timer = null;
  }
}
