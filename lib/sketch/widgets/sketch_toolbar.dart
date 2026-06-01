import 'package:flutter/widgets.dart';

import 'package:flowcraft/sketch/models/sketch_tool.dart';
import 'package:flowcraft/sketch/state/sketch_controller.dart';

/// Compact toolbar exposing the most common sketch tools.
///
/// Pure widgets — no Material / Cupertino dependency — so it can be
/// dropped into any host without forcing a UI framework.
///
/// Styling can be customised via constructor parameters; for richer
/// editing UIs (colour picker, fill style, etc.) build a custom toolbar
/// against [SketchController] directly.
class SketchToolbar extends StatelessWidget {
  const SketchToolbar({
    super.key,
    required this.controller,
    this.backgroundColor = const Color(0xFFFFFFFF),
    this.borderColor = const Color(0xFFE0E0E0),
    this.activeColor = const Color(0xFF2196F3),
    this.iconColor = const Color(0xFF424242),
    this.tools = const [
      SketchTool.select,
      SketchTool.hand,
      SketchTool.rectangle,
      SketchTool.ellipse,
      SketchTool.diamond,
      SketchTool.line,
      SketchTool.arrow,
      SketchTool.freedraw,
      SketchTool.text,
      SketchTool.eraser,
    ],
  });

  final SketchController controller;
  final Color backgroundColor;
  final Color borderColor;
  final Color activeColor;
  final Color iconColor;
  final List<SketchTool> tools;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        return DecoratedBox(
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: borderColor),
            boxShadow: const [
              BoxShadow(
                color: Color(0x1A000000),
                blurRadius: 8,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final tool in tools)
                  _ToolButton(
                    tool: tool,
                    selected: controller.currentTool == tool,
                    activeColor: activeColor,
                    iconColor: iconColor,
                    onTap: () => controller.currentTool = tool,
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ToolButton extends StatelessWidget {
  const _ToolButton({
    required this.tool,
    required this.selected,
    required this.activeColor,
    required this.iconColor,
    required this.onTap,
  });

  final SketchTool tool;
  final bool selected;
  final Color activeColor;
  final Color iconColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 2),
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: selected
              ? activeColor.withValues(alpha: 0.15)
              : const Color(0x00000000),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Center(
          child: CustomPaint(
            size: const Size(18, 18),
            painter: _ToolIconPainter(
              tool: tool,
              color: selected ? activeColor : iconColor,
            ),
          ),
        ),
      ),
    );
  }
}

/// Minimal vector icons for each tool. Pure-Dart so no asset / font
/// dependency is needed.
class _ToolIconPainter extends CustomPainter {
  _ToolIconPainter({required this.tool, required this.color});

  final SketchTool tool;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final fill = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final r = Rect.fromLTWH(2, 2, size.width - 4, size.height - 4);
    switch (tool) {
      case SketchTool.select:
        final p = Path()
          ..moveTo(3, 2)
          ..lineTo(14, 9)
          ..lineTo(8.5, 10)
          ..lineTo(6, 15)
          ..close();
        canvas.drawPath(p, fill);
        break;
      case SketchTool.hand:
        canvas.drawCircle(Offset(size.width / 2, size.height / 2), 5, paint);
        canvas.drawLine(
          Offset(size.width / 2, size.height / 2 - 7),
          Offset(size.width / 2, size.height / 2 + 7),
          paint,
        );
        canvas.drawLine(
          Offset(size.width / 2 - 7, size.height / 2),
          Offset(size.width / 2 + 7, size.height / 2),
          paint,
        );
        break;
      case SketchTool.rectangle:
        canvas.drawRRect(
          RRect.fromRectAndRadius(r, const Radius.circular(2)),
          paint,
        );
        break;
      case SketchTool.ellipse:
        canvas.drawOval(r, paint);
        break;
      case SketchTool.diamond:
        final p = Path()
          ..moveTo(size.width / 2, 2)
          ..lineTo(size.width - 2, size.height / 2)
          ..lineTo(size.width / 2, size.height - 2)
          ..lineTo(2, size.height / 2)
          ..close();
        canvas.drawPath(p, paint);
        break;
      case SketchTool.line:
        canvas.drawLine(Offset(2, size.height - 2), Offset(size.width - 2, 2), paint);
        break;
      case SketchTool.arrow:
        canvas.drawLine(Offset(2, size.height - 2), Offset(size.width - 2, 2), paint);
        canvas.drawLine(Offset(size.width - 2, 2), Offset(size.width - 6, 3), paint);
        canvas.drawLine(Offset(size.width - 2, 2), Offset(size.width - 3, 6), paint);
        break;
      case SketchTool.freedraw:
        final p = Path()
          ..moveTo(2, size.height - 4)
          ..quadraticBezierTo(5, 2, 9, 8)
          ..quadraticBezierTo(13, 14, size.width - 2, 4);
        canvas.drawPath(p, paint);
        break;
      case SketchTool.text:
        canvas.drawLine(Offset(3, 4), Offset(size.width - 3, 4), paint);
        canvas.drawLine(
          Offset(size.width / 2, 4),
          Offset(size.width / 2, size.height - 2),
          paint,
        );
        break;
      case SketchTool.eraser:
        final box = Rect.fromLTRB(3, 6, size.width - 3, size.height - 3);
        canvas.drawRRect(
          RRect.fromRectAndRadius(box, const Radius.circular(2)),
          paint,
        );
        canvas.drawLine(
          Offset(3, size.height - 3),
          Offset(size.width - 3, size.height - 3),
          paint,
        );
        break;
    }
  }

  @override
  bool shouldRepaint(_ToolIconPainter old) =>
      tool != old.tool || color != old.color;
}
