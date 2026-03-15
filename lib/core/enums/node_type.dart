/// Defines the visual type of a [FlowNode].
enum NodeType {
  /// A standard rectangular node.
  defaultNode,

  /// An entry-point node, typically styled with a rounded top and accent color.
  input,

  /// An exit-point node, typically styled with a rounded bottom.
  output,

  /// A custom node type whose rendering is provided by a [NodeTypeRegistry].
  custom;

  /// Converts a string name to a [NodeType].
  static NodeType fromString(String value) {
    return NodeType.values.firstWhere(
      (e) => e.name == value,
      orElse: () => NodeType.defaultNode,
    );
  }
}
