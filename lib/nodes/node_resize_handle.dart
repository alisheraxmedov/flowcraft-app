import 'package:flutter/widgets.dart';

/// A corner drag handle for resizing nodes.
class NodeResizeHandle extends StatelessWidget {
  /// Creates a [NodeResizeHandle].
  const NodeResizeHandle({
    super.key,
    required this.onResize,
    this.size = 12.0,
  });

  /// Called with the delta offset during resize drag.
  final void Function(Offset delta) onResize;

  /// The size of the resize handle.
  final double size;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      right: 0,
      bottom: 0,
      child: GestureDetector(
        onPanUpdate: (details) => onResize(details.delta),
        child: Container(
          width: size,
          height: size,
          decoration: const BoxDecoration(
            color: Color(0x44888888),
            borderRadius: BorderRadius.only(
              bottomRight: Radius.circular(6),
            ),
          ),
          child: CustomPaint(
            painter: _ResizeIconPainter(),
          ),
        ),
      ),
    );
  }
}

class _ResizeIconPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF999999)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    // Draw two diagonal lines for resize indicator
    canvas.drawLine(
      Offset(size.width * 0.4, size.height),
      Offset(size.width, size.height * 0.4),
      paint,
    );
    canvas.drawLine(
      Offset(size.width * 0.7, size.height),
      Offset(size.width, size.height * 0.7),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
