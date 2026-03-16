import 'package:flutter/widgets.dart';

import 'package:flowcraft/canvas/grid_painter.dart';
import 'package:flowcraft/canvas/viewport_transform.dart';
import 'package:flowcraft/controller/flow_controller.dart';
import 'package:flowcraft/core/enums/handle_position.dart';
import 'package:flowcraft/core/enums/node_type.dart';
import 'package:flowcraft/core/models/flow_handle.dart';
import 'package:flowcraft/core/models/flow_node.dart';
import 'package:flowcraft/core/models/flow_viewport.dart';
import 'package:flowcraft/edges/bezier_edge.dart';
import 'package:flowcraft/edges/edge_label_widget.dart';
import 'package:flowcraft/edges/edge_painter.dart';
import 'package:flowcraft/edges/smooth_step_edge.dart';
import 'package:flowcraft/edges/step_edge.dart';
import 'package:flowcraft/edges/straight_edge.dart';
import 'package:flowcraft/core/enums/edge_type.dart';
import 'package:flowcraft/nodes/trigger_node_widget.dart';
import 'package:flowcraft/handles/connection_line_painter.dart';
import 'package:flowcraft/nodes/base_node_widget.dart';
import 'package:flowcraft/theme/flow_theme.dart';

/// Layered canvas: grid → edges → nodes → labels → overlays.
///
/// Drives edge dash animation and manages connection drag state.
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
    this.onConnectionCreated,
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
  final void Function(String edgeId)? onConnectionCreated;

  @override
  State<CanvasLayerStack> createState() => _CanvasLayerStackState();
}

