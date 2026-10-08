import 'dart:ui' show Rect;
import 'package:flowcraft/models/sketch_element.dart';

/// Which elements a [SketchFrame] contains.
///
/// Membership is computed, not stored: an element belongs to a frame while
/// its bounds lie wholly inside the frame's rect. Moving an element out
/// therefore releases it with no bookkeeping, and there is no id to go stale.
class FrameMembership {
  const FrameMembership._();

  /// Elements of [els] (other than [frame] itself) wholly inside
  /// [frame]`.rect`. An element merely overlapping the border is not a
  /// member. Nested frames count like any other element.
  static List<SketchElement> members(
    SketchFrame frame,
    List<SketchElement> els,
  ) {
    final r = frame.rect;
    return [
      for (final e in els)
        if (e.id != frame.id && _inside(r, e.bounds)) e,
    ];
  }

  static bool _inside(Rect outer, Rect inner) =>
      inner.left >= outer.left &&
      inner.top >= outer.top &&
      inner.right <= outer.right &&
      inner.bottom <= outer.bottom;
}
