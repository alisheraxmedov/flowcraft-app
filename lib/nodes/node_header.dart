import 'package:flutter/widgets.dart';

import 'package:flowcraft/core/enums/node_type.dart';

/// The title bar section at the top of a node widget.
///
/// Displays the node label and an optional type badge.
class NodeHeader extends StatelessWidget {
  /// Creates a [NodeHeader].
  const NodeHeader({
    super.key,
    required this.label,
    this.nodeType = NodeType.defaultNode,
    this.backgroundColor,
  });

  /// The display label.
  final String label;

  /// The node type (used for badge display).
  final NodeType nodeType;

  /// Optional background color.
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    final headerBg = backgroundColor ?? _headerColor(nodeType);
    final isDark = headerBg.computeLuminance() < 0.5;
    final textColor = isDark
        ? const Color(0xFFE0E0E0)
        : const Color(0xFF333333);
    final badgeTextColor = isDark
        ? const Color(0xFFBBBBBB)
        : const Color(0xFF666666);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: headerBg,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(7),
          topRight: Radius.circular(7),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: textColor,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (nodeType != NodeType.defaultNode)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0x33FFFFFF)
                    : const Color(0x22000000),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                nodeType.name,
                style: TextStyle(
                  fontSize: 9,
                  color: badgeTextColor,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Color _headerColor(NodeType type) {
    switch (type) {
      case NodeType.input:
        return const Color(0xFFC8E6C9);
      case NodeType.output:
        return const Color(0xFFFFCDD2);
      case NodeType.trigger:
        return const Color(0xFFFFE0B2);
      case NodeType.custom:
        return const Color(0xFFE1BEE7);
      case NodeType.defaultNode:
        return const Color(0xFFF5F5F5);
    }
  }
}
