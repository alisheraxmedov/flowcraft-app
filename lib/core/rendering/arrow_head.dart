import 'dart:math' as math;

import 'package:flutter/rendering.dart';

import 'package:flowcraft/models/sketch_element.dart' show ArrowheadStyle;

/// Shared geometry for the filled triangular arrow-head drawn at the end
/// of an arrow.
///
/// Used by both [SketchPainter] (committed arrows) and
/// [SketchPreviewPainter] (in-progress arrow preview) so the two stay
/// visually identical instead of drifting apart as separately-maintained
/// copies of the same formula.
class ArrowHead {
  ArrowHead._();

  /// Builds the closed triangle path for an arrow-head pointing from
  /// [start] toward [end], with wingspan proportional to [size].
  static Path path(Offset start, Offset end, double size) {
    final dx = end.dx - start.dx;
    final dy = end.dy - start.dy;
    final angle = math.atan2(dy, dx);
    final left = Offset(
      end.dx - size * math.cos(angle - 0.5),
      end.dy - size * math.sin(angle - 0.5),
    );
    final right = Offset(
      end.dx - size * math.cos(angle + 0.5),
      end.dy - size * math.sin(angle + 0.5),
    );
    return Path()
      ..moveTo(end.dx, end.dy)
      ..lineTo(left.dx, left.dy)
      ..lineTo(right.dx, right.dy)
      ..close();
  }

  /// The glyph for [style] at [to], seen travelling from [from], scaled by
  /// [size].
  ///
  /// [ArrowheadStyle.none] is an empty path. [ArrowheadStyle.arrow] is the
  /// filled [path] triangle. The cardinality glyphs are open strokes plus an
  /// oval for "zero" (the painter strokes them; the oval is not filled), all
  /// within 1.3 × [size] of [to] along the shaft and 0.4 × [size] either
  /// side, which is the envelope `SketchArrow.unrotatedBounds` reserves.
  static Path pathFor(
    ArrowheadStyle style,
    Offset from,
    Offset to,
    double size,
  ) {
    if (style == ArrowheadStyle.none) return Path();
    if (style == ArrowheadStyle.arrow) return path(from, to, size);

    final delta = to - from;
    final len = delta.distance;
    // Degenerate (zero-length) shaft: no direction to orient against.
    final d = len == 0 ? const Offset(1, 0) : delta / len;
    final n = Offset(-d.dy, d.dx);
    Offset at(double back, [double side = 0]) =>
        to - d * (back * size) + n * (side * size);

    final p = Path();
    void bar(double back) => p
      ..moveTo(at(back, -0.4).dx, at(back, -0.4).dy)
      ..lineTo(at(back, 0.4).dx, at(back, 0.4).dy);
    void foot() {
      final apex = at(0.7);
      for (final side in const <double>[-0.4, 0, 0.4]) {
        final tip = at(0, side);
        p
          ..moveTo(apex.dx, apex.dy)
          ..lineTo(tip.dx, tip.dy);
      }
    }

    void zero(double back) =>
        p.addOval(Rect.fromCircle(center: at(back), radius: 0.3 * size));

    switch (style) {
      case ArrowheadStyle.one:
        bar(0.35);
      case ArrowheadStyle.many:
        foot();
      case ArrowheadStyle.zeroOrOne:
        bar(0.35);
        zero(0.9);
      case ArrowheadStyle.zeroOrMany:
        foot();
        zero(1.0);
      case ArrowheadStyle.oneOrMany:
        foot();
        bar(0.85);
      case ArrowheadStyle.none || ArrowheadStyle.arrow:
        break;
    }
    return p;
  }
}
