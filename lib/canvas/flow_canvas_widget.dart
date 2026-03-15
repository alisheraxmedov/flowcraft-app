import 'package:flutter/widgets.dart';

import 'package:flowcraft/canvas/canvas_gesture_handler.dart';
import 'package:flowcraft/canvas/canvas_layer_stack.dart';
import 'package:flowcraft/canvas/grid_painter.dart';
import 'package:flowcraft/controller/flow_controller.dart';
import 'package:flowcraft/overlays/controls_widget.dart';
import 'package:flowcraft/overlays/minimap_widget.dart';
import 'package:flowcraft/theme/flow_theme.dart';

/// The root public widget for embedding a FlowCraft canvas.
///
/// This is the single widget developers add to their app:
///
/// ```dart
/// FlowCanvas(
///   controller: controller,
///   theme: FlowTheme.dark(),
///   showMiniMap: true,
///   showControls: true,
/// )
/// ```
class FlowCanvas extends StatefulWidget {
  /// Creates a [FlowCanvas].
  const FlowCanvas({
    super.key,
    required this.controller,
    this.theme,
    this.onNodeTap,
    this.onEdgeTap,
    this.onCanvasTap,
    this.onNodeAdded,
    this.showMiniMap = false,
    this.showControls = true,
    this.gridType = GridType.dots,
    this.minZoom = 0.1,
    this.maxZoom = 4.0,
    this.nodeBuilder,
    this.overlays = const [],
  });

  /// The controller managing all flow state.
  final FlowController controller;

  /// Optional theme configuration.
  final FlowTheme? theme;

  /// Called when a node is tapped.
  final void Function(String nodeId)? onNodeTap;

  /// Called when an edge is tapped.
  final void Function(String edgeId)? onEdgeTap;

  /// Called when the canvas background is tapped.
  final VoidCallback? onCanvasTap;

  /// Called after a new node is added.
  final void Function(String nodeId)? onNodeAdded;

  /// Whether to show the minimap overlay.
  final bool showMiniMap;

  /// Whether to show the zoom controls overlay.
  final bool showControls;

  /// The type of background grid.
  final GridType gridType;

  /// Minimum zoom level.
  final double minZoom;

  /// Maximum zoom level.
  final double maxZoom;

  /// Optional custom node builder.
  final Widget Function(FlowController controller, int index)? nodeBuilder;

  /// Additional overlay widgets.
  final List<Widget> overlays;

  @override
  State<FlowCanvas> createState() => _FlowCanvasState();
}

class _FlowCanvasState extends State<FlowCanvas> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onControllerChanged);
  }

  @override
  void didUpdateWidget(FlowCanvas oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onControllerChanged);
      widget.controller.addListener(_onControllerChanged);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    super.dispose();
  }

  void _onControllerChanged() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme ?? FlowTheme.light();

    // Build the overlays list including optional minimap and controls
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

    return Container(
      color: theme.canvasColor,
      child: CanvasGestureHandler(
        controller: widget.controller,
        onCanvasTap: widget.onCanvasTap,
        child: CanvasLayerStack(
          controller: widget.controller,
          gridType: widget.gridType,
          gridColor: theme.gridColor,
          nodeBuilder: widget.nodeBuilder,
          overlays: allOverlays,
        ),
      ),
    );
  }
}
