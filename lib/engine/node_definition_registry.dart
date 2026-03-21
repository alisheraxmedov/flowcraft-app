import 'package:flowcraft/engine/node_definition.dart';

/// Registry of available node type definitions.
///
/// Maps `typeId` strings to [NodeDefinition] instances so the
/// execution engine can look up how to execute each node type.
class NodeDefinitionRegistry {
  final Map<String, NodeDefinition> _definitions = {};

  /// Registers a [NodeDefinition].
  void register(NodeDefinition definition) {
    _definitions[definition.typeId] = definition;
  }

  /// Unregisters a node definition by type ID.
  void unregister(String typeId) {
    _definitions.remove(typeId);
  }

  /// Returns the definition for the given type ID, or `null`.
  NodeDefinition? getDefinition(String typeId) {
    return _definitions[typeId];
  }

  /// Whether a definition is registered for the given type ID.
  bool hasDefinition(String typeId) {
    return _definitions.containsKey(typeId);
  }

  /// All registered definitions.
  Iterable<NodeDefinition> get allDefinitions => _definitions.values;

  /// All registered type IDs.
  Set<String> get registeredTypes => _definitions.keys.toSet();

  /// All definitions in a given category.
  List<NodeDefinition> definitionsInCategory(String category) {
    return _definitions.values
        .where((d) => d.category == category)
        .toList();
  }

  /// All unique categories.
  Set<String> get categories {
    return _definitions.values.map((d) => d.category).toSet();
  }
}
