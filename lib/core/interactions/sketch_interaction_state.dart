import 'package:flutter/foundation.dart';

import 'package:flowcraft/core/interactions/sketch_drag_session.dart';

/// Holds the currently-active [SketchDragSession] (if any) and notifies
/// listeners on every change, so the preview layer can repaint in real
/// time without coupling to [SketchController].
class SketchInteractionState extends ChangeNotifier {
  SketchDragSession? _session;
  int _revision = 0;

  SketchDragSession? get session => _session;

  /// Monotonic counter bumped on every begin/mutation/end. The preview
  /// painter compares this (rather than the mutable session contents) in
  /// [CustomPainter.shouldRepaint] to reliably detect in-place updates.
  int get revision => _revision;

  void begin(SketchDragSession session) {
    _session = session;
    _revision++;
    notifyListeners();
  }

  /// Bumps a notification without replacing the session reference —
  /// used after mutating the existing session (e.g. appending a freedraw
  /// point or moving the current pointer position).
  void notifyChanged() {
    if (_session != null) {
      _revision++;
      notifyListeners();
    }
  }

  void end() {
    if (_session == null) return;
    _session = null;
    _revision++;
    notifyListeners();
  }
}
