import 'package:flutter/widgets.dart';

import 'package:flowcraft/core/enums/handle_position.dart';
import 'package:flowcraft/core/models/flow_handle.dart';

/// A small circle/dot representing a connection point on a node.
///
/// Positioned on the edge of the node based on the handle's [HandlePosition].
class HandleWidget extends StatelessWidget {
  /// Creates a [HandleWidget].
  const HandleWidget({
    super.key,
    required this.handle,
    required this.nodeSize,
    this.size = 10.0,
    this.color = const Color(0xFF2196F3),
  });

  /// The handle data.
  final FlowHandle handle;

  /// The size of the parent node (used for positioning).
  final Size nodeSize;

  /// The diameter of the handle dot.
  final double size;

  /// The color of the handle dot.
  final Color color;

  @override
  Widget build(BuildContext context) {
    final pos = _position();

    return Positioned(
      left: pos.dx - size / 2,
      top: pos.dy - size / 2,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: const Color(0xFFFFFFFF),
          border: Border.all(color: color, width: 1.5),
        ),
      ),
    );
  }

  Offset _position() {
    switch (handle.position) {
      case HandlePosition.top:
        return Offset(nodeSize.width / 2, 0);
      case HandlePosition.bottom:
        return Offset(nodeSize.width / 2, nodeSize.height);
      case HandlePosition.left:
        return Offset(0, nodeSize.height / 2);
      case HandlePosition.right:
        return Offset(nodeSize.width, nodeSize.height / 2);
    }
  }
}
