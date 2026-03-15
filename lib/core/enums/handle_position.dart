import 'dart:ui';

/// Defines which side of a node a [FlowHandle] is placed on.
enum HandlePosition {
  /// Top center of the node.
  top,

  /// Bottom center of the node.
  bottom,

  /// Left center of the node.
  left,

  /// Right center of the node.
  right;

  /// Returns the absolute offset position of the handle given the node's [rect].
  Offset toOffset(Rect rect) {
    switch (this) {
      case HandlePosition.top:
        return Offset(rect.left + rect.width / 2, rect.top);
      case HandlePosition.bottom:
        return Offset(rect.left + rect.width / 2, rect.bottom);
      case HandlePosition.left:
        return Offset(rect.left, rect.top + rect.height / 2);
      case HandlePosition.right:
        return Offset(rect.right, rect.top + rect.height / 2);
    }
  }

  /// Converts a string name to a [HandlePosition].
  static HandlePosition fromString(String value) {
    return HandlePosition.values.firstWhere(
      (e) => e.name == value,
      orElse: () => HandlePosition.top,
    );
  }
}
