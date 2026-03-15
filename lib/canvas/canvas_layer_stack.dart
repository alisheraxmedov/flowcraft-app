import 'package:flutter/widgets.dart';

import 'package:flowcraft/canvas/grid_painter.dart';
import 'package:flowcraft/canvas/viewport_transform.dart';
import 'package:flowcraft/controller/flow_controller.dart';
import 'package:flowcraft/edges/edge_painter.dart';
import 'package:flowcraft/nodes/base_node_widget.dart';

/// Builds the layered canvas stack: grid → edges → nodes → overlays.
///
/// Each layer is stacked with proper z-ordering and the edges/nodes
/// are transformed according to the current viewport.
class CanvasLayerStack extends StatelessWidget {
  /// Creates a [CanvasLayerStack].
  const CanvasLayerStack({
    super.key,
    required this.controller,
    this.gridType = GridType.dots,
    this.gridColor = const Color(0x22888888),
    this.gridSpacing = 20.0,
    this.nodeBuilder,
    this.overlays = const [],
  });

  /// The flow controller.
  final FlowController controller;

  /// The grid type to display.
  final GridType gridType;

  /// The grid color.
  final Color gridColor;

  /// The spacing of grid points.
  final double gridSpacing;

  /// An optional custom node builder. If null, uses [DefaultBaseNodeWidget].
  final Widget Function(FlowController controller, int index)? nodeBuilder;

  /// Overlay widgets to render on top of the canvas.
  final List<Widget> overlays;

  @override
  Widget build(BuildContext context) {
    final viewport = controller.viewport;

    return ClipRect(
      child: Stack(
        children: [
          // Layer 1: Background grid
          Positioned.fill(
            child: CustomPaint(
              painter: GridPainter(
                viewport: viewport,
                gridType: gridType,
                gridColor: gridColor,
                gridSpacing: gridSpacing,
              ),
            ),
          ),

          // Layer 2: Edges (transformed)
          Positioned.fill(
            child: RepaintBoundary(
              child: CustomPaint(
                painter: EdgePainter(
                  controller: controller,
                ),
              ),
            ),
          ),

          // Layer 3: Nodes (transformed)
          ...List.generate(controller.nodes.length, (index) {
            final node = controller.nodes[index];
            final screenPos = ViewportTransform.canvasToScreen(
              node.position,
              viewport,
            );

            return Positioned(
              left: screenPos.dx,
              top: screenPos.dy,
              child: Transform.scale(
                scale: viewport.zoom,
                alignment: Alignment.topLeft,
                child: RepaintBoundary(
                  child: nodeBuilder != null
                      ? nodeBuilder!(controller, index)
                      : DefaultBaseNodeWidget(
                          controller: controller,
                          node: node,
                        ),
                ),
              ),
            );
          }),

          // Layer 4: Overlays (zoom controls, minimap, etc.)
          ...overlays,
        ],
      ),
    );
  }
}
