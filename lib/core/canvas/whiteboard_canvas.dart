import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart' show Theme;
import 'package:flutter/services.dart' show HardwareKeyboard;
import 'package:flutter/widgets.dart';

import 'package:flowcraft/core/canvas/grid_painter.dart';
import 'package:flowcraft/core/canvas/viewport_transform.dart';
import 'package:flowcraft/core/theme/app_colors.dart';
import 'package:flowcraft/core/theme/app_spacing.dart';
import 'package:flowcraft/models/flow_viewport.dart';
import 'package:flowcraft/models/sketch_tool.dart';
import 'package:flowcraft/viewmodels/sketch_controller.dart';
import 'package:flowcraft/views/widgets/sketch_layer.dart';

/// A self-contained Miro / Excalidraw-style whiteboard.
///
/// Composes an infinite pan/zoom grid with the [SketchLayer] drawing
/// surface so users can sketch shapes, arrows, and text on a virtual
/// whiteboard. The [SketchController] drives tool selection, element
/// state, selection, and undo/redo.
///
/// ```dart
/// final sketch = SketchController();
/// WhiteboardCanvas(sketchController: sketch);
/// ```
///
/// Pan/zoom is handled automatically: while a drawing tool is active the
/// canvas pan is suppressed so sketching doesn't fight the gesture arena;
/// switch to [SketchTool.hand] (or use pinch / mouse-wheel) to navigate.
///
/// Keyboard shortcuts are *not* handled here. They used to be, on this
/// widget's own focus node, which meant they died the moment focus moved to
/// a toolbar popover or a properties field. They now live in
/// `CanvasShortcuts`, wrapped around the whole screen; this widget only
/// keeps a focus node so the key events have somewhere to start from.
class WhiteboardCanvas extends StatefulWidget {
  const WhiteboardCanvas({
    super.key,
    required this.sketchController,
    this.backgroundColor = AppColors.surface,
    this.gridType = GridType.dots,
    this.gridColor = AppColors.outline,
    this.gridOpacity = 0.15,
    this.gridSpacing = AppSpacing.canvasGrid,
    this.minZoom = 0.1,
    this.maxZoom = 4.0,
    this.initialZoom = 1.0,
    this.animateReveal = true,
  });

  final SketchController sketchController;
  final Color backgroundColor;
  final GridType gridType;
  final Color gridColor;
  final double gridOpacity;
  final double gridSpacing;
  final double minZoom;
  final double maxZoom;
  final double initialZoom;

  /// Whether agent-drawn elements animate in; see `SketchLayer.animateReveal`.
  final bool animateReveal;

  /// Zoom change per scroll unit when Ctrl/Cmd is held: 100 px of wheel
  /// travel is a 20 % step. Multiplicative, like the pinch gesture
  /// (`_lastZoom * details.scale`), so a step feels the same at 0.1× as at
  /// 4× — the old fixed ±0.05 was a 50 % jump zoomed out and a 1 % nudge
  /// zoomed in.
  static const double wheelZoomRate = 0.002;

  @override
  State<WhiteboardCanvas> createState() => _WhiteboardCanvasState();
}

class _WhiteboardCanvasState extends State<WhiteboardCanvas> {
  late FocusNode _focusNode;
  late FlowViewport _viewport;

  /// True while the sketch layer is consuming pointer events (a drawing
  /// tool is active). When true, pan/zoom is bypassed so the drawing
  /// gesture isn't competed for.
  final ValueNotifier<bool> _sketchConsuming = ValueNotifier<bool>(false);

  /// Last frame request this canvas has acted on. Starts at the controller's
  /// current generation so a request made before mount is not replayed.
  late int _seenFrameGen;

