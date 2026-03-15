import 'package:flutter/widgets.dart';

import 'package:flowcraft/controller/flow_controller.dart';

/// Zoom control buttons overlay.
///
/// Shows zoom in, zoom out, and fit-to-view buttons.
class ControlsWidget extends StatelessWidget {
  /// Creates a [ControlsWidget].
  const ControlsWidget({
    super.key,
    required this.controller,
  });

  /// The flow controller.
  final FlowController controller;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 12,
      bottom: 12,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFFFFFFF),
          borderRadius: BorderRadius.circular(6),
          boxShadow: const [
            BoxShadow(
              color: Color(0x1A000000),
              blurRadius: 6,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _ControlButton(
              icon: '+',
              onTap: () => controller.zoomIn(),
              tooltip: 'Zoom In',
            ),
            Container(
              height: 1,
              width: 32,
              color: const Color(0xFFEEEEEE),
            ),
            _ControlButton(
              icon: '−',
              onTap: () => controller.zoomOut(),
              tooltip: 'Zoom Out',
            ),
            Container(
              height: 1,
              width: 32,
              color: const Color(0xFFEEEEEE),
            ),
            _ControlButton(
              icon: '⊡',
              onTap: () {
                // Fit view needs canvas size — uses a reasonable default
                final renderBox =
                    context.findRenderObject() as RenderBox?;
                final canvasSize = renderBox?.size ?? const Size(800, 600);
                controller.fitView(canvasSize);
              },
              tooltip: 'Fit View',
            ),
          ],
        ),
      ),
    );
  }
}

class _ControlButton extends StatelessWidget {
  const _ControlButton({
    required this.icon,
    required this.onTap,
    required this.tooltip,
  });

  final String icon;
  final VoidCallback onTap;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        alignment: Alignment.center,
        child: Text(
          icon,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w400,
            color: Color(0xFF555555),
          ),
        ),
      ),
    );
  }
}
