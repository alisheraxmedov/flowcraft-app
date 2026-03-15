import 'package:flutter/widgets.dart';

import 'package:flowcraft/controller/flow_controller.dart';
import 'package:flowcraft/core/models/flow_node.dart';
import 'package:flowcraft/nodes/node_header.dart';
import 'package:flowcraft/handles/handle_widget.dart';
import 'package:flowcraft/theme/flow_theme.dart';

/// The default base node widget used when no custom builder is provided.
///
/// Wraps a node with selection highlight, drag support, handles,
/// delete button, and the standard header/fields layout.
class DefaultBaseNodeWidget extends StatelessWidget {
  const DefaultBaseNodeWidget({
    super.key,
    required this.controller,
    required this.node,
    this.onTap,
    this.theme,
  });

  final FlowController controller;
  final FlowNode node;
  final VoidCallback? onTap;
  final FlowTheme? theme;

  @override
  Widget build(BuildContext context) {
    final isSelected = controller.selection.isNodeSelected(node.id);
    final bgColor = theme?.nodeBackgroundColor ?? const Color(0xFFFFFFFF);
    final borderColor = isSelected
        ? (theme?.nodeSelectedBorderColor ?? const Color(0xFF2196F3))
        : (theme?.nodeBorderColor ?? const Color(0xFFDDDDDD));
    final headerBg = theme?.headerBackgroundColor;

    return GestureDetector(
      onTap: () {
        controller.selection.selectNode(node.id);
        onTap?.call();
      },
      onPanStart: (_) {
        controller.startNodeDrag(node.id);
        controller.selection.selectNode(node.id);
      },
      onPanUpdate: (details) {
        final delta = details.delta / controller.viewport.zoom;
        controller.moveNodeBy(node.id, delta);
      },
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Node body
          Container(
            width: node.size.width,
            height: node.size.height,
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(
                theme?.nodeBorderRadius ?? 8.0,
              ),
              border: Border.all(
                color: borderColor,
                width: isSelected ? 2 : 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0x1A000000),
                  blurRadius: isSelected ? 8 : 4,
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
                  backgroundColor: headerBg,
                ),
              ],
            ),
          ),

          // Handles
          ...node.handles.map((handle) => HandleWidget(
                handle: handle,
                nodeSize: node.size,
              )),

          // Delete button (visible when selected)
          if (isSelected)
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
