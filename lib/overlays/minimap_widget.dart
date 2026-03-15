import 'package:flutter/widgets.dart';

import 'package:flowcraft/controller/flow_controller.dart';

/// Miniature overview of the entire graph with viewport indicator.
///
/// Supports tap/drag to quickly pan the canvas.
class MinimapWidget extends StatelessWidget {
  const MinimapWidget({
    super.key,
    required this.controller,
    this.width = 180,
    this.height = 120,
    this.backgroundColor = const Color(0xFFF5F5F5),
    this.nodeColor = const Color(0xFF90CAF9),
    this.viewportColor = const Color(0x442196F3),
    this.interactive = true,
  });

  final FlowController controller;
  final double width;
  final double height;
  final Color backgroundColor;
  final Color nodeColor;
  final Color viewportColor;
  final bool interactive;

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
          child: interactive
              ? _InteractiveMinimap(
                  controller: controller,
                  nodeColor: nodeColor,
                  viewportColor: viewportColor,
                  width: width,
                  height: height,
                )
              : CustomPaint(
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

class _InteractiveMinimap extends StatelessWidget {
  const _InteractiveMinimap({
    required this.controller,
    required this.nodeColor,
    required this.viewportColor,
    required this.width,
    required this.height,
  });

  final FlowController controller;
  final Color nodeColor;
  final Color viewportColor;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (d) => _panTo(d.localPosition),
      onPanUpdate: (d) => _panTo(d.localPosition),
      child: CustomPaint(
        painter: _MinimapPainter(
          controller: controller,
          nodeColor: nodeColor,
          viewportColor: viewportColor,
        ),
      ),
    );
  }

  void _panTo(Offset local) {
    if (controller.nodes.isEmpty) return;

    final bounds = _graphBounds();
    if (bounds == null) return;

    final scaleX = width / bounds.width;
    final scaleY = height / bounds.height;
    final scale = scaleX < scaleY ? scaleX : scaleY;

    final graphX = local.dx / scale + bounds.left;
    final graphY = local.dy / scale + bounds.top;
    final zoom = controller.viewport.zoom;
    controller.pan(Offset(-graphX * zoom, -graphY * zoom));
  }

  Rect? _graphBounds() {
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

    const p = 50.0;
    minX -= p;
    minY -= p;
    maxX += p;
    maxY += p;

    final w = maxX - minX;
    final h = maxY - minY;
    if (w <= 0 || h <= 0) return null;

    return Rect.fromLTWH(minX, minY, w, h);
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

    const p = 50.0;
    minX -= p;
    minY -= p;
    maxX += p;
    maxY += p;

    final graphW = maxX - minX;
    final graphH = maxY - minY;
    if (graphW <= 0 || graphH <= 0) return;

    final scaleX = size.width / graphW;
    final scaleY = size.height / graphH;
    final scale = scaleX < scaleY ? scaleX : scaleY;

    // Nodes
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

    // Viewport indicator
    final vp = controller.viewport;
    final vpFill = Paint()
      ..color = viewportColor
      ..style = PaintingStyle.fill;
    final vpStroke = Paint()
      ..color = const Color(0xFF2196F3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    final vpRect = Rect.fromLTWH(
      (-vp.offset.dx / vp.zoom - minX) * scale,
      (-vp.offset.dy / vp.zoom - minY) * scale,
      (size.width / vp.zoom) * scale / 2,
      (size.height / vp.zoom) * scale / 2,
    );
    canvas.drawRect(vpRect, vpFill);
    canvas.drawRect(vpRect, vpStroke);
  }

  @override
  bool shouldRepaint(_MinimapPainter oldDelegate) => true;
}
