import 'package:flutter/widgets.dart';

import 'package:flowcraft/controller/flow_controller.dart';
import 'package:flowcraft/core/models/flow_node.dart';
import 'package:flowcraft/handles/handle_widget.dart';
import 'package:flowcraft/nodes/node_header.dart';
import 'package:flowcraft/nodes/node_fields_panel.dart';

/// Standard rectangular node widget.
///
/// This is the most common node type with a white background,
/// header, and optional expandable fields panel.
class DefaultNodeWidget extends StatelessWidget {
  /// Creates a [DefaultNodeWidget].
  const DefaultNodeWidget({
    super.key,
    required this.controller,
    required this.node,
  });

  /// The flow controller.
  final FlowController controller;

  /// The node data.
  final FlowNode node;

  @override
  Widget build(BuildContext context) {
    final isSelected = controller.selection.isNodeSelected(node.id);

    return GestureDetector(
      onTap: () => controller.selection.selectNode(node.id),
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
          Container(
            width: node.size.width,
            constraints: BoxConstraints(minHeight: node.size.height),
            decoration: BoxDecoration(
              color: const Color(0xFFFFFFFF),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isSelected
                    ? const Color(0xFF2196F3)
                    : const Color(0xFFE0E0E0),
                width: isSelected ? 2 : 1,
              ),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x14000000),
                  blurRadius: 6,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                NodeHeader(label: node.label, nodeType: node.type),
                if (node.data.isNotEmpty)
                  NodeFieldsPanel(data: node.data),
              ],
            ),
          ),
          ...node.handles.map((h) => HandleWidget(
                handle: h,
                nodeSize: node.size,
              )),
        ],
      ),
    );
  }
}
