import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'package:flowcraft/canvas/canvas_gesture_handler.dart';
import 'package:flowcraft/canvas/canvas_layer_stack.dart';
import 'package:flowcraft/canvas/grid_painter.dart';
import 'package:flowcraft/controller/flow_controller.dart';
import 'package:flowcraft/overlays/controls_widget.dart';
import 'package:flowcraft/overlays/minimap_widget.dart';
import 'package:flowcraft/sketch/models/sketch_tool.dart';
import 'package:flowcraft/sketch/state/sketch_controller.dart';
import 'package:flowcraft/sketch/widgets/sketch_layer.dart';
import 'package:flowcraft/theme/flow_theme.dart';

/// The root widget for embedding a FlowCraft canvas.
///
/// ```dart
/// FlowCanvas(controller: controller, theme: FlowTheme.dark())
/// ```
///
/// Provide a [sketchController] to enable the Excalidraw-style drawing
/// layer on top of the flow graph. The layer suppresses canvas
/// pan/zoom while a drawing tool is active so users can sketch without
/// fighting the gesture arena.
class FlowCanvas extends StatefulWidget {
  const FlowCanvas({
    super.key,
    required this.controller,
    this.sketchController,
    this.theme,
    this.onNodeTap,
    this.onEdgeTap,
    this.onCanvasTap,
    this.onNodeAdded,
    this.onConnectionCreated,
    this.showMiniMap = false,
    this.showControls = true,
    this.gridType = GridType.dots,
    this.minZoom = 0.1,
    this.maxZoom = 4.0,
    this.nodeBuilder,
    this.overlays = const [],
    this.enableKeyboardShortcuts = true,
  });

  final FlowController controller;

  /// Optional sketch (drawing) controller. When supplied, a [SketchLayer]
  /// is composed above the flow graph and gestures are routed to it
  /// when a drawing tool is active.
  final SketchController? sketchController;

  final FlowTheme? theme;
  final void Function(String nodeId)? onNodeTap;
  final void Function(String edgeId)? onEdgeTap;
  final VoidCallback? onCanvasTap;
  final void Function(String nodeId)? onNodeAdded;
  final void Function(String edgeId)? onConnectionCreated;
  final bool showMiniMap;
  final bool showControls;
  final GridType gridType;
  final double minZoom;
  final double maxZoom;
  final Widget Function(FlowController controller, int index)? nodeBuilder;
  final List<Widget> overlays;
  final bool enableKeyboardShortcuts;

  @override
  State<FlowCanvas> createState() => _FlowCanvasState();
}

class _FlowCanvasState extends State<FlowCanvas> {
  late FocusNode _focusNode;

