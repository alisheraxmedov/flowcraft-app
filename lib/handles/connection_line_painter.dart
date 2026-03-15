import 'package:flutter/rendering.dart';

/// Paints a live temporary line while the user drags from a handle
/// to create a new connection.
class ConnectionLinePainter extends CustomPainter {
  /// Creates a [ConnectionLinePainter].
  ConnectionLinePainter({
    required this.startPoint,
    required this.endPoint,
    this.color = const Color(0xFF2196F3),
    this.strokeWidth = 2.0,
  });

  /// The screen-space start point (from the source handle).
  final Offset startPoint;

  /// The screen-space end point (follows the user's cursor/finger).
  final Offset endPoint;

  /// The color of the line.
  final Color color;

  /// The stroke width.
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // Draw a dashed bezier line
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

    // Draw dashed
    const dashLen = 6.0;
    const gapLen = 4.0;
    final metrics = path.computeMetrics();
    for (final metric in metrics) {
      double distance = 0;
      bool draw = true;
      while (distance < metric.length) {
        final len = draw ? dashLen : gapLen;
        final end = (distance + len).clamp(0.0, metric.length);
        if (draw) {
          canvas.drawPath(metric.extractPath(distance, end), paint);
        }
        distance = end;
        draw = !draw;
      }
    }
  }

  @override
  bool shouldRepaint(ConnectionLinePainter oldDelegate) {
    return startPoint != oldDelegate.startPoint ||
        endPoint != oldDelegate.endPoint;
  }
}
