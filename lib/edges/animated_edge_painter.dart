import 'package:flutter/rendering.dart';

import 'package:flowcraft/canvas/viewport_transform.dart';
import 'package:flowcraft/core/enums/edge_type.dart';
import 'package:flowcraft/core/enums/handle_position.dart';
import 'package:flowcraft/core/models/flow_edge.dart';
import 'package:flowcraft/controller/flow_controller.dart';
import 'package:flowcraft/edges/bezier_edge.dart';
import 'package:flowcraft/edges/smooth_step_edge.dart';
import 'package:flowcraft/edges/straight_edge.dart';

/// A [CustomPainter] that draws animated dashed flowing edges.
///
/// Uses [PathMetrics] to extract dash sub-paths and shifts them
/// based on [animationValue] to create a flowing direction effect.
/// This is the core implementation described in the research document.
class AnimatedEdgePainter extends CustomPainter {
  /// Creates an [AnimatedEdgePainter].
  AnimatedEdgePainter({
    required this.controller,
    required this.animationValue,
  });

  /// The flow controller providing edge and node data.
  final FlowController controller;

  /// Animation progress value cycling [0..1].
  final double animationValue;

  @override
  void paint(Canvas canvas, Size size) {
    final viewport = controller.viewport;

    for (final edge in controller.edges) {
      if (!edge.style.animated) continue;

      final sourceNode = controller.graph.nodeById(edge.sourceNodeId);
      final targetNode = controller.graph.nodeById(edge.targetNodeId);
      if (sourceNode == null || targetNode == null) continue;

      final sourceHandle = sourceNode.handleById(edge.sourceHandleId);
      final targetHandle = targetNode.handleById(edge.targetHandleId);
      if (sourceHandle == null || targetHandle == null) continue;

      final sourceOffset = sourceHandle.position.toOffset(sourceNode.rect);
      final targetOffset = targetHandle.position.toOffset(targetNode.rect);

      final screenSource =
          ViewportTransform.canvasToScreen(sourceOffset, viewport);
      final screenTarget =
          ViewportTransform.canvasToScreen(targetOffset, viewport);

      final path = _buildPath(
        edge,
        screenSource,
        screenTarget,
        sourceHandle.position,
        targetHandle.position,
      );

      _drawAnimatedPath(canvas, path, edge, viewport.zoom);
    }
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
        return BezierEdge.buildPath(source, target,
            sourcePosition: sourcePos, targetPosition: targetPos);
      case EdgeType.smoothStep:
        return SmoothStepEdge.buildPath(source, target,
            sourcePosition: sourcePos, targetPosition: targetPos);
      case EdgeType.straight:
        return StraightEdge.buildPath(source, target);
    }
  }

  void _drawAnimatedPath(
    Canvas canvas,
    Path path,
    FlowEdge edge,
    double zoom,
  ) {
    final style = edge.style;
    final dashPattern = style.dashPattern.isNotEmpty
        ? style.dashPattern
        : [8.0, 4.0]; // default dash pattern

    final dashLen = dashPattern[0] * zoom;
    final gapLen = dashPattern[1] * zoom;
    final cycleLen = dashLen + gapLen;

    final paint = Paint()
      ..color = style.color
      ..strokeWidth = style.thickness * zoom
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final metrics = path.computeMetrics();
    for (final metric in metrics) {
      // Shift starting position based on animation value
      double distance = -(animationValue * cycleLen);

      while (distance < metric.length) {
        final start = distance.clamp(0.0, metric.length);
        final end = (distance + dashLen).clamp(0.0, metric.length);

        if (end > start) {
          final segment = metric.extractPath(start, end);
          canvas.drawPath(segment, paint);
        }

        distance += cycleLen;
      }
    }
  }

  @override
  bool shouldRepaint(AnimatedEdgePainter oldDelegate) {
    // Always repaint for animation ticks
    return animationValue != oldDelegate.animationValue;
  }
}
