/// Defines an input or output port on a node definition.
///
/// Ports are the connection points for data flow between nodes.
class PortDefinition {
  const PortDefinition({
    required this.name,
    this.displayName,
    this.dataType = PortDataType.any,
    this.required = true,
  });

  /// Internal name used as the port key.
  final String name;

  /// Human-readable display name.
  final String? displayName;

  /// Expected data type flowing through this port.
  final PortDataType dataType;

  /// Whether this port must be connected for execution.
  final bool required;

  String get label => displayName ?? name;
}

/// Data type classification for port values.
enum PortDataType {
  string,
  number,
  boolean,
  json,
  list,
  any,
}
