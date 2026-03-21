import 'package:flutter/widgets.dart';

import 'package:flowcraft/controller/flow_controller.dart';
import 'package:flowcraft/core/models/flow_handle.dart';
import 'package:flowcraft/core/models/flow_node.dart';

/// A function that builds a custom node widget.
typedef NodeWidgetBuilder = Widget Function(
  FlowController controller,
  FlowNode node, {
  void Function(FlowHandle handle)? onHandleDragStarted,
  void Function(Offset globalPosition)? onHandleDragUpdated,
  VoidCallback? onHandleDragEnded,
});

/// A registry for custom node type widget builders.
///
/// Developers can register their own widget builders for custom
/// node types, which the canvas will use when rendering nodes
/// of that type.
///
/// ```dart
/// final registry = NodeTypeRegistry();
/// registry.register('apiNode', (controller, node) {
///   return MyApiNodeWidget(controller: controller, node: node);
/// });
/// ```
class NodeTypeRegistry {
  final Map<String, NodeWidgetBuilder> _builders = {};

  /// Registers a custom widget builder for the given [typeName].
  void register(String typeName, NodeWidgetBuilder builder) {
    _builders[typeName] = builder;
  }

  /// Unregisters a custom widget builder.
  void unregister(String typeName) {
    _builders.remove(typeName);
  }

  /// Returns the builder for the given [typeName], or `null` if not registered.
  NodeWidgetBuilder? builderFor(String typeName) {
    return _builders[typeName];
  }

  /// Whether a builder is registered for the given [typeName].
  bool hasBuilder(String typeName) {
    return _builders.containsKey(typeName);
  }

  /// All registered type names.
  Set<String> get registeredTypes => _builders.keys.toSet();

  /// Clears all registered builders.
  void clear() {
    _builders.clear();
  }
}