  /// True while the sketch layer is consuming pointer events. When true,
  /// [CanvasGestureHandler] is bypassed so pan/zoom doesn't fight the
  /// drawing gesture.
  final ValueNotifier<bool> _sketchConsuming = ValueNotifier<bool>(false);

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    widget.sketchController?.addListener(_syncSketchActive);
    _syncSketchActive();
  }

  @override
  void didUpdateWidget(FlowCanvas old) {
    super.didUpdateWidget(old);
    if (old.sketchController != widget.sketchController) {
      old.sketchController?.removeListener(_syncSketchActive);
      widget.sketchController?.addListener(_syncSketchActive);
      _syncSketchActive();
    }
  }

  @override
  void dispose() {
    widget.sketchController?.removeListener(_syncSketchActive);
    _sketchConsuming.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  /// Recomputes whether the sketch layer should own pointer input.
  ///
  /// The sketch layer owns input whenever the user has picked a
  /// drawing-style tool (anything other than [SketchTool.hand]).
  /// [SketchTool.hand] is a deliberate pass-through tool that delegates
  /// to the underlying canvas pan.
  void _syncSketchActive() {
    final sc = widget.sketchController;
    if (sc == null) {
      _sketchConsuming.value = false;
      return;
    }
    final active = sc.currentTool != SketchTool.hand;
    if (_sketchConsuming.value != active) {
      _sketchConsuming.value = active;
    }
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
      if (sketch != null && sketch.hasSelection) {
        sketch.removeSelected();
      } else {
        widget.controller.deleteSelection();
      }
      return KeyEventResult.handled;
    }

    if (ctrl) {
      if (key == LogicalKeyboardKey.keyZ) {
        if (sketch != null && (shift ? sketch.canRedo : sketch.canUndo)) {
          shift ? sketch.redo() : sketch.undo();
        } else {
          shift ? widget.controller.redo() : widget.controller.undo();
        }
        return KeyEventResult.handled;
      }
      if (key == LogicalKeyboardKey.keyY) {
        if (sketch != null && sketch.canRedo) {
          sketch.redo();
        } else {
          widget.controller.redo();
        }
        return KeyEventResult.handled;
      }
      if (key == LogicalKeyboardKey.keyA) {
        widget.controller.selectAll();
        return KeyEventResult.handled;
      }
      if (key == LogicalKeyboardKey.keyC) {
        widget.controller.copySelectedNodes();
        return KeyEventResult.handled;
      }
      if (key == LogicalKeyboardKey.keyV) {
        widget.controller.pasteNodes();
        return KeyEventResult.handled;
      }
    }

    if (key == LogicalKeyboardKey.escape) {
      widget.controller.selection.clearSelection();
      sketch?.clearSelection();
      return KeyEventResult.handled;
    }

    // Anything else (letters, digits, arrows, etc.) must fall through
    // so descendants like inline text editors can consume them.
    return KeyEventResult.ignored;
  }

  bool _sketchEditing() {
    final s = widget.sketchController;
    return s != null &&
        (s.editingElementId != null || s.editingCanvasPosition != null);
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme ?? FlowTheme.light();

    final allOverlays = <Widget>[
      ...widget.overlays,
      if (widget.showControls)
        ControlsWidget(controller: widget.controller),
      if (widget.showMiniMap)
        MinimapWidget(
          controller: widget.controller,
          backgroundColor: theme.minimapBackgroundColor,
          nodeColor: theme.minimapNodeColor,
          viewportColor: theme.minimapViewportColor,
        ),
    ];

    return Focus(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: (_, event) {
        // While the inline sketch text editor is active, let it own
        // every key — including plain characters — so typing works.
        if (_sketchEditing()) return KeyEventResult.ignored;
        return _handleKey(event);
      },
      child: GestureDetector(
        onTap: () {
          // Don't steal focus when the sketch text editor is up;
          // doing so kills typing.
          if (_sketchEditing()) return;
          _focusNode.requestFocus();
        },
        behavior: HitTestBehavior.translucent,
        child: Container(
          color: theme.canvasColor,
          child: ListenableBuilder(
            listenable: widget.controller,
            builder: (context, _) {
              final flowCanvas = ValueListenableBuilder<bool>(
                valueListenable: _sketchConsuming,
                builder: (context, consuming, child) {
                  return CanvasGestureHandler(
                    controller: widget.controller,
                    enabled: !consuming,
                    onCanvasTap: () {
                      _focusNode.requestFocus();
                      widget.onCanvasTap?.call();
                    },
                    child: child!,
                  );
                },
                child: CanvasLayerStack(
                  controller: widget.controller,
                  gridType: widget.gridType,
                  gridColor: theme.gridColor,
                  nodeBuilder: widget.nodeBuilder,
                  overlays: allOverlays,
                  theme: theme,
                  onNodeTap: widget.onNodeTap,
                  onEdgeTap: widget.onEdgeTap,
                  onConnectionCreated: widget.onConnectionCreated,
                ),
              );

              if (widget.sketchController == null) return flowCanvas;

              return Stack(
                fit: StackFit.expand,
                children: [
                  flowCanvas,
                  SketchLayer(
                    controller: widget.sketchController!,
                    viewportProvider: () => widget.controller.viewport,
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
