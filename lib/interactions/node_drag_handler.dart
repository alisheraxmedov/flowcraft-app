import 'dart:ui';

import 'package:flutter/widgets.dart';

import 'package:flowcraft/controller/flow_controller.dart';

/// Handles the drag-to-move logic for nodes on the canvas.
///
/// This mixin or utility can be used by node widgets to implement
/// consistent drag behavior with undo snapshot support.
class NodeDragHandler {
  /// Creates a [NodeDragHandler].
  NodeDragHandler({
    required this.controller,
    required this.nodeId,
  });

  /// The flow controller.
  final FlowController controller;

  /// The ID of the node being dragged.
  final String nodeId;

  /// Call this at drag start.
  void onDragStart() {
    controller.startNodeDrag(nodeId);
    controller.selection.selectNode(nodeId);
  }

  /// Call this on each drag update.
  void onDragUpdate(Offset delta) {
    final scaledDelta = delta / controller.viewport.zoom;
    controller.moveNodeBy(nodeId, scaledDelta);
  }

  /// Moves all selected nodes by a delta (for group drag).
  void onGroupDragUpdate(Offset delta) {
    final scaledDelta = delta / controller.viewport.zoom;
    for (final selectedId in controller.selection.selectedNodeIds) {
      controller.moveNodeBy(selectedId, scaledDelta);
    }
  }

  /// Call this at drag end.
  void onDragEnd() {
    controller.endNodeDrag();
  }
}
