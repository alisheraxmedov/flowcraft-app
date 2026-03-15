import 'package:flutter/widgets.dart';

import 'package:flowcraft/controller/flow_controller.dart';
import 'package:flowcraft/core/models/flow_node.dart';
import 'package:flowcraft/nodes/node_header.dart';
import 'package:flowcraft/handles/handle_widget.dart';

/// The default base node widget used when no custom builder is provided.
///
/// Wraps a node with selection highlight, drag support, handles,
/// and the standard header/fields layout.
class DefaultBaseNodeWidget extends StatelessWidget {
  /// Creates a [DefaultBaseNodeWidget].
  const DefaultBaseNodeWidget({
    super.key,
    required this.controller,
    required this.node,
    this.onTap,
  });

  /// The flow controller.
  final FlowController controller;

  /// The node data to render.
  final FlowNode node;

  /// Called when the node is tapped.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final isSelected = controller.selection.isNodeSelected(node.id);

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
              color: const Color(0xFFFFFFFF),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isSelected
                    ? const Color(0xFF2196F3)
                    : const Color(0xFFDDDDDD),
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
                ),
              ],
            ),
          ),

          // Handles
          ...node.handles.map((handle) => HandleWidget(
                handle: handle,
                nodeSize: node.size,
              )),
        ],
      ),
    );
  }
}
