import 'package:flutter/widgets.dart';

import 'package:flowcraft/controller/flow_controller.dart';
import 'package:flowcraft/core/models/flow_handle.dart';
import 'package:flowcraft/core/models/flow_node.dart';
import 'package:flowcraft/handles/handle_widget.dart';
import 'package:flowcraft/theme/flow_theme.dart';

/// A D-shaped trigger node for workflow entry/exit points.
///
/// Input triggers have rounded LEFT corners (D shape).
/// Output triggers have rounded RIGHT corners (reversed D shape).
/// The radius is half the node height, creating a capsule-like curve.
class TriggerNodeWidget extends StatefulWidget {
  const TriggerNodeWidget({
    super.key,
    required this.controller,
    required this.node,
    this.reversed = false,
    this.accentColor = const Color(0xFFFF9800),
    this.theme,
    this.onTap,
    this.onHandleDragStarted,
    this.onHandleDragUpdated,
    this.onHandleDragEnded,
  });

  final FlowController controller;
  final FlowNode node;

  /// If false (input): left corners rounded (D shape).
  /// If true (output): right corners rounded (reversed D shape).
  final bool reversed;

  final Color accentColor;
  final FlowTheme? theme;
  final VoidCallback? onTap;
  final void Function(FlowHandle handle)? onHandleDragStarted;
  final void Function(Offset globalPosition)? onHandleDragUpdated;
  final VoidCallback? onHandleDragEnded;

  @override
  State<TriggerNodeWidget> createState() => _TriggerNodeWidgetState();
}

class _TriggerNodeWidgetState extends State<TriggerNodeWidget> {
  bool _isDragging = false;
  bool _isHandleDragging = false;
  Offset? _lastPointerPosition;
  Offset? _initialPointerPosition;

  static const double _dragThreshold = 4.0;

  void _onPointerDown(PointerDownEvent event) {
    _lastPointerPosition = event.position;
    _initialPointerPosition = event.position;
    _isDragging = false;
  }

  void _onPointerMove(PointerMoveEvent event) {
    if (_lastPointerPosition == null || _isHandleDragging) return;

    if (!_isDragging) {
      final totalDelta = event.position - _initialPointerPosition!;
      if (totalDelta.distance < _dragThreshold) return;
      _isDragging = true;
      widget.controller.startNodeDrag(widget.node.id);
      widget.controller.selection.selectNode(widget.node.id);
    }

    final delta = event.position - _lastPointerPosition!;
    _lastPointerPosition = event.position;

    final scaledDelta = delta / widget.controller.viewport.zoom;
    widget.controller.moveNodeBy(widget.node.id, scaledDelta);
  }

  void _onPointerUp(PointerUpEvent event) {
    if (!_isDragging) {
      widget.controller.selection.selectNode(widget.node.id);
      widget.onTap?.call();
    } else {
      widget.controller.endNodeDrag();
    }
    _isDragging = false;
    _lastPointerPosition = null;
    _initialPointerPosition = null;
  }

  @override
  Widget build(BuildContext context) {
    final selected = widget.controller.selection.isNodeSelected(widget.node.id);
    final accent = widget.accentColor;
    final handleColor =
        widget.theme?.handleBorderColor ?? const Color(0xFF2196F3);

    final w = widget.node.size.width;
    final h = widget.node.size.height;
    final halfH = h / 2;

    // Input (D): left corners rounded, right corners square
    // Output (reversed D): right corners rounded, left corners square
    final borderRadius = widget.reversed
        ? BorderRadius.only(
            topRight: Radius.circular(halfH),
            bottomRight: Radius.circular(halfH),
          )
        : BorderRadius.only(
            topLeft: Radius.circular(halfH),
            bottomLeft: Radius.circular(halfH),
          );

    return Listener(
      onPointerDown: _onPointerDown,
      onPointerMove: _onPointerMove,
      onPointerUp: _onPointerUp,
      behavior: HitTestBehavior.opaque,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: w,
            height: h,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              borderRadius: borderRadius,
              border: Border.all(
                color: selected ? accent : accent.withValues(alpha: 0.4),
                width: selected ? 2.5 : 1.5,
              ),
            ),
            padding: EdgeInsets.only(
              left: widget.reversed ? 14 : halfH + 8,
              right: widget.reversed ? halfH + 8 : 14,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: widget.reversed
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              children: [
                Text(
                  widget.node.label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: accent,
                    letterSpacing: 0.3,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  widget.reversed ? 'output' : 'input',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w500,
                    color: accent.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),

          // Handles
          ...widget.node.handles.map((h) => HandleWidget(
                handle: h,
                nodeSize: widget.node.size,
                color: handleColor,
                onDragStarted: (handle) {
                  _isHandleDragging = true;
                  widget.onHandleDragStarted?.call(handle);
                },
                onDragUpdated: widget.onHandleDragUpdated,
                onDragEnded: () {
                  _isHandleDragging = false;
                  widget.onHandleDragEnded?.call();
                },
              )),

          // Delete button
          if (selected)
            Positioned(
              top: -8,
              right: -8,
              child: GestureDetector(
                onTap: () => widget.controller.removeNode(widget.node.id),
                child: Container(
                  width: 20,
                  height: 20,
                  decoration: const BoxDecoration(
                    color: Color(0xFFEF4444),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Color(0x33000000),
                        blurRadius: 4,
                        offset: Offset(0, 1),
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Text(
                      '×',
                      style: TextStyle(
                        color: Color(0xFFFFFFFF),
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        height: 1.0,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
