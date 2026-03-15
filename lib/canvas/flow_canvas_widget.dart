import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'package:flowcraft/canvas/canvas_gesture_handler.dart';
import 'package:flowcraft/canvas/canvas_layer_stack.dart';
import 'package:flowcraft/canvas/grid_painter.dart';
import 'package:flowcraft/controller/flow_controller.dart';
import 'package:flowcraft/overlays/controls_widget.dart';
import 'package:flowcraft/overlays/minimap_widget.dart';
import 'package:flowcraft/theme/flow_theme.dart';

/// The root widget for embedding a FlowCraft canvas.
///
/// ```dart
/// FlowCanvas(controller: controller, theme: FlowTheme.dark())
/// ```
class FlowCanvas extends StatefulWidget {
  const FlowCanvas({
    super.key,
    required this.controller,
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

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    widget.controller.addListener(_rebuild);
  }

  @override
  void didUpdateWidget(FlowCanvas oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_rebuild);
      widget.controller.addListener(_rebuild);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_rebuild);
    _focusNode.dispose();
    super.dispose();
  }

  void _rebuild() => setState(() {});

  void _handleKey(KeyEvent event) {
    if (!widget.enableKeyboardShortcuts) return;
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return;

    final ctrl = HardwareKeyboard.instance.isControlPressed ||
        HardwareKeyboard.instance.isMetaPressed;
    final shift = HardwareKeyboard.instance.isShiftPressed;
    final key = event.logicalKey;

    // Delete / Backspace → remove selected
    if (key == LogicalKeyboardKey.delete ||
        key == LogicalKeyboardKey.backspace) {
      widget.controller.deleteSelection();
      return;
    }

    if (ctrl) {
      if (key == LogicalKeyboardKey.keyZ) {
        shift ? widget.controller.redo() : widget.controller.undo();
        return;
      }
      if (key == LogicalKeyboardKey.keyY) {
        widget.controller.redo();
        return;
      }
      if (key == LogicalKeyboardKey.keyA) {
        widget.controller.selectAll();
        return;
      }
      if (key == LogicalKeyboardKey.keyC) {
        widget.controller.copySelectedNodes();
        return;
      }
      if (key == LogicalKeyboardKey.keyV) {
        widget.controller.pasteNodes();
        return;
      }
    }

    if (key == LogicalKeyboardKey.escape) {
      widget.controller.selection.clearSelection();
    }
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
        _handleKey(event);
        return KeyEventResult.handled;
      },
      child: GestureDetector(
        onTap: () => _focusNode.requestFocus(),
        behavior: HitTestBehavior.translucent,
        child: Container(
          color: theme.canvasColor,
          child: CanvasGestureHandler(
            controller: widget.controller,
            onCanvasTap: () {
              _focusNode.requestFocus();
              widget.onCanvasTap?.call();
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
          ),
        ),
      ),
    );
  }
}
