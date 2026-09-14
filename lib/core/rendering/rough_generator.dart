import 'dart:math' as math;
import 'dart:ui';

/// Generates "hand-drawn" looking [Path]s for primitive shapes.
///
/// Pure Dart, deterministic for a given seed — paths can be cached
/// per element across paint frames.
///
/// Inspired by rough.js (MIT). The algorithm is intentionally
/// minimal: each stroke is drawn twice with slight per-segment jitter
/// and a small "bowing" curvature, producing the familiar wobbly look.
class RoughGenerator {
  RoughGenerator._();

  /// Builds a sketchy line from [p1] to [p2].
  ///
  /// [roughness] controls jitter magnitude (1 = normal). [seed] makes
  /// the result deterministic; same seed → same path. Set [doubleStroke]
  /// to false to emit a single pass (cheaper, less sketchy).
  static Path line(
    Offset p1,
    Offset p2, {
    double roughness = 1.0,
    int seed = 1,
    bool doubleStroke = true,
    double bowing = 1.0,
  }) {
    final path = Path();
    final rng = _Rng(seed);
    _line(path, p1, p2, roughness, rng, bowing, move: true);
    if (doubleStroke) {
      _line(path, p1, p2, roughness, rng, bowing, move: true);
    }
    return path;
  }

  /// Builds a sketchy rectangle, optionally with rounded corners.
  static Path rectangle(
    Rect rect, {
    double roughness = 1.0,
    int seed = 1,
    double cornerRadius = 0.0,
    bool doubleStroke = true,
    double bowing = 1.0,
  }) {
    final path = Path();
    final rng = _Rng(seed);
    final tl = rect.topLeft;
    final tr = rect.topRight;
    final br = rect.bottomRight;
    final bl = rect.bottomLeft;

    // Sketchy rounded corners are tricky; for now we emit 4 sketchy lines
    // and accept square corners when cornerRadius > 0 (visual fidelity
    // is dominated by the roughness anyway).
    for (var pass = 0; pass < (doubleStroke ? 2 : 1); pass++) {
      _line(path, tl, tr, roughness, rng, bowing, move: true);
      _line(path, tr, br, roughness, rng, bowing, move: false);
      _line(path, br, bl, roughness, rng, bowing, move: false);
      _line(path, bl, tl, roughness, rng, bowing, move: false);
    }
    return path;
  }

  /// Builds a sketchy diamond (rhombus) inscribed in [rect].
  static Path diamond(
    Rect rect, {
    double roughness = 1.0,
    int seed = 1,
    bool doubleStroke = true,
    double bowing = 1.0,
  }) {
    final path = Path();
    final rng = _Rng(seed);
    final top = Offset(rect.center.dx, rect.top);
    final right = Offset(rect.right, rect.center.dy);
    final bottom = Offset(rect.center.dx, rect.bottom);
    final left = Offset(rect.left, rect.center.dy);

    for (var pass = 0; pass < (doubleStroke ? 2 : 1); pass++) {
      _line(path, top, right, roughness, rng, bowing, move: true);
      _line(path, right, bottom, roughness, rng, bowing, move: false);
      _line(path, bottom, left, roughness, rng, bowing, move: false);
      _line(path, left, top, roughness, rng, bowing, move: false);
    }
    return path;
  }

  /// Builds a sketchy isosceles triangle inscribed in [rect] (apex at
  /// top-centre, base along the bottom edge).
  static Path triangle(
    Rect rect, {
    double roughness = 1.0,
    int seed = 1,
    bool doubleStroke = true,
    double bowing = 1.0,
  }) {
    final path = Path();
    final rng = _Rng(seed);
    final a = Offset(rect.center.dx, rect.top);
    final b = Offset(rect.left, rect.bottom);
    final c = Offset(rect.right, rect.bottom);

    for (var pass = 0; pass < (doubleStroke ? 2 : 1); pass++) {
      _line(path, a, b, roughness, rng, bowing, move: true);
      _line(path, b, c, roughness, rng, bowing, move: false);
      _line(path, c, a, roughness, rng, bowing, move: false);
    }
    return path;
  }

  /// Builds a sketchy ellipse inscribed in [rect].
  static Path ellipse(
    Rect rect, {
    double roughness = 1.0,
    int seed = 1,
    bool doubleStroke = true,
  }) {
    final path = Path();
    if (rect.width == 0 || rect.height == 0) return path;
    final rng = _Rng(seed);
    final cx = rect.center.dx;
    final cy = rect.center.dy;
    final rx = rect.width / 2;
    final ry = rect.height / 2;

    // Step count scales with circumference so circles stay visually round
    // (a low step count reads as a polygon). Bounded to keep the cost
    // manageable on large shapes.
    final steps = (math.pi * (rx + ry) / 4.0).clamp(32.0, 96.0).round();
    final jitter = roughness * 1.2;
    final startAngle = rng.next() * math.pi * 2;

    for (var pass = 0; pass < (doubleStroke ? 2 : 1); pass++) {
      final passJitterX = (rng.next() - 0.5) * jitter;
      final passJitterY = (rng.next() - 0.5) * jitter;
      Offset? prev;
      for (var i = 0; i <= steps; i++) {
        final t = i / steps;
        final theta = startAngle + t * math.pi * 2;
        final dx = (rng.next() - 0.5) * jitter;
        final dy = (rng.next() - 0.5) * jitter;
        final p = Offset(
          cx + rx * math.cos(theta) + dx + passJitterX,
          cy + ry * math.sin(theta) + dy + passJitterY,
        );
        if (prev == null) {
          path.moveTo(p.dx, p.dy);
        } else {
          path.lineTo(p.dx, p.dy);
        }
        prev = p;
      }
    }
    return path;
  }

