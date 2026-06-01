import 'package:flutter/material.dart';

import 'package:flowcraft/flowcraft.dart';

class TelegramNode extends StatefulWidget {
  const TelegramNode({
    super.key,
    required this.controller,
    required this.node,
    this.onHandleDragStarted,
    this.onHandleDragUpdated,
    this.onHandleDragEnded,
  });

  final FlowController controller;
  final FlowNode node;
  final void Function(FlowHandle handle)? onHandleDragStarted;
  final void Function(Offset globalPosition)? onHandleDragUpdated;
  final VoidCallback? onHandleDragEnded;

  static Widget builder(
    FlowController controller,
    FlowNode node, {
    void Function(FlowHandle handle)? onHandleDragStarted,
    void Function(Offset globalPosition)? onHandleDragUpdated,
    VoidCallback? onHandleDragEnded,
  }) {
    return TelegramNode(
      controller: controller,
      node: node,
      onHandleDragStarted: onHandleDragStarted,
      onHandleDragUpdated: onHandleDragUpdated,
      onHandleDragEnded: onHandleDragEnded,
    );
  }

  @override
  State<TelegramNode> createState() => _TelegramNodeState();
}

class _TelegramNodeState extends State<TelegramNode> {
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
    } else {
      widget.controller.endNodeDrag();
    }
    _isDragging = false;
    _lastPointerPosition = null;
  }

  @override
  Widget build(BuildContext context) {
    final selected = widget.controller.selection.isNodeSelected(widget.node.id);

    return Listener(
      onPointerDown: _onPointerDown,
      onPointerMove: _onPointerMove,
      onPointerUp: _onPointerUp,
      behavior: HitTestBehavior.opaque,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            height: 100.0,
            width: 100.0,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              image: DecorationImage(image: AssetImage('assets/icons/telegram.png'), scale: 8.0, fit: BoxFit.none),
              color: Colors.blue.shade100,
              border: Border.all(
                color: selected ? Colors.blue : Colors.blue,
                width: selected ? 5.0 : 2.0,
              ),
            ),
          ),

          ...widget.node.handles.map((h) => HandleWidget(
                handle: h,
                nodeSize: const Size(100, 100),
                color: Colors.blueAccent,
                onDragStarted: (handle) {
                  _isHandleDragging = true;
                  widget.onHandleDragStarted?.call(handle);
                },
                onDragUpdated: widget.onHandleDragUpdated,
                onDragEnded: () {
                  _isHandleDragging = false;
                  widget.onHandleDragEnded?.call();
                },
              ),),
        ],
      ),
    );
  }
}