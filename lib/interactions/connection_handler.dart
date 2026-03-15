import 'dart:ui';

import 'package:flowcraft/controller/flow_controller.dart';
import 'package:flowcraft/core/models/edge_style.dart';

/// Handles the logic for creating new edge connections between nodes.
///
/// Manages the state of an in-progress connection drag from a source
/// handle to a potential target handle.
class ConnectionHandler {
  /// Creates a [ConnectionHandler].
  ConnectionHandler({required this.controller});

  /// The flow controller.
  final FlowController controller;

  /// The ID of the source node being connected from.
  String? sourceNodeId;

  /// The ID of the source handle.
  String? sourceHandleId;

  /// The current drag end position in screen space.
  Offset? currentEndPoint;

  /// Whether a connection drag is in progress.
  bool get isConnecting =>
      sourceNodeId != null && sourceHandleId != null;

  /// Starts a connection drag from a handle.
  void startConnection({
    required String nodeId,
    required String handleId,
  }) {
    sourceNodeId = nodeId;
    sourceHandleId = handleId;
  }

  /// Updates the drag end position.
  void updateEndPoint(Offset screenPoint) {
    currentEndPoint = screenPoint;
  }

  /// Attempts to complete the connection by finding a target handle
  /// at the given screen-space position.
  ///
  /// Returns `true` if a valid connection was made.
  bool completeConnection({
    required String targetNodeId,
    required String targetHandleId,
    EdgeStyle? style,
  }) {
    if (!isConnecting) return false;

    final edge = controller.addEdge(
      sourceNodeId: sourceNodeId!,
      targetNodeId: targetNodeId,
      sourceHandleId: sourceHandleId!,
      targetHandleId: targetHandleId,
      style: style,
    );

    cancelConnection();
    return edge != null;
  }

  /// Cancels the current connection drag.
  void cancelConnection() {
    sourceNodeId = null;
    sourceHandleId = null;
    currentEndPoint = null;
  }
}
