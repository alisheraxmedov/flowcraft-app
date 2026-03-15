import 'package:flutter/widgets.dart';

import 'package:flowcraft/controller/flow_controller.dart';

/// A small overview preview of the entire graph.
///
/// Shows a miniature representation of all nodes and the current
/// viewport rectangle, allowing quick navigation.
class MinimapWidget extends StatelessWidget {
  /// Creates a [MinimapWidget].
  const MinimapWidget({
    super.key,
    required this.controller,
    this.width = 180,
    this.height = 120,
    this.backgroundColor = const Color(0xFFF5F5F5),
    this.nodeColor = const Color(0xFF90CAF9),
    this.viewportColor = const Color(0x442196F3),
  });

  /// The flow controller.
  final FlowController controller;

  /// The width of the minimap.
  final double width;

  /// The height of the minimap.
  final double height;

  /// Background color of the minimap.
  final Color backgroundColor;

  /// Color used to represent nodes.
  final Color nodeColor;

  /// Color of the viewport rectangle.
  final Color viewportColor;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      right: 12,
      bottom: 12,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: const Color(0xFFDDDDDD)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x1A000000),
              blurRadius: 6,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(5),
          child: CustomPaint(
            painter: _MinimapPainter(
              controller: controller,
              nodeColor: nodeColor,
              viewportColor: viewportColor,
            ),
          ),
        ),
      ),
    );
  }
}

class _MinimapPainter extends CustomPainter {
  _MinimapPainter({
    required this.controller,
    required this.nodeColor,
    required this.viewportColor,
  });

  final FlowController controller;
  final Color nodeColor;
  final Color viewportColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (controller.nodes.isEmpty) return;

    // Calculate bounds of all nodes
    double minX = double.infinity, minY = double.infinity;
    double maxX = double.negativeInfinity, maxY = double.negativeInfinity;

    for (final node in controller.nodes) {
      if (node.position.dx < minX) minX = node.position.dx;
      if (node.position.dy < minY) minY = node.position.dy;
      final right = node.position.dx + node.size.width;
      final bottom = node.position.dy + node.size.height;
      if (right > maxX) maxX = right;
      if (bottom > maxY) maxY = bottom;
    }

    const padding = 50.0;
    minX -= padding;
    minY -= padding;
    maxX += padding;
    maxY += padding;

    final graphWidth = maxX - minX;
    final graphHeight = maxY - minY;
    if (graphWidth <= 0 || graphHeight <= 0) return;

    final scaleX = size.width / graphWidth;
    final scaleY = size.height / graphHeight;
    final scale = scaleX < scaleY ? scaleX : scaleY;

    // Draw nodes
    final nodePaint = Paint()
      ..color = nodeColor
      ..style = PaintingStyle.fill;

    for (final node in controller.nodes) {
      final rect = Rect.fromLTWH(
        (node.position.dx - minX) * scale,
        (node.position.dy - minY) * scale,
        node.size.width * scale,
        node.size.height * scale,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(1)),
        nodePaint,
      );
    }

    // Draw viewport rectangle
    final viewport = controller.viewport;
    final vpPaint = Paint()
      ..color = viewportColor
      ..style = PaintingStyle.fill;
    final vpBorderPaint = Paint()
      ..color = const Color(0xFF2196F3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    // This is approximate — shows what portion of the graph is visible
    final vpRect = Rect.fromLTWH(
      (-viewport.offset.dx / viewport.zoom - minX) * scale,
      (-viewport.offset.dy / viewport.zoom - minY) * scale,
      (size.width / viewport.zoom) * scale / 2,
      (size.height / viewport.zoom) * scale / 2,
    );
    canvas.drawRect(vpRect, vpPaint);
    canvas.drawRect(vpRect, vpBorderPaint);
  }

  @override
  bool shouldRepaint(_MinimapPainter oldDelegate) => true;
}
