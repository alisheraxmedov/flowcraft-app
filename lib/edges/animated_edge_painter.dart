import 'package:flutter/rendering.dart';

import 'package:flowcraft/canvas/viewport_transform.dart';
import 'package:flowcraft/core/enums/edge_type.dart';
import 'package:flowcraft/core/enums/handle_position.dart';
import 'package:flowcraft/core/models/flow_edge.dart';
import 'package:flowcraft/controller/flow_controller.dart';
import 'package:flowcraft/edges/bezier_edge.dart';
import 'package:flowcraft/edges/smooth_step_edge.dart';
import 'package:flowcraft/edges/step_edge.dart';
import 'package:flowcraft/edges/straight_edge.dart';

/// Draws only animated (flowing dash) edges.
///
/// Used as a separate painter layer so it can repaint independently
/// on every animation tick without affecting static edges.
class AnimatedEdgePainter extends CustomPainter {
  AnimatedEdgePainter({
    required this.controller,
    required this.animationValue,
  });

  final FlowController controller;
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

      final screenSource = ViewportTransform.canvasToScreen(
        sourceHandle.position.toOffset(sourceNode.rect),
        viewport,
      );
      final screenTarget = ViewportTransform.canvasToScreen(
        targetHandle.position.toOffset(targetNode.rect),
        viewport,
      );

      final path = _buildPath(
        edge, screenSource, screenTarget,
        sourceHandle.position, targetHandle.position,
      );

      _drawAnimated(canvas, path, edge, viewport.zoom);
    }
  }

  Path _buildPath(
    FlowEdge edge, Offset source, Offset target,
    HandlePosition sourcePos, HandlePosition targetPos,
  ) {
    switch (edge.style.edgeType) {
      case EdgeType.bezier:
        return BezierEdge.buildPath(source, target,
            sourcePosition: sourcePos, targetPosition: targetPos);
      case EdgeType.smoothStep:
        return SmoothStepEdge.buildPath(source, target,
            sourcePosition: sourcePos, targetPosition: targetPos);
      case EdgeType.step:
        return StepEdge.buildPath(source, target,
            sourcePosition: sourcePos, targetPosition: targetPos);
      case EdgeType.straight:
        return StraightEdge.buildPath(source, target);
    }
  }

  void _drawAnimated(Canvas canvas, Path path, FlowEdge edge, double zoom) {
    final style = edge.style;
    final pattern = style.dashPattern.isNotEmpty
        ? style.dashPattern
        : [8.0, 4.0];

    final dashLen = pattern[0] * zoom;
    final gapLen = pattern[1] * zoom;
    final cycle = dashLen + gapLen;

    final paint = Paint()
      ..color = style.color
      ..strokeWidth = style.thickness * zoom
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    for (final metric in path.computeMetrics()) {
      double dist = animationValue * cycle - cycle;
      while (dist < metric.length) {
        final start = dist.clamp(0.0, metric.length);
        final end = (dist + dashLen).clamp(0.0, metric.length);
        if (end > start) {
          canvas.drawPath(metric.extractPath(start, end), paint);
        }
        dist += cycle;
      }
    }
  }

  @override
  bool shouldRepaint(AnimatedEdgePainter oldDelegate) {
    return animationValue != oldDelegate.animationValue;
  }
}
