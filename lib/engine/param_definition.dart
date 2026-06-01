/// Defines a configurable parameter on a node definition.
///
/// Parameters are user-editable settings that control node behavior.
class ParamDefinition {
  const ParamDefinition({
    required this.name,
    this.displayName,
    this.type = ParamType.string,
    this.defaultValue,
    this.description,
    this.options,
    this.isRequired = false,
  });

  /// Internal parameter key.
  final String name;

  /// Human-readable display name.
  final String? displayName;

  /// The parameter's data type.
  final ParamType type;

  /// Default value if not configured.
  final dynamic defaultValue;

  /// Description shown in the UI.
  final String? description;

  /// Available options for [ParamType.select].
  final List<String>? options;

  /// Whether this parameter is mandatory for node execution.
  final bool isRequired;

  String get label => displayName ?? name;
}

/// Parameter data types for node configuration.
enum ParamType {
  string,
  number,
  boolean,
  select,
  json,
  code,
  credential,
}
