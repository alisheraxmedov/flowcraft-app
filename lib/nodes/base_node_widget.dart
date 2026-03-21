import 'package:flutter/widgets.dart';

import 'package:flowcraft/controller/flow_controller.dart';
import 'package:flowcraft/core/models/flow_handle.dart';
import 'package:flowcraft/core/models/flow_node.dart';
import 'package:flowcraft/engine/node_status.dart';
import 'package:flowcraft/nodes/node_header.dart';
import 'package:flowcraft/handles/handle_widget.dart';
import 'package:flowcraft/theme/flow_theme.dart';

/// Default node widget with selection, drag, handles, and delete button.
///
/// Uses raw [Listener] for drag handling to avoid gesture arena conflicts
/// with the canvas pan gesture.
class DefaultBaseNodeWidget extends StatefulWidget {
  const DefaultBaseNodeWidget({
    super.key,
    required this.controller,
    required this.node,
    this.onTap,
    this.theme,
    this.onHandleDragStarted,
    this.onHandleDragUpdated,
    this.onHandleDragEnded,
  });

  final FlowController controller;
  final FlowNode node;
  final VoidCallback? onTap;
  final FlowTheme? theme;
  final void Function(FlowHandle handle)? onHandleDragStarted;
  final void Function(Offset globalPosition)? onHandleDragUpdated;
  final VoidCallback? onHandleDragEnded;

  @override
  State<DefaultBaseNodeWidget> createState() => _DefaultBaseNodeWidgetState();
}

class _DefaultBaseNodeWidgetState extends State<DefaultBaseNodeWidget> {
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
      widget.controller.markNodeTapped();
      widget.controller.selection.selectNode(widget.node.id);
      widget.onTap?.call();
    } else {
      widget.controller.endNodeDrag();
    }
    _isDragging = false;
    _lastPointerPosition = null;
  }

  @override
  Widget build(BuildContext context) {
    final selected = widget.controller.selection.isNodeSelected(widget.node.id);
    final runtimeStatus = widget.controller.nodeStatus(widget.node.id);
    final bg = widget.theme?.nodeBackgroundColor ?? const Color(0xFFFFFFFF);
    final statusBorder = _statusBorderColor(runtimeStatus);
    final border = statusBorder ?? (selected
        ? (widget.theme?.nodeSelectedBorderColor ?? const Color(0xFF2196F3))
        : (widget.theme?.nodeBorderColor ?? const Color(0xFFDDDDDD)));
    final handleColor =
        widget.theme?.handleBorderColor ?? const Color(0xFF2196F3);

    return Listener(
      onPointerDown: _onPointerDown,
      onPointerMove: _onPointerMove,
      onPointerUp: _onPointerUp,
      behavior: HitTestBehavior.opaque,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: widget.node.size.width,
            height: widget.node.size.height,
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(
                widget.theme?.nodeBorderRadius ?? 8.0,
              ),
              border: Border.all(
                color: border,
                width: selected || statusBorder != null ? 2 : 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0x1A000000),
                  blurRadius: selected ? 8 : 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                NodeHeader(
                  label: widget.node.label,
                  nodeType: widget.node.type,
                  backgroundColor: widget.theme?.headerBackgroundColor,
                ),
              ],
            ),
          ),

          // Runtime status indicator
          if (runtimeStatus != NodeStatus.idle)
            Positioned(
              bottom: -4,
              left: 8,
              child: Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: _statusColor(runtimeStatus),
                  shape: BoxShape.circle,
                  border: Border.all(color: bg, width: 1),
                ),
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

  static Color _statusColor(NodeStatus status) {
    switch (status) {
      case NodeStatus.queued:
        return const Color(0xFF90A4AE);
      case NodeStatus.running:
        return const Color(0xFF42A5F5);
      case NodeStatus.success:
        return const Color(0xFF66BB6A);
      case NodeStatus.error:
        return const Color(0xFFEF5350);
      case NodeStatus.skipped:
        return const Color(0xFFFFCA28);
      case NodeStatus.idle:
        return const Color(0x00000000);
    }
  }

  static Color? _statusBorderColor(NodeStatus status) {
    switch (status) {
      case NodeStatus.running:
        return const Color(0xFF42A5F5);
      case NodeStatus.success:
        return const Color(0xFF66BB6A);
      case NodeStatus.error:
        return const Color(0xFFEF5350);
      default:
        return null;
    }
  }
}
