import 'dart:math' as math;
import 'dart:ui';

/// A line the drag is currently snapped to, in canvas-space.
///
/// Drawn while the drag is live, because a snap with no visible cause reads
/// as the canvas fighting the user: the guide is what turns "it refused to
/// go where I put it" into "it lined up with that".
class AlignmentGuide {
  const AlignmentGuide({
    required this.vertical,
    required this.position,
    required this.from,
    required this.to,
  });

  /// True for a guide at a constant x, false for one at a constant y.
  final bool vertical;

  /// Canvas x (vertical guide) or canvas y (horizontal guide) of the line.
  final double position;

  /// Extent of the line along the other axis. Spans both the moving
  /// selection and the element it lined up with, so the pairing is legible
  /// without any further decoration.
  final double from;
  final double to;

  @override
  bool operator ==(Object other) =>
      other is AlignmentGuide &&
      other.vertical == vertical &&
      other.position == position &&
      other.from == from &&
      other.to == to;

  @override
  int get hashCode => Object.hash(vertical, position, from, to);

  @override
  String toString() =>
      'AlignmentGuide(${vertical ? 'x' : 'y'}=$position, $from..$to)';
}

/// The correction a snap wants applied, plus the guides that explain it.
class SnapResult {
  const SnapResult(this.delta, this.guides);

  static const SnapResult none = SnapResult(Offset.zero, <AlignmentGuide>[]);

  /// Canvas-space nudge the caller should add to whatever it was about to
  /// apply. [Offset.zero] when nothing was near enough to snap to.
  final Offset delta;

  final List<AlignmentGuide> guides;
}

/// Quantises a live drag onto the background grid and onto the edges and
/// centres of the elements around it.
///
/// [threshold] and [searchRadius] are canvas-space, because that is what the
/// geometry being compared is measured in. Callers convert from screen
/// pixels by dividing by zoom — exactly like the gesture handler's hit
/// tolerance — so a magnet stays the same size under the user's hand at 4x
/// as at 0.25x instead of becoming 16x stickier across that range.
class SketchSnapper {
  const SketchSnapper({
    required this.threshold,
    this.gridSpacing,
    this.searchRadius = 800.0,
  });

  /// How far a value may sit from a target and still be pulled onto it.
  final double threshold;

  /// Background-grid spacing, or `null` to snap to elements only.
  final double? gridSpacing;

  /// How far from the moving box an element may be and still be worth
  /// aligning to. This is what keeps the per-pointer-move scan cheap
  /// without a spatial index: candidates outside the window are rejected by
  /// four comparisons before any edge arithmetic happens.
  final double searchRadius;

