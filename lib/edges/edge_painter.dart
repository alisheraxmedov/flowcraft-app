import 'dart:math' as math;

import 'package:flutter/rendering.dart';

import 'package:flowcraft/canvas/viewport_transform.dart';
import 'package:flowcraft/core/enums/edge_type.dart';
import 'package:flowcraft/core/enums/handle_position.dart';
import 'package:flowcraft/core/models/flow_edge.dart';
import 'package:flowcraft/core/models/flow_viewport.dart';
import 'package:flowcraft/controller/flow_controller.dart';
import 'package:flowcraft/edges/bezier_edge.dart';
import 'package:flowcraft/edges/smooth_step_edge.dart';
import 'package:flowcraft/edges/step_edge.dart';
import 'package:flowcraft/edges/straight_edge.dart';

/// Paints all edges using [CustomPainter].
///
/// Supports solid, dashed, and animated dash styles.
/// Delegates path computation to [BezierEdge], [SmoothStepEdge],
/// [StepEdge], or [StraightEdge].
class EdgePainter extends CustomPainter {
  EdgePainter({
    required this.controller,
    required this.viewport,
    required this.edges,
    required this.selectedEdgeIds,
    required this.paintGen,
    this.animationValue = 0.0,
    this.canvasSize,
  });

  final FlowController controller;
  final FlowViewport viewport;
  final List<FlowEdge> edges;
  final Set<String> selectedEdgeIds;
  final int paintGen;
  final double animationValue;
  final Size? canvasSize;

  // Reusable paints — mutated per edge instead of allocated each time.
  static final Paint _bodyPaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;
  static final Paint _highlightPaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round;

  @override
  void paint(Canvas canvas, Size size) {
    final effectiveSize = canvasSize ?? size;
    final zoom = viewport.zoom;
    final graph = controller.graph;

    for (final edge in edges) {
      final sourceNode = graph.nodeById(edge.sourceNodeId);
      final targetNode = graph.nodeById(edge.targetNodeId);
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

      if (_isEdgeOffScreen(screenSource, screenTarget, effectiveSize)) {
        continue;
      }

      final path = _buildPath(
        edge, screenSource, screenTarget,
        sourceHandle.position, targetHandle.position,
      );

      final scaledThickness = edge.style.thickness * zoom;
      _bodyPaint
        ..color = edge.style.color
        ..strokeWidth = scaledThickness;

      if (selectedEdgeIds.contains(edge.id)) {
        _highlightPaint
          ..color = edge.style.color.withValues(alpha: 0.3)
          ..strokeWidth = (edge.style.thickness + 4) * zoom;
        canvas.drawPath(path, _highlightPaint);
      }

      final dashes = _effectiveDashes(edge);
      if (edge.style.animated) {
        _drawAnimated(canvas, path, _bodyPaint, dashes, zoom);
      } else if (dashes.isNotEmpty) {
        _drawDashed(canvas, path, _bodyPaint, dashes);
      } else {
        canvas.drawPath(path, _bodyPaint);
      }

      if (edge.style.showArrow) {
        _drawArrow(canvas, path, _bodyPaint, edge.style.arrowSize * zoom);
      }
    }
  }

  bool _isEdgeOffScreen(Offset source, Offset target, Size size) {
    const margin = 100.0;
    final minX = math.min(source.dx, target.dx);
    final maxX = math.max(source.dx, target.dx);
    final minY = math.min(source.dy, target.dy);
    final maxY = math.max(source.dy, target.dy);

    return maxX < -margin ||
        minX > size.width + margin ||
        maxY < -margin ||
        minY > size.height + margin;
  }

  List<double> _effectiveDashes(FlowEdge edge) {
    if (edge.style.dashPattern.isNotEmpty) return edge.style.dashPattern;
    if (edge.style.animated) return const [8.0, 4.0];
    return const <double>[];
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

  void _drawDashed(
    Canvas canvas, Path path, Paint paint, List<double> pattern,
  ) {
    if (pattern.length < 2) {
      canvas.drawPath(path, paint);
      return;
    }
    for (final metric in path.computeMetrics()) {
      double dist = 0;
      int idx = 0;
      while (dist < metric.length) {
        final len = pattern[idx % pattern.length];
        final end = (dist + len).clamp(0.0, metric.length);
        if (idx % 2 == 0) {
          canvas.drawPath(metric.extractPath(dist, end), paint);
        }
        dist = end;
        idx++;
      }
    }
  }

  void _drawAnimated(
    Canvas canvas, Path path, Paint paint,
    List<double> pattern, double zoom,
  ) {
    if (pattern.length < 2) {
      canvas.drawPath(path, paint);
      return;
    }
    final dashLen = pattern[0] * zoom;
    final gapLen = pattern[1] * zoom;
    final cycle = dashLen + gapLen;
    final offset = animationValue * cycle;

    for (final metric in path.computeMetrics()) {
      double dist = offset - cycle;
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

  void _drawArrow(Canvas canvas, Path path, Paint paint, double arrowSize) {
    for (final metric in path.computeMetrics()) {
      if (metric.length < 2) continue;
      final tangent = metric.getTangentForOffset(metric.length);
      if (tangent == null) continue;

      final tip = tangent.position;
      final angle = tangent.angle;

      final arrow = Path()
        ..moveTo(tip.dx, tip.dy)
        ..lineTo(
          tip.dx - arrowSize * math.cos(angle - 0.5),
          tip.dy - arrowSize * math.sin(angle - 0.5),
        )
        ..moveTo(tip.dx, tip.dy)
        ..lineTo(
          tip.dx - arrowSize * math.cos(angle + 0.5),
          tip.dy - arrowSize * math.sin(angle + 0.5),
        );
      canvas.drawPath(arrow, paint);
      break;
    }
  }

  @override
  bool shouldRepaint(EdgePainter old) {
    return paintGen != old.paintGen ||
        animationValue != old.animationValue ||
        viewport != old.viewport ||
        !_setEquals(selectedEdgeIds, old.selectedEdgeIds);
  }

  static bool _setEquals(Set<String> a, Set<String> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (final e in a) {
      if (!b.contains(e)) return false;
    }
    return true;
  }
}
