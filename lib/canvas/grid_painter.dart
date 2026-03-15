import 'package:flutter/rendering.dart';

import 'package:flowcraft/core/models/flow_viewport.dart';

/// The type of background grid displayed on the canvas.
enum GridType {
  /// Small circular dots.
  dots,

  /// Thin horizontal and vertical lines.
  lines,

  /// No grid.
  none,
}

/// A [CustomPainter] that draws a background grid pattern on the canvas.
///
/// The grid adjusts its spacing and opacity based on the current viewport
/// zoom level for a smooth visual experience.
class GridPainter extends CustomPainter {
  /// Creates a [GridPainter].
  GridPainter({
    required this.viewport,
    this.gridType = GridType.dots,
    this.gridSpacing = 20.0,
    this.gridColor = const Color(0x22888888),
    this.dotRadius = 1.0,
  });

  /// The current viewport state (used for zoom and pan offset).
  final FlowViewport viewport;

  /// The type of grid to draw.
  final GridType gridType;

  /// The base spacing between grid points.
  final double gridSpacing;

  /// The color of the grid.
  final Color gridColor;

  /// The radius of grid dots (for [GridType.dots]).
  final double dotRadius;

  @override
  void paint(Canvas canvas, Size size) {
    if (gridType == GridType.none) return;

    final zoom = viewport.zoom;
    final offsetX = viewport.offset.dx;
    final offsetY = viewport.offset.dy;
    final spacing = gridSpacing * zoom;

    // Don't draw grid if spacing is too small
    if (spacing < 5) return;

    // Calculate the grid range visible in the viewport
    final startX = -(offsetX % spacing);
    final startY = -(offsetY % spacing);

    final paint = Paint()
      ..color = gridColor.withValues(alpha: gridColor.a * (zoom.clamp(0.3, 1.0)));

    if (gridType == GridType.dots) {
      _paintDots(canvas, size, startX, startY, spacing, paint);
    } else if (gridType == GridType.lines) {
      _paintLines(canvas, size, startX, startY, spacing, paint);
    }
  }

  void _paintDots(Canvas canvas, Size size, double startX, double startY,
      double spacing, Paint paint) {
    for (double x = startX; x <= size.width; x += spacing) {
      for (double y = startY; y <= size.height; y += spacing) {
        canvas.drawCircle(
          Offset(x, y),
          dotRadius * viewport.zoom.clamp(0.5, 1.5),
          paint,
        );
      }
    }
  }

  void _paintLines(Canvas canvas, Size size, double startX, double startY,
      double spacing, Paint paint) {
    paint.strokeWidth = 0.5;

    // Vertical lines
    for (double x = startX; x <= size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    // Horizontal lines
    for (double y = startY; y <= size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(GridPainter oldDelegate) {
    return viewport.offset != oldDelegate.viewport.offset ||
        viewport.zoom != oldDelegate.viewport.zoom ||
        gridType != oldDelegate.gridType ||
        gridColor != oldDelegate.gridColor;
  }
}
