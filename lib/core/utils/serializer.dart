import 'dart:convert';

import 'package:flowcraft/core/models/flow_graph.dart';
import 'package:flowcraft/core/models/flow_viewport.dart';

/// Handles serialization and deserialization of the complete flow state.
class Serializer {
  /// Serializes the entire canvas state (graph + viewport) to a JSON string.
  static String serialize({
    required FlowGraph graph,
    required FlowViewport viewport,
  }) {
    final data = {
      'version': 1,
      'graph': graph.toJson(),
      'viewport': viewport.toJson(),
    };
    return jsonEncode(data);
  }

  /// Deserializes a JSON string back into graph and viewport state.
  ///
  /// Returns a record containing the [FlowGraph] and [FlowViewport].
  static ({FlowGraph graph, FlowViewport viewport}) deserialize(
      String jsonString) {
    final data = jsonDecode(jsonString) as Map<String, dynamic>;
    return (
      graph: FlowGraph.fromJson(data['graph'] as Map<String, dynamic>),
      viewport: data['viewport'] != null
          ? FlowViewport.fromJson(data['viewport'] as Map<String, dynamic>)
          : const FlowViewport(),
    );
  }

  /// Serializes the graph state to a JSON map (not a string).
  static Map<String, dynamic> toMap({
    required FlowGraph graph,
    required FlowViewport viewport,
  }) {
    return {
      'version': 1,
      'graph': graph.toJson(),
      'viewport': viewport.toJson(),
    };
  }

  /// Deserializes from a JSON map.
  static ({FlowGraph graph, FlowViewport viewport}) fromMap(
      Map<String, dynamic> data) {
    return (
      graph: FlowGraph.fromJson(data['graph'] as Map<String, dynamic>),
      viewport: data['viewport'] != null
          ? FlowViewport.fromJson(data['viewport'] as Map<String, dynamic>)
          : const FlowViewport(),
    );
  }
}