  /// Builds a smooth-but-jittered polyline path for freedraw strokes.
  ///
  /// Renders the polyline using cubic interpolation between control
  /// points, with optional per-segment jitter. For freehand strokes that
  /// are already noisy, prefer [roughness] = 0.
  static Path polyline(
    List<Offset> points, {
    double roughness = 0.0,
    int seed = 1,
    bool smooth = true,
  }) {
    final path = Path();
    if (points.isEmpty) return path;
    if (points.length == 1) {
      path.addOval(Rect.fromCircle(center: points.first, radius: 0.5));
      return path;
    }

    final rng = _Rng(seed);
    final jitter = roughness;

    Offset jit(Offset p) => jitter == 0
        ? p
        : p + Offset((rng.next() - 0.5) * jitter, (rng.next() - 0.5) * jitter);

    final first = jit(points.first);
    path.moveTo(first.dx, first.dy);

    if (!smooth || points.length == 2) {
      for (var i = 1; i < points.length; i++) {
        final p = jit(points[i]);
        path.lineTo(p.dx, p.dy);
      }
      return path;
    }

    // Quadratic-smoothed polyline: control point = current vertex, end
    // point = midpoint of current and next. Produces a smoother stroke
    // than straight segments without the cost of Catmull-Rom interpolation.
    for (var i = 1; i < points.length - 1; i++) {
      final cur = jit(points[i]);
      final next = jit(points[i + 1]);
      final mid = Offset((cur.dx + next.dx) / 2, (cur.dy + next.dy) / 2);
      path.quadraticBezierTo(cur.dx, cur.dy, mid.dx, mid.dy);
    }
    final last = jit(points.last);
    path.lineTo(last.dx, last.dy);
    return path;
  }

  /// Upper bound on hachure lines per direction. A rect large enough to
  /// need more (≈ 16 000 canvas units across at the default gap) is legal
  /// in a scene file, and building tens of thousands of jittered cubics for
  /// one element on the UI thread is not; such a shape falls back to a
  /// solid fill instead (see [hachureFits]).
  static const int maxHachureSteps = 2000;

  /// Whether [hachure] will pattern [rect] rather than give up on it.
  static bool hachureFits(
    Rect rect, {
    double gap = 8.0,
    double angleDeg = -41.0,
  }) => _hachureSteps(rect, gap, angleDeg) <= maxHachureSteps;

  static int _hachureSteps(Rect rect, double gap, double angleDeg) {
    final angle = angleDeg * math.pi / 180.0;
    // Diagonal extent ≈ |w·cos| + |h·sin|, walked in [gap]-sized steps.
    final extent =
        rect.width * math.cos(angle).abs() +
        rect.height * math.sin(angle).abs();
    return (extent / gap).floor() + 1;
  }

  /// Builds a hachure (parallel-line) fill pattern inside [rect].
  ///
  /// Lines are oriented at [angleDeg] degrees and spaced [gap] units
  /// apart. The pattern is clipped to the rect bounds before drawing.
  /// Returns an empty path when the rect would need more than
  /// [maxHachureSteps] lines; callers check [hachureFits] first and draw a
  /// solid fill in that case.
  static Path hachure(
    Rect rect, {
    double gap = 8.0,
    double angleDeg = -41.0,
    double roughness = 1.0,
    int seed = 1,
  }) {
    final path = Path();
    if (rect.width <= 0 || rect.height <= 0 || gap <= 0) return path;
    final steps = _hachureSteps(rect, gap, angleDeg);
    if (steps > maxHachureSteps) return path;
    final rng = _Rng(seed);
    final angle = angleDeg * math.pi / 180.0;
    final sin = math.sin(angle);
    final cos = math.cos(angle);

    // Convert hachure to axis-aligned by rotating sample coordinates.
    // We walk perpendicular to the hachure direction in [gap]-sized steps,
    // emitting one line per step.
    final cx = rect.center.dx;
    final cy = rect.center.dy;
    final halfLen = math.max(rect.width, rect.height);

    for (var i = -steps; i <= steps; i++) {
      final offsetPerp = i * gap;
      // Centre of the segment along the perpendicular axis.
      final cxLine = cx + offsetPerp * -sin;
      final cyLine = cy + offsetPerp * cos;
      final p1 = Offset(cxLine - halfLen * cos, cyLine - halfLen * sin);
      final p2 = Offset(cxLine + halfLen * cos, cyLine + halfLen * sin);

      // Clip the segment to the rect using Liang-Barsky.
      final clipped = _clipSegmentToRect(p1, p2, rect);
      if (clipped == null) continue;

      _line(path, clipped.$1, clipped.$2, roughness, rng, 0.5, move: true);
    }
    return path;
  }