  Offset? _lastFocalPoint;
  double? _lastZoom;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    _viewport = FlowViewport(
      minZoom: widget.minZoom,
      maxZoom: widget.maxZoom,
      zoom: widget.initialZoom,
    );
    _seenFrameGen = widget.sketchController.frameRequestGen;
    widget.sketchController.addListener(_syncSketchActive);
    _syncSketchActive();
  }

  @override
  void didUpdateWidget(WhiteboardCanvas old) {
    super.didUpdateWidget(old);
    if (old.sketchController != widget.sketchController) {
      old.sketchController.removeListener(_syncSketchActive);
      widget.sketchController.addListener(_syncSketchActive);
      _seenFrameGen = widget.sketchController.frameRequestGen;
      _syncSketchActive();
    }
  }

  @override
  void dispose() {
    widget.sketchController.removeListener(_syncSketchActive);
    _sketchConsuming.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  /// The sketch layer owns pointer input whenever the user has picked a
  /// drawing-style tool (anything other than [SketchTool.hand]).
  void _syncSketchActive() {
    final active = widget.sketchController.currentTool != SketchTool.hand;
    if (_sketchConsuming.value != active) {
      _sketchConsuming.value = active;
    }
    final c = widget.sketchController;
    if (c.frameRequestGen != _seenFrameGen) {
      _seenFrameGen = c.frameRequestGen;
      final request = c.frameRequest;
      if (request != null) _frame(request.rect, request.onlyIfHidden);
    }
  }

  /// Fits [rect] (canvas space) into the view with 48 px of padding, centred.
  /// With [onlyIfHidden] a rect that is already fully visible is left alone.
  void _frame(Rect rect, bool onlyIfHidden) {
    final size = context.size;
    if (size == null || size.isEmpty || !rect.isFinite) return;
    if (onlyIfHidden) {
      final visible = Rect.fromPoints(
        ViewportTransform.screenToCanvas(Offset.zero, _viewport),
        ViewportTransform.screenToCanvas(
          size.bottomRight(Offset.zero),
          _viewport,
        ),
      );
      if (visible.contains(rect.topLeft) &&
          visible.contains(rect.bottomRight)) {
        return;
      }
    }
    const pad = 48.0;
    final zoom = math.min(
      (size.width - 2 * pad) / math.max(rect.width, 1),
      (size.height - 2 * pad) / math.max(rect.height, 1),
    );
    final fitted = _viewport.copyWith(zoom: zoom);
    _setViewport(
      fitted.copyWith(
        offset: size.center(Offset.zero) - rect.center * fitted.zoom,
      ),
    );
  }

  bool _sketchEditing() {
    final s = widget.sketchController;
    return s.editingElementId != null || s.editingCanvasPosition != null;
  }

  void _setViewport(FlowViewport viewport) {
    if (_viewport == viewport) return;
    setState(() => _viewport = viewport);
  }

  void _onScaleStart(ScaleStartDetails details) {
    _lastFocalPoint = details.localFocalPoint;
    _lastZoom = _viewport.zoom;
  }

  void _onScaleUpdate(ScaleUpdateDetails details) {
    final focalPoint = details.localFocalPoint;

    if (details.pointerCount == 1) {
      // Single pointer — pan.
      if (_lastFocalPoint != null) {
        final delta = focalPoint - _lastFocalPoint!;
        _setViewport(_viewport.copyWith(offset: _viewport.offset + delta));
      }
    } else if (details.pointerCount >= 2 && _lastZoom != null) {
      // Two pointers — pinch zoom.
      final newZoom = _lastZoom! * details.scale;
      _setViewport(
        ViewportTransform.zoomAtFocalPoint(_viewport, newZoom, focalPoint),
      );
    }

    _lastFocalPoint = focalPoint;
  }

  void _onScaleEnd(ScaleEndDetails details) {
    _lastFocalPoint = null;
    _lastZoom = null;
  }

  /// Wheel / trackpad scroll: plain scroll pans, Ctrl/Cmd + scroll zooms
  /// about the pointer.
  ///
  /// Every two-finger sideways swipe on a trackpad and every tilt-wheel
  /// arrives with `dy == 0`; that used to take the "zoom in" branch and
  /// jump several steps per flick. A horizontal scroll now moves the board
  /// sideways and never touches the zoom.
  void _onPointerSignal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent) return;
    final delta = event.scrollDelta;
    final zoomModifier =
        HardwareKeyboard.instance.isControlPressed ||
        HardwareKeyboard.instance.isMetaPressed;
    if (!zoomModifier) {
      // Scroll content the way the wheel moves a page: wheel-down (dy > 0)
      // brings the board up, i.e. the viewport offset decreases.
      _setViewport(_viewport.copyWith(offset: _viewport.offset - delta));
      return;
    }
    if (delta.dy == 0) return;
    // One flung wheel event can report hundreds of pixels; bound a single
    // step to halving / doubling so the factor can never go negative.
    final factor = (1 - delta.dy * WhiteboardCanvas.wheelZoomRate).clamp(
      0.5,
      2.0,
    );
    final newZoom = _viewport.zoom * factor;
    _setViewport(
      ViewportTransform.zoomAtFocalPoint(
        _viewport,
        newZoom,
        event.localPosition,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // A focusable node, not a key handler: shortcuts live one layer up in
    // `CanvasShortcuts`, which needs *something* inside it to hold focus so
    // key events walk up through it. Autofocus is what makes the keyboard
    // work on a freshly-opened window with nothing clicked yet.
    return Focus(
      focusNode: _focusNode,
      autofocus: true,
      child: GestureDetector(
        onTap: () {
          if (_sketchEditing()) return;
          _focusNode.requestFocus();
        },
        behavior: HitTestBehavior.translucent,
        child: Container(
          color: widget.backgroundColor,
          child: ValueListenableBuilder<bool>(
            valueListenable: _sketchConsuming,
            builder: (context, consuming, child) {
              return Listener(
                onPointerSignal: _onPointerSignal,
                child: consuming
                    ? child!
                    : GestureDetector(
                        onScaleStart: _onScaleStart,
                        onScaleUpdate: _onScaleUpdate,
                        onScaleEnd: _onScaleEnd,
                        behavior: HitTestBehavior.translucent,
                        child: child!,
                      ),
              );
            },
            child: Stack(
              fit: StackFit.expand,
              children: [
                RepaintBoundary(
                  child: CustomPaint(
                    painter: GridPainter(
                      viewport: _viewport,
                      gridType: widget.gridType,
                      gridColor: widget.gridColor,
                      gridOpacity: widget.gridOpacity,
                      gridSpacing: widget.gridSpacing,
                    ),
                  ),
                ),
                SketchLayer(
                  controller: widget.sketchController,
                  viewportProvider: () => _viewport,
                  animateReveal: widget.animateReveal,
                  selectionColor: Theme.of(context).colorScheme.primary,
                  marqueeColor: Theme.of(context).colorScheme.primary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
