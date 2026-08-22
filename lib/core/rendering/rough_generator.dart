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

  /// Builds a sketchy closed outline through [vertices], in order, with the
  /// last joined back to the first.
  ///
  /// The general form of [rectangle] / [diamond] / [triangle] above, for
  /// silhouettes those three don't describe — the sticky note's chat bubble,
  /// whose outline is a body plus a tail. Corners are square, exactly as they
  /// are for [rectangle]: at any visible roughness the jitter dominates the
  /// corner treatment, and the matching *fill* carries the real rounding.
  static Path closedPolyline(
    List<Offset> vertices, {
    double roughness = 1.0,
    int seed = 1,
    bool doubleStroke = true,
    double bowing = 1.0,
  }) {
    final path = Path();
    if (vertices.length < 2) return path;
    final rng = _Rng(seed);
    for (var pass = 0; pass < (doubleStroke ? 2 : 1); pass++) {
      for (var i = 0; i < vertices.length; i++) {
        _line(
          path,
          vertices[i],
          vertices[(i + 1) % vertices.length],
          roughness,
          rng,
          bowing,
          move: i == 0,
        );
      }
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
      path.addOval(
        Rect.fromCircle(center: points.first, radius: 0.5),
      );
      return path;
    }

    final rng = _Rng(seed);
    final jitter = roughness;

    Offset jit(Offset p) =>
        jitter == 0 ? p : p + Offset((rng.next() - 0.5) * jitter, (rng.next() - 0.5) * jitter);

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

  /// Builds a hachure (parallel-line) fill pattern inside [rect].
  ///
  /// Lines are oriented at [angleDeg] degrees and spaced [gap] units
  /// apart. The pattern is clipped to the rect bounds before drawing.
  static Path hachure(
    Rect rect, {
    double gap = 8.0,
    double angleDeg = -41.0,
    double roughness = 1.0,
    int seed = 1,
  }) {
    final path = Path();
    if (rect.width <= 0 || rect.height <= 0 || gap <= 0) return path;
    final rng = _Rng(seed);
    final angle = angleDeg * math.pi / 180.0;
    final sin = math.sin(angle);
    final cos = math.cos(angle);

    // Convert hachure to axis-aligned by rotating sample coordinates.
    // We walk perpendicular to the hachure direction in [gap]-sized steps,
    // emitting one line per step. Diagonal extent ≈ |w·cos| + |h·sin|.
    final extent = rect.width * cos.abs() + rect.height * sin.abs();
    final steps = (extent / gap).floor() + 1;
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
    final offsetMag = (roughness * 1.5 * math.min(len * 0.07, 5.0)).clamp(0.0, 8.0);
    final maxOffset = math.max(0.5, offsetMag);

    final divergePoint = 0.5 +
        (rng.next() - 0.5) * 0.4; // 0.3–0.7

    Offset jit() => Offset(
          (rng.next() - 0.5) * maxOffset,
          (rng.next() - 0.5) * maxOffset,
        );

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
  static (Offset, Offset)? _clipSegmentToRect(
    Offset p1,
    Offset p2,
    Rect rect,
  ) {
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
  _Rng(int seed) : _state = (seed == 0 ? 1 : seed) & 0xFFFFFFFF;
  int _state;

  /// Returns a double in `[0, 1)`.
  double next() {
    // Park-Miller multiplicative LCG.
    _state = (_state * 48271) % 0x7FFFFFFF;
    return _state / 0x7FFFFFFF;
  }
}