  /// Cuts [src] into the on/off runs of [pattern] (alternating dash and
  /// gap lengths, in the path's own units) and returns the dashes as one
  /// path of open sub-paths. A pattern shorter than two entries returns
  /// [src] unchanged.
  ///
  /// Drawn with round caps, the merged path is indistinguishable from one
  /// `drawPath` per dash — which is what the painter used to issue, per
  /// element, per frame; built once and cached, a dotted outline costs the
  /// same to draw as a solid one.
  static Path dash(Path src, List<double> pattern) {
    if (pattern.length < 2) return src;
    final out = Path();
    for (final metric in src.computeMetrics()) {
      var dist = 0.0;
      var idx = 0;
      while (dist < metric.length) {
        final len = pattern[idx % pattern.length];
        final end = math.min(dist + len, metric.length);
        if (idx.isEven) out.addPath(metric.extractPath(dist, end), Offset.zero);
        dist = end;
        idx++;
      }
    }
    return out;
  }

  // ── internal ─────────────────────────────────────────────────────────────

  static void _line(
    Path path,
    Offset p1,
    Offset p2,
    double roughness,
    _Rng rng,
    double bowing, {
    required bool move,
  }) {
    final len = (p2 - p1).distance;
    if (len == 0) return;
    final offsetMag = (roughness * 1.5 * math.min(len * 0.07, 5.0)).clamp(
      0.0,
      8.0,
    );
    final maxOffset = math.max(0.5, offsetMag);

    final divergePoint = 0.5 + (rng.next() - 0.5) * 0.4; // 0.3–0.7

    Offset jit() =>
        Offset((rng.next() - 0.5) * maxOffset, (rng.next() - 0.5) * maxOffset);

    final mid1 = Offset(
      p1.dx + (p2.dx - p1.dx) * divergePoint,
      p1.dy + (p2.dy - p1.dy) * divergePoint,
    );
    final mid2 = Offset(
      p1.dx + 2 * (p2.dx - p1.dx) * divergePoint,
      p1.dy + 2 * (p2.dy - p1.dy) * divergePoint,
    );
    final bowOff = Offset(
      -(p2.dy - p1.dy) * bowing * 0.02,
      (p2.dx - p1.dx) * bowing * 0.02,
    );

    final start = p1 + jit();
    final c1 = mid1 + bowOff + jit();
    final c2 = mid2 + bowOff + jit();
    final end = p2 + jit();

    if (move) {
      path.moveTo(start.dx, start.dy);
    }
    path.cubicTo(c1.dx, c1.dy, c2.dx, c2.dy, end.dx, end.dy);
  }

  /// Liang-Barsky line clipping against [rect].
  /// Returns the clipped segment, or null if entirely outside.
  static (Offset, Offset)? _clipSegmentToRect(Offset p1, Offset p2, Rect rect) {
    final dx = p2.dx - p1.dx;
    final dy = p2.dy - p1.dy;
    final p = [-dx, dx, -dy, dy];
    final q = [
      p1.dx - rect.left,
      rect.right - p1.dx,
      p1.dy - rect.top,
      rect.bottom - p1.dy,
    ];

    double u1 = 0.0, u2 = 1.0;
    for (var i = 0; i < 4; i++) {
      if (p[i] == 0) {
        if (q[i] < 0) return null;
      } else {
        final t = q[i] / p[i];
        if (p[i] < 0) {
          if (t > u2) return null;
          if (t > u1) u1 = t;
        } else {
          if (t < u1) return null;
          if (t < u2) u2 = t;
        }
      }
    }
    return (
      Offset(p1.dx + u1 * dx, p1.dy + u1 * dy),
      Offset(p1.dx + u2 * dx, p1.dy + u2 * dy),
    );
  }
}

/// Tiny linear-congruential PRNG. Stable across platforms and Dart
/// versions, unlike [math.Random] whose sequence is implementation-defined.
class _Rng {
  /// Park–Miller needs `1 <= state <= m - 1` (m = 0x7FFFFFFF): a state of 0
  /// is a fixed point that returns 0 forever, which `seed & 0xFFFFFFFF`
  /// produced for every multiple of m (and `seed == 0` was only one of
  /// those). Seeds already in range are used as-is so every existing
  /// board keeps the exact wobble it was saved with; anything else is
  /// reduced modulo `m - 1` plus one, which lands in range for negative
  /// seeds too (Dart's `%` is never negative).
  _Rng(int seed)
    : _state = (seed >= 1 && seed < _modulus)
          ? seed
          : (seed % _modulusMinusOne) + 1;

  static const int _modulus = 0x7FFFFFFF;
  static const int _modulusMinusOne = 0x7FFFFFFE;

  int _state;

  /// Returns a double in `[0, 1)`.
  double next() {
    // Park-Miller multiplicative LCG.
    _state = (_state * 48271) % _modulus;
    return _state / _modulus;
  }
}