class _CanvasLayerStackState extends State<CanvasLayerStack>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  bool _animationRunning = false;

  FlowHandle? _dragSourceHandle;
  Offset? _dragStart;
  Offset? _dragCurrent;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _syncAnimationState();
  }

  @override
  void didUpdateWidget(CanvasLayerStack oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncAnimationState();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _syncAnimationState() {
    final hasAnimated = widget.controller.edges.any((e) => e.style.animated);
    if (hasAnimated && !_animationRunning) {
      _animController.repeat();
      _animationRunning = true;
    } else if (!hasAnimated && _animationRunning) {
      _animController.stop();
      _animController.value = 0;
      _animationRunning = false;
    }
  }

  // ── Connection Drag ───────────────────────────────────────────────────────

  void _onHandleDragStarted(FlowHandle handle) {
    final node = widget.controller.graph.nodeById(handle.nodeId);
    if (node == null) return;

    final offset = handle.position.toOffset(node.rect);
    final screen = ViewportTransform.canvasToScreen(
      offset,
      widget.controller.viewport,
    );

    setState(() {
      _dragSourceHandle = handle;
      _dragStart = screen;
      _dragCurrent = screen;
    });
  }

  void _onHandleDragUpdated(Offset globalPosition) {
    if (_dragSourceHandle == null) return;
    final box = context.findRenderObject() as RenderBox?;
    if (box == null) return;

    setState(() {
      _dragCurrent = box.globalToLocal(globalPosition);
    });
  }

  void _onHandleDragEnded() {
    if (_dragSourceHandle == null || _dragCurrent == null) {
      _cancelDrag();
      return;
    }

    final target = _findTargetHandle(_dragCurrent!);
    if (target != null) {
      final edge = widget.controller.addEdge(
        sourceNodeId: _dragSourceHandle!.nodeId,
        targetNodeId: target.nodeId,
        sourceHandleId: _dragSourceHandle!.id,
        targetHandleId: target.id,
      );
      if (edge != null) {
        widget.onConnectionCreated?.call(edge.id);
      }
    }

    _cancelDrag();
  }

  void _cancelDrag() {
    setState(() {
      _dragSourceHandle = null;
      _dragStart = null;
      _dragCurrent = null;
    });
  }

  FlowHandle? _findTargetHandle(Offset screenPos) {
    const hitRadiusSq = 20.0 * 20.0;
    double bestDistSq = hitRadiusSq;
    FlowHandle? best;

    for (final node in widget.controller.nodes) {
      if (node.id == _dragSourceHandle?.nodeId) continue;

      for (final handle in node.handles) {
        final pos = handle.position.toOffset(node.rect);
        final screen = ViewportTransform.canvasToScreen(
          pos,
          widget.controller.viewport,
        );

        final dx = screenPos.dx - screen.dx;
        final dy = screenPos.dy - screen.dy;
        final distSq = dx * dx + dy * dy;

        if (distSq < bestDistSq) {
          bestDistSq = distSq;
          best = handle;
        }
      }
    }

    return best;
  }

  // ── Viewport culling ──────────────────────────────────────────────────────

  bool _isNodeVisible(Offset screenPos, Size nodeSize, double zoom, Size canvasSize) {
    final scaledWidth = nodeSize.width * zoom;
    final scaledHeight = nodeSize.height * zoom;
    const margin = 50.0;
    return screenPos.dx + scaledWidth > -margin &&
        screenPos.dx < canvasSize.width + margin &&
        screenPos.dy + scaledHeight > -margin &&
        screenPos.dy < canvasSize.height + margin;
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final viewport = widget.controller.viewport;
    final theme = widget.theme;

    return ClipRect(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final canvasSize = Size(constraints.maxWidth, constraints.maxHeight);

          return Stack(
            children: [
              // Grid
              Positioned.fill(
                child: RepaintBoundary(
                  child: CustomPaint(
                    painter: GridPainter(
                      viewport: viewport,
                      gridType: widget.gridType,
                      gridColor: widget.gridColor,
                      gridSpacing: widget.gridSpacing,
                    ),
                  ),
                ),
              ),

              // Edges
              Positioned.fill(
                child: RepaintBoundary(
                  child: _animationRunning
                      ? AnimatedBuilder(
                          animation: _animController,
                          builder: (context, _) {
                            return CustomPaint(
                              painter: EdgePainter(
                                controller: widget.controller,
                                animationValue: _animController.value,
                                canvasSize: canvasSize,
                              ),
                            );
                          },
                        )
                      : CustomPaint(
                          painter: EdgePainter(
                            controller: widget.controller,
                            animationValue: 0,
                            canvasSize: canvasSize,
                          ),
                        ),
                ),
              ),

              // Connection preview line
              if (_dragSourceHandle != null &&
                  _dragStart != null &&
                  _dragCurrent != null)
                Positioned.fill(
                  child: CustomPaint(
                    painter: ConnectionLinePainter(
                      startPoint: _dragStart!,
                      endPoint: _dragCurrent!,
                      color: theme?.handleBorderColor ?? const Color(0xFF2196F3),
                      strokeWidth: 2.0,
                    ),
                  ),
                ),

              // Nodes (with viewport culling and ValueKey)
              ..._buildVisibleNodes(viewport, canvasSize),

              // Edge labels
              ..._buildEdgeLabels(viewport),

              // Overlays
              ...widget.overlays,
            ],
          );
        },
      ),
    );
  }

  List<Widget> _buildVisibleNodes(FlowViewport viewport, Size canvasSize) {
    final nodes = widget.controller.nodes;
    final result = <Widget>[];

    for (int i = 0; i < nodes.length; i++) {
      final node = nodes[i];
      final screenPos = ViewportTransform.canvasToScreen(
        node.position,
        viewport,
      );

      if (!_isNodeVisible(screenPos, node.size, viewport.zoom, canvasSize)) {
        continue;
      }

      result.add(
        Positioned(
          key: ValueKey(node.id),
          left: screenPos.dx,
          top: screenPos.dy,
          child: Transform.scale(
            scale: viewport.zoom,
            alignment: Alignment.topLeft,
            child: RepaintBoundary(
              child: widget.nodeBuilder != null
                  ? widget.nodeBuilder!(widget.controller, i)
                  : _buildNodeWidget(node),
            ),
          ),
        ),
      );
    }

    return result;
  }

  Widget _buildNodeWidget(FlowNode node) {
    if (node.type == NodeType.trigger) {
      final isOutputTrigger = node.data['direction'] == 'output';
      return TriggerNodeWidget(
        controller: widget.controller,
        node: node,
        reversed: isOutputTrigger,
        theme: widget.theme,
        onTap: widget.onNodeTap != null
            ? () => widget.onNodeTap!(node.id)
            : null,
        onHandleDragStarted: _onHandleDragStarted,
        onHandleDragUpdated: _onHandleDragUpdated,
        onHandleDragEnded: _onHandleDragEnded,
      );
    }
    return DefaultBaseNodeWidget(
      controller: widget.controller,
      node: node,
      theme: widget.theme,
      onTap: widget.onNodeTap != null
          ? () => widget.onNodeTap!(node.id)
          : null,
      onHandleDragStarted: _onHandleDragStarted,
      onHandleDragUpdated: _onHandleDragUpdated,
      onHandleDragEnded: _onHandleDragEnded,
    );
  }

  List<Widget> _buildEdgeLabels(FlowViewport viewport) {
    final labels = <Widget>[];

    for (final edge in widget.controller.edges) {
      if (edge.style.label == null || edge.style.label!.isEmpty) continue;

      final sourceNode = widget.controller.graph.nodeById(edge.sourceNodeId);
      final targetNode = widget.controller.graph.nodeById(edge.targetNodeId);
      if (sourceNode == null || targetNode == null) continue;

      final sourceHandle = sourceNode.handleById(edge.sourceHandleId);
      final targetHandle = targetNode.handleById(edge.targetHandleId);
      if (sourceHandle == null || targetHandle == null) continue;

      final screenSource = ViewportTransform.canvasToScreen(
        sourceHandle.position.toOffset(sourceNode.rect),
        viewport,
      );
      final screenTarget = ViewportTransform.canvasToScreen(
        targetHandle.position.toOffset(targetNode.rect),
        viewport,
      );

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
      case EdgeType.step:
        return StepEdge.midpoint(source, target);
      case EdgeType.straight:
        return StraightEdge.midpoint(source, target);
    }
  }
}