  /// Resolves a snap for a drag whose moving geometry occupies [moving].
  ///
  /// [xs] / [ys] are the canvas values that want to line up with something —
  /// a move offers its box's left/centre/right, a resize only the edges its
  /// handle drives, an endpoint drag just the point.
  ///
  /// [gridXs] / [gridYs] default to [xs] / [ys], and a move deliberately
  /// passes a shorter list: pinning the selection's *origin* to the grid is
  /// predictable, whereas letting its centre or trailing edge win means a
  /// box whose size is not a multiple of the spacing never lands on the same
  /// relationship to the grid twice.
  SnapResult resolve({
    required Rect moving,
    required List<double> xs,
    required List<double> ys,
    required List<Rect> candidates,
    List<double>? gridXs,
    List<double>? gridYs,
  }) {
    if (threshold <= 0) return SnapResult.none;

    final x = _AxisBest(threshold);
    final y = _AxisBest(threshold);

    for (final candidate in candidates) {
      if (!_near(moving, candidate, searchRadius)) continue;
      if (xs.isNotEmpty) {
        x.consider(candidate.left, xs, candidate);
        x.consider(candidate.center.dx, xs, candidate);
        x.consider(candidate.right, xs, candidate);
      }
      if (ys.isNotEmpty) {
        y.consider(candidate.top, ys, candidate);
        y.consider(candidate.center.dy, ys, candidate);
        y.consider(candidate.bottom, ys, candidate);
      }
    }

    // The grid is the fallback, not a competitor: an element alignment is
    // the more meaningful of the two and is the only one that can be
    // explained by a guide, so it wins its axis outright when it exists.
    if (_gridIsUsable) {
      final spacing = gridSpacing!;
      if (!x.matched) x.considerGrid(gridXs ?? xs, spacing);
      if (!y.matched) y.considerGrid(gridYs ?? ys, spacing);
    }

    final delta = Offset(x.correction, y.correction);
    if (delta == Offset.zero && !x.matched && !y.matched) {
      return SnapResult.none;
    }

    final snapped = moving.shift(delta);
    final guides = <AlignmentGuide>[];
    final xOwner = x.owner;
    if (xOwner != null) {
      guides.add(
        AlignmentGuide(
          vertical: true,
          position: x.line,
          from: math.min(snapped.top, xOwner.top),
          to: math.max(snapped.bottom, xOwner.bottom),
        ),
      );
    }
    final yOwner = y.owner;
    if (yOwner != null) {
      guides.add(
        AlignmentGuide(
          vertical: false,
          position: y.line,
          from: math.min(snapped.left, yOwner.left),
          to: math.max(snapped.right, yOwner.right),
        ),
      );
    }
    return SnapResult(delta, guides);
  }

  /// Whether the grid is far enough apart, at this zoom, to be a magnet
  /// rather than a ratchet.
  ///
  /// The furthest any value can sit from a grid line is half the spacing, so
  /// once [threshold] passes that every position is already within reach of
  /// one and "snapping" quietly becomes hard quantisation — off-grid
  /// placement stops being possible at all. Zoomed far enough out that is
  /// exactly what happens (at 0.25x a 24px grid is 6 screen pixels apart),
  /// so grid snapping bows out instead, leaving element alignment — which
  /// has no such floor — still working.
  bool get _gridIsUsable {
    final spacing = gridSpacing;
    return spacing != null && spacing > 0 && threshold * 2 < spacing;
  }

  /// Whether [b] is within [radius] of [a] on both axes.
  ///
  /// Written out rather than `a.inflate(radius).overlaps(b)` so a candidate
  /// sitting exactly [radius] away still counts — [Rect.overlaps] treats a
  /// shared edge as disjoint — and to spare the intermediate [Rect] on a
  /// path that runs for every candidate on every pointer move.
  static bool _near(Rect a, Rect b, double radius) =>
      a.left - radius <= b.right &&
      b.left - radius <= a.right &&
      a.top - radius <= b.bottom &&
      b.top - radius <= a.bottom;
}

/// Running best snap for one axis. Mutable and reused across every
/// candidate so a pointer move allocates two of these and nothing else.
class _AxisBest {
  _AxisBest(this.threshold);

  final double threshold;

  /// Nudge to apply along this axis; `0` when nothing snapped.
  double correction = 0.0;

  /// Where the winning target line sits, for the guide.
  double line = 0.0;

  /// The element that won this axis, or `null` when the winner was the grid
  /// (or nothing) — the grid draws no guide, because the dots the user is
  /// already looking at are the explanation.
  Rect? owner;

  double _distance = double.infinity;

  bool get matched => owner != null;

  void consider(double target, List<double> values, Rect ownerRect) {
    for (final value in values) {
      final distance = (target - value).abs();
      if (distance > threshold || distance >= _distance) continue;
      _distance = distance;
      correction = target - value;
      line = target;
      owner = ownerRect;
    }
  }

  void considerGrid(List<double> values, double spacing) {
    for (final value in values) {
      final target = (value / spacing).roundToDouble() * spacing;
      final distance = (target - value).abs();
      if (distance > threshold || distance >= _distance) continue;
      _distance = distance;
      correction = target - value;
      line = target;
    }
  }
}
