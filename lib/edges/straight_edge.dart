import 'dart:ui';

/// Computes a simple straight line [Path] between two points.
class StraightEdge {
  /// Builds a straight line path from [source] to [target].
  static Path buildPath(Offset source, Offset target) {
    return Path()
      ..moveTo(source.dx, source.dy)
      ..lineTo(target.dx, target.dy);
  }

  /// Returns the midpoint for label placement.
  static Offset midpoint(Offset source, Offset target) {
    return Offset(
      (source.dx + target.dx) / 2,
      (source.dy + target.dy) / 2,
    );
  }
}
