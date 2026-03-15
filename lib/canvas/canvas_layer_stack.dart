import 'package:flutter/widgets.dart';

import 'package:flowcraft/canvas/grid_painter.dart';
import 'package:flowcraft/canvas/viewport_transform.dart';
import 'package:flowcraft/controller/flow_controller.dart';
import 'package:flowcraft/core/enums/handle_position.dart';
import 'package:flowcraft/core/models/flow_viewport.dart';
import 'package:flowcraft/edges/bezier_edge.dart';
import 'package:flowcraft/edges/edge_label_widget.dart';
import 'package:flowcraft/edges/edge_painter.dart';
import 'package:flowcraft/edges/smooth_step_edge.dart';
import 'package:flowcraft/edges/straight_edge.dart';
import 'package:flowcraft/core/enums/edge_type.dart';
import 'package:flowcraft/nodes/base_node_widget.dart';
import 'package:flowcraft/theme/flow_theme.dart';

/// Builds the layered canvas stack: grid → edges → nodes → edge labels → overlays.
///
/// Includes an [AnimationController] that drives animated dash edges.
class CanvasLayerStack extends StatefulWidget {
  const CanvasLayerStack({
    super.key,
    required this.controller,
    this.gridType = GridType.dots,
    this.gridColor = const Color(0x22888888),
    this.gridSpacing = 20.0,
    this.nodeBuilder,
    this.overlays = const [],
    this.theme,
    this.onNodeTap,
    this.onEdgeTap,
  });

  final FlowController controller;
  final GridType gridType;
  final Color gridColor;
  final double gridSpacing;
  final Widget Function(FlowController controller, int index)? nodeBuilder;
  final List<Widget> overlays;
  final FlowTheme? theme;
  final void Function(String nodeId)? onNodeTap;
  final void Function(String edgeId)? onEdgeTap;

  @override
  State<CanvasLayerStack> createState() => _CanvasLayerStackState();
}

class _CanvasLayerStackState extends State<CanvasLayerStack>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final viewport = widget.controller.viewport;
    final theme = widget.theme;

    return ClipRect(
      child: Stack(
        children: [
          // Layer 1: Background grid
          Positioned.fill(
            child: CustomPaint(
              painter: GridPainter(
                viewport: viewport,
                gridType: widget.gridType,
                gridColor: widget.gridColor,
                gridSpacing: widget.gridSpacing,
              ),
            ),
          ),

          // Layer 2: Edges (animated)
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _animationController,
              builder: (context, child) {
                return CustomPaint(
                  painter: EdgePainter(
                    controller: widget.controller,
                    animationValue: _animationController.value,
                  ),
                );
              },
            ),
          ),

          // Layer 3: Nodes (transformed)
          ...List.generate(widget.controller.nodes.length, (index) {
            final node = widget.controller.nodes[index];
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
                  child: widget.nodeBuilder != null
                      ? widget.nodeBuilder!(widget.controller, index)
                      : DefaultBaseNodeWidget(
                          controller: widget.controller,
                          node: node,
                          theme: theme,
                          onTap: widget.onNodeTap != null
                              ? () => widget.onNodeTap!(node.id)
                              : null,
                        ),
                ),
              ),
            );
          }),

          // Layer 4: Edge labels (rendered as widgets on top of nodes)
          ..._buildEdgeLabels(viewport),

          // Layer 5: Overlays (zoom controls, minimap, etc.)
          ...widget.overlays,
        ],
      ),
    );
  }

  List<Widget> _buildEdgeLabels(FlowViewport viewport) {
    final labels = <Widget>[];

    for (final edge in widget.controller.edges) {
      if (edge.style.label == null || edge.style.label!.isEmpty) continue;

      final sourceNode =
          widget.controller.graph.nodeById(edge.sourceNodeId);
      final targetNode =
          widget.controller.graph.nodeById(edge.targetNodeId);
      if (sourceNode == null || targetNode == null) continue;

      final sourceHandle = sourceNode.handleById(edge.sourceHandleId);
      final targetHandle = targetNode.handleById(edge.targetHandleId);
      if (sourceHandle == null || targetHandle == null) continue;

      final sourceOffset =
          sourceHandle.position.toOffset(sourceNode.rect);
      final targetOffset =
          targetHandle.position.toOffset(targetNode.rect);

      final screenSource =
          ViewportTransform.canvasToScreen(sourceOffset, viewport);
      final screenTarget =
          ViewportTransform.canvasToScreen(targetOffset, viewport);

      final midpoint = _computeEdgeMidpoint(
        edge.style.edgeType,
        screenSource,
        screenTarget,
        sourceHandle.position,
        targetHandle.position,
      );

      final isDark = widget.theme != null &&
          widget.theme!.canvasColor.computeLuminance() < 0.5;

      labels.add(
        EdgeLabelWidget(
          label: edge.style.label!,
          position: midpoint,
          backgroundColor: isDark
              ? const Color(0xFF2D2D2D)
              : const Color(0xFFFFFFFF),
          style: TextStyle(
            fontSize: 10 * viewport.zoom,
            color: edge.style.color,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }

    return labels;
  }

  Offset _computeEdgeMidpoint(
    EdgeType edgeType,
    Offset source,
    Offset target,
    HandlePosition sourcePos,
    HandlePosition targetPos,
  ) {
    switch (edgeType) {
      case EdgeType.bezier:
        return BezierEdge.midpoint(
          source,
          target,
          sourcePosition: sourcePos,
          targetPosition: targetPos,
        );
      case EdgeType.smoothStep:
        return SmoothStepEdge.midpoint(source, target);
      case EdgeType.straight:
        return StraightEdge.midpoint(source, target);
    }
  }
}
