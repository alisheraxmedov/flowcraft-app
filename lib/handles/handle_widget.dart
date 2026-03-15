import 'package:flutter/widgets.dart';

import 'package:flowcraft/core/enums/handle_position.dart';
import 'package:flowcraft/core/models/flow_handle.dart';

/// Connection point displayed on node edges.
///
/// Shows a small interactive dot that supports drag gestures
/// for creating edges between nodes.
class HandleWidget extends StatefulWidget {
  const HandleWidget({
    super.key,
    required this.handle,
    required this.nodeSize,
    this.size = 10.0,
    this.color = const Color(0xFF2196F3),
    this.onDragStarted,
    this.onDragUpdated,
    this.onDragEnded,
  });

  final FlowHandle handle;
  final Size nodeSize;
  final double size;
  final Color color;
  final void Function(FlowHandle handle)? onDragStarted;
  final void Function(Offset globalPosition)? onDragUpdated;
  final VoidCallback? onDragEnded;

  @override
  State<HandleWidget> createState() => _HandleWidgetState();
}

class _HandleWidgetState extends State<HandleWidget> {
  bool _hovering = false;
  bool _dragging = false;

  bool get _active => _hovering || _dragging;

  @override
  Widget build(BuildContext context) {
    final pos = _offset();
    final displaySize = _active ? widget.size + 4 : widget.size;

    return Positioned(
      left: pos.dx - displaySize / 2,
      top: pos.dy - displaySize / 2,
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovering = true),
        onExit: (_) => setState(() => _hovering = false),
        cursor: SystemMouseCursors.grab,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanStart: (_) {
            setState(() => _dragging = true);
            widget.onDragStarted?.call(widget.handle);
          },
          onPanUpdate: (d) => widget.onDragUpdated?.call(d.globalPosition),
          onPanEnd: (_) {
            setState(() => _dragging = false);
            widget.onDragEnded?.call();
          },
          child: Container(
            width: displaySize,
            height: displaySize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _active ? widget.color : const Color(0xFFFFFFFF),
              border: Border.all(
                color: widget.color,
                width: _active ? 2.0 : 1.5,
              ),
              boxShadow: _active
                  ? [
                      BoxShadow(
                        color: widget.color.withValues(alpha: 0.4),
                        blurRadius: 6,
                        spreadRadius: 1,
                      ),
                    ]
                  : null,
            ),
          ),
        ),
      ),
    );
  }

  Offset _offset() {
    final w = widget.nodeSize.width;
    final h = widget.nodeSize.height;
    switch (widget.handle.position) {
      case HandlePosition.top:
        return Offset(w / 2, 0);
      case HandlePosition.bottom:
        return Offset(w / 2, h);
      case HandlePosition.left:
        return Offset(0, h / 2);
      case HandlePosition.right:
        return Offset(w, h / 2);
    }
  }
}
