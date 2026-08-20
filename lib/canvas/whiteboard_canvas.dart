import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'package:flowcraft/canvas/grid_painter.dart';
import 'package:flowcraft/canvas/viewport_transform.dart';
import 'package:flowcraft/core/models/flow_viewport.dart';
import 'package:flowcraft/sketch/models/sketch_tool.dart';
import 'package:flowcraft/sketch/state/sketch_controller.dart';
import 'package:flowcraft/sketch/widgets/sketch_layer.dart';

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
class WhiteboardCanvas extends StatefulWidget {
  const WhiteboardCanvas({
    super.key,
    required this.sketchController,
    this.backgroundColor = const Color(0xFFFFFFFF),
    this.gridType = GridType.dots,
    this.gridColor = const Color(0x22888888),
    this.gridSpacing = 20.0,
    this.minZoom = 0.1,
    this.maxZoom = 4.0,
    this.initialZoom = 1.0,
    this.enableKeyboardShortcuts = true,
  });

  final SketchController sketchController;
  final Color backgroundColor;
  final GridType gridType;
  final Color gridColor;
  final double gridSpacing;
  final double minZoom;
  final double maxZoom;
  final double initialZoom;
  final bool enableKeyboardShortcuts;

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
    widget.sketchController.addListener(_syncSketchActive);
    _syncSketchActive();
  }

  @override
  void didUpdateWidget(WhiteboardCanvas old) {
    super.didUpdateWidget(old);
    if (old.sketchController != widget.sketchController) {
      old.sketchController.removeListener(_syncSketchActive);
      widget.sketchController.addListener(_syncSketchActive);
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
  }

  bool _sketchEditing() {
    final s = widget.sketchController;
    return s.editingElementId != null || s.editingCanvasPosition != null;
  }

  void _setViewport(FlowViewport viewport) {
    if (_viewport == viewport) return;
    setState(() => _viewport = viewport);
  }

  KeyEventResult _handleKey(KeyEvent event) {
    if (!widget.enableKeyboardShortcuts) return KeyEventResult.ignored;
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }

    final ctrl = HardwareKeyboard.instance.isControlPressed ||
        HardwareKeyboard.instance.isMetaPressed;
    final shift = HardwareKeyboard.instance.isShiftPressed;
    final key = event.logicalKey;
    final sketch = widget.sketchController;

    // Delete / Backspace → remove selected
    if (key == LogicalKeyboardKey.delete ||
        key == LogicalKeyboardKey.backspace) {
      if (sketch.hasSelection) sketch.removeSelected();
      return KeyEventResult.handled;
    }

    if (ctrl) {
      if (key == LogicalKeyboardKey.keyZ) {
        if (shift ? sketch.canRedo : sketch.canUndo) {
          shift ? sketch.redo() : sketch.undo();
        }
        return KeyEventResult.handled;
      }
      if (key == LogicalKeyboardKey.keyY) {
        if (sketch.canRedo) sketch.redo();
        return KeyEventResult.handled;
      }
    }

    if (key == LogicalKeyboardKey.escape) {
      sketch.clearSelection();
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
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

  void _onPointerSignal(PointerSignalEvent event) {
    // Mouse wheel zoom.
    if (event is PointerScrollEvent) {
      final delta = event.scrollDelta.dy;
      final zoomFactor = delta > 0 ? -0.05 : 0.05;
      final newZoom = _viewport.zoom + zoomFactor;
      _setViewport(
        ViewportTransform.zoomAtFocalPoint(
          _viewport,
          newZoom,
          event.localPosition,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: (_, event) {
        // While the inline sketch text editor is active, let it own every
        // key — including plain characters — so typing works.
        if (_sketchEditing()) return KeyEventResult.ignored;
        return _handleKey(event);
      },
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
                      gridSpacing: widget.gridSpacing,
                    ),
                  ),
                ),
                SketchLayer(
                  controller: widget.sketchController,
                  viewportProvider: () => _viewport,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
