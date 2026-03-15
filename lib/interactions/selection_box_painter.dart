import 'package:flutter/rendering.dart';

/// Paints a rubber-band selection rectangle (lasso box) on the canvas.
class SelectionBoxPainter extends CustomPainter {
  /// Creates a [SelectionBoxPainter].
  SelectionBoxPainter({
    required this.startPoint,
    required this.endPoint,
    this.borderColor = const Color(0xFF2196F3),
    this.fillColor = const Color(0x222196F3),
  });

  /// The starting corner of the selection box.
  final Offset startPoint;

  /// The ending corner of the selection box.
  final Offset endPoint;

  /// The border color of the selection box.
  final Color borderColor;

  /// The fill color of the selection box.
  final Color fillColor;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromPoints(startPoint, endPoint);

    // Fill
    canvas.drawRect(
      rect,
      Paint()
        ..color = fillColor
        ..style = PaintingStyle.fill,
    );

    // Border
    canvas.drawRect(
      rect,
      Paint()
        ..color = borderColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0,
    );
  }

  @override
  bool shouldRepaint(SelectionBoxPainter oldDelegate) {
    return startPoint != oldDelegate.startPoint ||
        endPoint != oldDelegate.endPoint;
  }
}
