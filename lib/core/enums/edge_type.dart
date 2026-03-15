/// Defines the routing style of a [FlowEdge].
enum EdgeType {
  /// A smooth cubic bezier curve.
  bezier,

  /// Right-angle path segments with optional rounded corners.
  smoothStep,

  /// Right-angle path segments with sharp corners (no rounding).
  step,

  /// A direct straight line from source to target.
  straight;

  /// Converts a string name to an [EdgeType].
  static EdgeType fromString(String value) {
    return EdgeType.values.firstWhere(
      (e) => e.name == value,
      orElse: () => EdgeType.bezier,
    );
  }
}

