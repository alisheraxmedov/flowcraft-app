import 'package:flutter/rendering.dart';

/// Paints a temporary dashed bezier line during handle drag.
class ConnectionLinePainter extends CustomPainter {
  ConnectionLinePainter({
    required this.startPoint,
    required this.endPoint,
    this.color = const Color(0xFF2196F3),
    this.strokeWidth = 2.0,
  });

  final Offset startPoint;
  final Offset endPoint;
  final Color color;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final dx = (endPoint.dx - startPoint.dx).abs();
    final controlOffset = dx * 0.5 + 30;

    final path = Path()
      ..moveTo(startPoint.dx, startPoint.dy)
      ..cubicTo(
        startPoint.dx,
        startPoint.dy + controlOffset,
        endPoint.dx,
        endPoint.dy - controlOffset,
        endPoint.dx,
        endPoint.dy,
      );

    const dashLen = 6.0;
    const gapLen = 4.0;
    for (final metric in path.computeMetrics()) {
      double dist = 0;
      bool draw = true;
      while (dist < metric.length) {
        final len = draw ? dashLen : gapLen;
        final end = (dist + len).clamp(0.0, metric.length);
        if (draw) {
          canvas.drawPath(metric.extractPath(dist, end), paint);
        }
        dist = end;
        draw = !draw;
      }
    }
  }

  @override
  bool shouldRepaint(ConnectionLinePainter old) {
    return startPoint != old.startPoint || endPoint != old.endPoint;
  }
}
