import 'dart:typed_data';
import 'dart:ui' show PointMode;

import 'package:flutter/rendering.dart';

import 'package:flowcraft/core/theme/app_colors.dart';
import 'package:flowcraft/core/theme/app_spacing.dart';
import 'package:flowcraft/models/flow_viewport.dart';

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
    this.gridSpacing = AppSpacing.canvasGrid,
    this.gridColor = AppColors.outline,
    this.gridOpacity = _defaultGridOpacity,
    this.dotRadius = _defaultDotRadius,
  });

  /// The token colour (`FcTokens.dot`) already carries the mockup's alpha, so
  /// no further fade is applied by default.
  static const double _defaultGridOpacity = 1.0;

  /// Mockup dot: `radial-gradient(circle, var(--dot) 1.2px, ...)`.
  static const double _defaultDotRadius = 1.2;

  /// The current viewport state (used for zoom and pan offset).
  final FlowViewport viewport;

  /// The type of grid to draw.
  final GridType gridType;

  /// The base spacing between grid points.
  final double gridSpacing;

  /// The color of the grid, before [gridOpacity] is applied.
  final Color gridColor;

  /// Opacity multiplier applied to [gridColor] (0.0-1.0).
  final double gridOpacity;

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
      ..color = gridColor.withValues(
        alpha: gridColor.a * gridOpacity * (zoom.clamp(0.3, 1.0)),
      );

    if (gridType == GridType.dots) {
      _paintDots(canvas, size, startX, startY, spacing, paint);
    } else if (gridType == GridType.lines) {
      _paintLines(canvas, size, startX, startY, spacing, paint);
    }
  }

  void _paintDots(
    Canvas canvas,
    Size size,
    double startX,
    double startY,
    double spacing,
    Paint paint,
  ) {
    // Count points first to size buffer once.
    int countX = 0;
    for (double x = startX; x <= size.width; x += spacing) {
      countX++;
    }
    int countY = 0;
    for (double y = startY; y <= size.height; y += spacing) {
      countY++;
    }
    final total = countX * countY;
    if (total == 0) return;

    final dotSize = dotRadius * 2 * viewport.zoom.clamp(0.5, 1.5);
    paint
      ..strokeWidth = dotSize
      ..strokeCap = StrokeCap.round;

    // drawRawPoints with packed Float32List avoids Offset allocations.
    final buf = Float32List(total * 2);
    int i = 0;
    for (double x = startX; x <= size.width; x += spacing) {
      for (double y = startY; y <= size.height; y += spacing) {
        buf[i++] = x;
        buf[i++] = y;
      }
    }
    canvas.drawRawPoints(PointMode.points, buf, paint);
  }

  void _paintLines(
    Canvas canvas,
    Size size,
    double startX,
    double startY,
    double spacing,
    Paint paint,
  ) {
    paint.strokeWidth = 0.5;

    // Build packed buffer of (x0,y0,x1,y1) pairs and issue a single drawRawPoints
    // call in line-segment mode.
    int countV = 0;
    for (double x = startX; x <= size.width; x += spacing) {
      countV++;
    }
    int countH = 0;
    for (double y = startY; y <= size.height; y += spacing) {
      countH++;
    }
    final total = countV + countH;
    if (total == 0) return;

    final buf = Float32List(total * 4);
    int i = 0;
    for (double x = startX; x <= size.width; x += spacing) {
      buf[i++] = x;
      buf[i++] = 0;
      buf[i++] = x;
      buf[i++] = size.height;
    }
    for (double y = startY; y <= size.height; y += spacing) {
      buf[i++] = 0;
      buf[i++] = y;
      buf[i++] = size.width;
      buf[i++] = y;
    }
    canvas.drawRawPoints(PointMode.lines, buf, paint);
  }

  @override
  bool shouldRepaint(GridPainter oldDelegate) {
    return viewport.offset != oldDelegate.viewport.offset ||
        viewport.zoom != oldDelegate.viewport.zoom ||
        gridType != oldDelegate.gridType ||
        gridColor != oldDelegate.gridColor ||
        gridOpacity != oldDelegate.gridOpacity ||
        gridSpacing != oldDelegate.gridSpacing ||
        dotRadius != oldDelegate.dotRadius;
  }
}
