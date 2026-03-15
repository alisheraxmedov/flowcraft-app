import 'dart:math' as math;

import 'package:flutter/rendering.dart';

import 'package:flowcraft/canvas/viewport_transform.dart';
import 'package:flowcraft/core/enums/edge_type.dart';
import 'package:flowcraft/core/enums/handle_position.dart';
import 'package:flowcraft/core/models/flow_edge.dart';
import 'package:flowcraft/controller/flow_controller.dart';
import 'package:flowcraft/edges/bezier_edge.dart';
import 'package:flowcraft/edges/smooth_step_edge.dart';
import 'package:flowcraft/edges/straight_edge.dart';

/// [CustomPainter] that draws all edges in the graph.
///
/// Delegates to [BezierEdge], [SmoothStepEdge], or [StraightEdge]
/// based on each edge's [EdgeStyle.edgeType].
class EdgePainter extends CustomPainter {
  /// Creates an [EdgePainter].
  EdgePainter({
    required this.controller,
    this.animationValue = 0.0,
  });

  /// The flow controller providing edge and node data.
  final FlowController controller;

  /// The current animation value [0..1] for animated edges.
  final double animationValue;

  @override
  void paint(Canvas canvas, Size size) {
    final viewport = controller.viewport;

    for (final edge in controller.edges) {
      final sourceNode = controller.graph.nodeById(edge.sourceNodeId);
      final targetNode = controller.graph.nodeById(edge.targetNodeId);
        if (sourceNode == null || targetNode == null) continue;

        final sourceHandle = sourceNode.handleById(edge.sourceHandleId);
        final targetHandle = targetNode.handleById(edge.targetHandleId);
        if (sourceHandle == null || targetHandle == null) continue;

        // Get handle positions in canvas space
        final sourceOffset = sourceHandle.position.toOffset(sourceNode.rect);
        final targetOffset = targetHandle.position.toOffset(targetNode.rect);

        // Convert to screen space
        final screenSource =
            ViewportTransform.canvasToScreen(sourceOffset, viewport);
        final screenTarget =
            ViewportTransform.canvasToScreen(targetOffset, viewport);

        // Build the path
        final path = _buildPath(
          edge,
          screenSource,
          screenTarget,
          sourceHandle.position,
          targetHandle.position,
        );

        // Draw the edge
        final paint = Paint()
          ..color = edge.style.color
          ..strokeWidth = edge.style.thickness * viewport.zoom
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round;

        final isSelected = controller.selection.isEdgeSelected(edge.id);
        if (isSelected) {
          // Draw selection highlight
          final highlightPaint = Paint()
            ..color = edge.style.color.withValues(alpha: 0.3)
            ..strokeWidth = (edge.style.thickness + 4) * viewport.zoom
            ..style = PaintingStyle.stroke
            ..strokeCap = StrokeCap.round;
          canvas.drawPath(path, highlightPaint);
        }

        final dashPattern = _effectiveDashPattern(edge);

        if (edge.style.animated) {
          _drawAnimatedDashes(
            canvas,
            path,
            paint,
            dashPattern,
            viewport.zoom,
          );
        } else if (dashPattern.isNotEmpty) {
          _drawDashes(canvas, path, paint, dashPattern);
        } else {
          canvas.drawPath(path, paint);
        }

        // Draw arrow
        if (edge.style.showArrow) {
          _drawArrow(canvas, path, paint, edge.style.arrowSize * viewport.zoom);
        }
    }
  }

  List<double> _effectiveDashPattern(FlowEdge edge) {
    if (edge.style.dashPattern.isNotEmpty) {
      return edge.style.dashPattern;
    }

    if (edge.style.animated) {
      return const [8.0, 4.0];
    }

    return const <double>[];
  }

  Path _buildPath(
    FlowEdge edge,
    Offset source,
    Offset target,
    HandlePosition sourcePos,
    HandlePosition targetPos,
  ) {
    switch (edge.style.edgeType) {
      case EdgeType.bezier:
        return BezierEdge.buildPath(
          source,
          target,
          sourcePosition: sourcePos,
          targetPosition: targetPos,
        );
      case EdgeType.smoothStep:
        return SmoothStepEdge.buildPath(
          source,
          target,
          sourcePosition: sourcePos,
          targetPosition: targetPos,
        );
      case EdgeType.straight:
        return StraightEdge.buildPath(source, target);
    }
  }

  void _drawDashes(
    Canvas canvas,
    Path path,
    Paint paint,
    List<double> dashPattern,
  ) {
    if (dashPattern.length < 2) {
      canvas.drawPath(path, paint);
      return;
    }

    final metrics = path.computeMetrics();
    for (final metric in metrics) {
      double distance = 0;
      int dashIndex = 0;
      while (distance < metric.length) {
        final dashLen = dashPattern[dashIndex % dashPattern.length];
        final isDash = dashIndex % 2 == 0;
        final end = (distance + dashLen).clamp(0.0, metric.length);

        if (isDash) {
          final segment = metric.extractPath(distance, end);
          canvas.drawPath(segment, paint);
        }

        distance = end;
        dashIndex++;
      }
    }
  }

  void _drawAnimatedDashes(
    Canvas canvas,
    Path path,
    Paint paint,
    List<double> dashPattern,
    double zoom,
  ) {
    if (dashPattern.length < 2) {
      canvas.drawPath(path, paint);
      return;
    }

    final dashLen = dashPattern[0] * zoom;
    final gapLen = dashPattern[1] * zoom;
    final totalLen = dashLen + gapLen;
    final offset = animationValue * totalLen;

    final metrics = path.computeMetrics();
    for (final metric in metrics) {
      double distance = -offset;
      while (distance < metric.length) {
        final start = distance.clamp(0.0, metric.length);
        final end = (distance + dashLen).clamp(0.0, metric.length);

        if (end > start) {
          final segment = metric.extractPath(start, end);
          canvas.drawPath(segment, paint);
        }

        distance += totalLen;
      }
    }
  }

  void _drawArrow(Canvas canvas, Path path, Paint paint, double arrowSize) {
    for (final metric in path.computeMetrics()) {
      if (metric.length < 2) continue;

      final tangent = metric.getTangentForOffset(metric.length);
      if (tangent == null) continue;

      final tipPoint = tangent.position;
      final angle = tangent.angle;

      final arrowPath = Path();
      arrowPath.moveTo(tipPoint.dx, tipPoint.dy);
      arrowPath.lineTo(
        tipPoint.dx - arrowSize * math.cos(angle - 0.5),
        tipPoint.dy - arrowSize * math.sin(angle - 0.5),
      );
      arrowPath.moveTo(tipPoint.dx, tipPoint.dy);
      arrowPath.lineTo(
        tipPoint.dx - arrowSize * math.cos(angle + 0.5),
        tipPoint.dy - arrowSize * math.sin(angle + 0.5),
      );

      canvas.drawPath(arrowPath, paint);
      break;
    }
  }

  @override
  bool shouldRepaint(EdgePainter oldDelegate) {
    return animationValue != oldDelegate.animationValue ||
        controller != oldDelegate.controller;
  }
}
