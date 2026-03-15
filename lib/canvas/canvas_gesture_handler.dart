import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

import 'package:flowcraft/canvas/viewport_transform.dart';
import 'package:flowcraft/controller/flow_controller.dart';

/// Handles pan, pinch-to-zoom, and tap gestures on the canvas.
///
/// Wraps the canvas content in a [Listener] + [GestureDetector]
/// combo to process different interaction modes.
class CanvasGestureHandler extends StatefulWidget {
  /// Creates a [CanvasGestureHandler].
  const CanvasGestureHandler({
    super.key,
    required this.controller,
    required this.child,
    this.onCanvasTap,
  });

  /// The flow controller that receives pan/zoom updates.
  final FlowController controller;

  /// The child widget (the canvas content).
  final Widget child;

  /// Called when the user taps on the canvas background.
  final VoidCallback? onCanvasTap;

  @override
  State<CanvasGestureHandler> createState() => _CanvasGestureHandlerState();
}

class _CanvasGestureHandlerState extends State<CanvasGestureHandler> {
  Offset? _lastFocalPoint;
  double? _lastZoom;

  FlowController get _controller => widget.controller;

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerSignal: _onPointerSignal,
      child: GestureDetector(
        onScaleStart: _onScaleStart,
        onScaleUpdate: _onScaleUpdate,
        onScaleEnd: _onScaleEnd,
        onTap: _onTap,
        behavior: HitTestBehavior.translucent,
        child: widget.child,
      ),
    );
  }

  void _onScaleStart(ScaleStartDetails details) {
    _lastFocalPoint = details.localFocalPoint;
    _lastZoom = _controller.viewport.zoom;
  }

  void _onScaleUpdate(ScaleUpdateDetails details) {
    final focalPoint = details.localFocalPoint;

    if (details.pointerCount == 1) {
      // Single finger — pan
      if (_lastFocalPoint != null) {
        final delta = focalPoint - _lastFocalPoint!;
        _controller.panBy(delta);
      }
    } else if (details.pointerCount >= 2 && _lastZoom != null) {
      // Two finger — pinch zoom
      final newZoom = _lastZoom! * details.scale;
      final viewport = ViewportTransform.zoomAtFocalPoint(
        _controller.viewport,
        newZoom,
        focalPoint,
      );
      _controller.setViewport(offset: viewport.offset, zoom: viewport.zoom);
    }

    _lastFocalPoint = focalPoint;
  }

  void _onScaleEnd(ScaleEndDetails details) {
    _lastFocalPoint = null;
    _lastZoom = null;
  }

  void _onPointerSignal(PointerSignalEvent event) {
    // Mouse wheel zoom
    if (event is PointerScrollEvent) {
      final delta = event.scrollDelta.dy;
      final zoomFactor = delta > 0 ? -0.05 : 0.05;
      final newZoom = _controller.viewport.zoom + zoomFactor;

      final viewport = ViewportTransform.zoomAtFocalPoint(
        _controller.viewport,
        newZoom,
        event.localPosition,
      );
      _controller.setViewport(offset: viewport.offset, zoom: viewport.zoom);
    }
  }

  void _onTap() {
    _controller.selection.clearSelection();
    widget.onCanvasTap?.call();
  }
}
