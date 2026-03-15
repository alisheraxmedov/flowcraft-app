import 'package:flutter/widgets.dart';

import 'package:flowcraft/controller/flow_controller.dart';
import 'package:flowcraft/core/models/flow_handle.dart';
import 'package:flowcraft/core/models/flow_node.dart';
import 'package:flowcraft/nodes/node_header.dart';
import 'package:flowcraft/handles/handle_widget.dart';
import 'package:flowcraft/theme/flow_theme.dart';

/// Default node widget with selection, drag, handles, and delete button.
class DefaultBaseNodeWidget extends StatelessWidget {
  const DefaultBaseNodeWidget({
    super.key,
    required this.controller,
    required this.node,
    this.onTap,
    this.theme,
    this.onHandleDragStarted,
    this.onHandleDragUpdated,
    this.onHandleDragEnded,
  });

  final FlowController controller;
  final FlowNode node;
  final VoidCallback? onTap;
  final FlowTheme? theme;
  final void Function(FlowHandle handle)? onHandleDragStarted;
  final void Function(Offset globalPosition)? onHandleDragUpdated;
  final VoidCallback? onHandleDragEnded;

  @override
  Widget build(BuildContext context) {
    final selected = controller.selection.isNodeSelected(node.id);
    final bg = theme?.nodeBackgroundColor ?? const Color(0xFFFFFFFF);
    final border = selected
        ? (theme?.nodeSelectedBorderColor ?? const Color(0xFF2196F3))
        : (theme?.nodeBorderColor ?? const Color(0xFFDDDDDD));
    final handleColor = theme?.handleBorderColor ?? const Color(0xFF2196F3);

    return GestureDetector(
      onTap: () {
        controller.selection.selectNode(node.id);
        onTap?.call();
      },
      onPanStart: (_) {
        controller.startNodeDrag(node.id);
        controller.selection.selectNode(node.id);
      },
      onPanUpdate: (d) {
        controller.moveNodeBy(node.id, d.delta / controller.viewport.zoom);
      },
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: node.size.width,
            height: node.size.height,
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(
                theme?.nodeBorderRadius ?? 8.0,
              ),
              border: Border.all(
                color: border,
                width: selected ? 2 : 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0x1A000000),
                  blurRadius: selected ? 8 : 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                NodeHeader(
                  label: node.label,
                  nodeType: node.type,
                  backgroundColor: theme?.headerBackgroundColor,
                ),
              ],
            ),
          ),

          // Handles
          ...node.handles.map((h) => HandleWidget(
                handle: h,
                nodeSize: node.size,
                color: handleColor,
                onDragStarted: onHandleDragStarted,
                onDragUpdated: onHandleDragUpdated,
                onDragEnded: onHandleDragEnded,
              )),

          // Delete button
          if (selected)
            Positioned(
              top: -8,
              right: -8,
              child: GestureDetector(
                onTap: () => controller.removeNode(node.id),
                child: Container(
                  width: 20,
                  height: 20,
                  decoration: const BoxDecoration(
                    color: Color(0xFFEF4444),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Color(0x33000000),
                        blurRadius: 4,
                        offset: Offset(0, 1),
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Text(
                      '×',
                      style: TextStyle(
                        color: Color(0xFFFFFFFF),
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        height: 1.0,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
