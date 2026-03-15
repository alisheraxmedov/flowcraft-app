import 'package:flutter/widgets.dart';

import 'package:flowcraft/core/models/flow_viewport.dart';

/// Converts the [FlowViewport] state into a [Matrix4] transformation
/// that applies pan and zoom to the canvas.
class ViewportTransform {
  /// Builds a [Matrix4] from the given viewport state.
  static Matrix4 buildMatrix(FlowViewport viewport) {
    return Matrix4.identity()
      ..translateByDouble(viewport.offset.dx, viewport.offset.dy, 0, 0)
      ..scaleByDouble(viewport.zoom, viewport.zoom, 1, 1);
  }

  /// Converts a screen-space point to canvas-space using the viewport.
  static Offset screenToCanvas(Offset screenPoint, FlowViewport viewport) {
    return Offset(
      (screenPoint.dx - viewport.offset.dx) / viewport.zoom,
      (screenPoint.dy - viewport.offset.dy) / viewport.zoom,
    );
  }

  /// Converts a canvas-space point to screen-space using the viewport.
  static Offset canvasToScreen(Offset canvasPoint, FlowViewport viewport) {
    return Offset(
      canvasPoint.dx * viewport.zoom + viewport.offset.dx,
      canvasPoint.dy * viewport.zoom + viewport.offset.dy,
    );
  }

  /// Calculates zoom centered on a focal point.
  static FlowViewport zoomAtFocalPoint(
    FlowViewport viewport,
    double newZoom,
    Offset focalPoint,
  ) {
    final clampedZoom = newZoom.clamp(viewport.minZoom, viewport.maxZoom);

    // Calculate the canvas point under the focal point before zoom
    final canvasPoint = screenToCanvas(focalPoint, viewport);

    // After zoom, the same canvas point should still be under the focal point
    final newOffset = Offset(
      focalPoint.dx - canvasPoint.dx * clampedZoom,
      focalPoint.dy - canvasPoint.dy * clampedZoom,
    );

    return viewport.copyWith(
      zoom: clampedZoom,
      offset: newOffset,
    );
  }
}
