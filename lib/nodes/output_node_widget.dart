import 'package:flutter/widgets.dart';

import 'package:flowcraft/controller/flow_controller.dart';
import 'package:flowcraft/core/models/flow_node.dart';
import 'package:flowcraft/handles/handle_widget.dart';

/// Exit-point node with a rounded bottom and red accent color.
class OutputNodeWidget extends StatelessWidget {
  /// Creates an [OutputNodeWidget].
  const OutputNodeWidget({
    super.key,
    required this.controller,
    required this.node,
  });

  final FlowController controller;
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
            height: node.size.height,
            decoration: BoxDecoration(
              color: const Color(0xFFFFEBEE),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(8),
                topRight: Radius.circular(8),
                bottomLeft: Radius.circular(16),
                bottomRight: Radius.circular(16),
              ),
              border: Border.all(
                color: isSelected
                    ? const Color(0xFFF44336)
                    : const Color(0xFFEF9A9A),
                width: isSelected ? 2 : 1,
              ),
            ),
            alignment: Alignment.center,
            child: Text(
              node.label,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFFC62828),
              ),
            ),
          ),
          ...node.handles.map((h) => HandleWidget(
                handle: h,
                nodeSize: node.size,
                color: const Color(0xFFF44336),
              )),
        ],
      ),
    );
  }
}
