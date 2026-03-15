import 'package:flowcraft/core/models/edge_style.dart';
import 'package:flowcraft/core/utils/id_generator.dart';

/// Represents a directed connection between two nodes.
///
/// An edge connects a source handle to a target handle, with a
/// configurable visual style.
class FlowEdge {
  /// Creates a [FlowEdge].
  FlowEdge({
    String? id,
    required this.sourceNodeId,
    required this.targetNodeId,
    required this.sourceHandleId,
    required this.targetHandleId,
    EdgeStyle? style,
  })  : id = id ?? IdGenerator.edgeId(),
        style = style ?? const EdgeStyle();

  /// Unique identifier for this edge.
  final String id;

  /// The ID of the source node.
  final String sourceNodeId;

  /// The ID of the target node.
  final String targetNodeId;

  /// The ID of the source handle on the source node.
  final String sourceHandleId;

  /// The ID of the target handle on the target node.
  final String targetHandleId;

  /// The visual style of this edge.
  EdgeStyle style;

  /// Creates a copy of this [FlowEdge] with the given fields replaced.
  FlowEdge copyWith({
    String? id,
    String? sourceNodeId,
    String? targetNodeId,
    String? sourceHandleId,
    String? targetHandleId,
    EdgeStyle? style,
  }) {
    return FlowEdge(
      id: id ?? this.id,
      sourceNodeId: sourceNodeId ?? this.sourceNodeId,
      targetNodeId: targetNodeId ?? this.targetNodeId,
      sourceHandleId: sourceHandleId ?? this.sourceHandleId,
      targetHandleId: targetHandleId ?? this.targetHandleId,
      style: style ?? this.style,
    );
  }

  /// Serializes this [FlowEdge] to a JSON map.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'sourceNodeId': sourceNodeId,
      'targetNodeId': targetNodeId,
      'sourceHandleId': sourceHandleId,
      'targetHandleId': targetHandleId,
      'style': style.toJson(),
    };
  }

  /// Deserializes a [FlowEdge] from a JSON map.
  factory FlowEdge.fromJson(Map<String, dynamic> json) {
    return FlowEdge(
      id: json['id'] as String,
      sourceNodeId: json['sourceNodeId'] as String,
      targetNodeId: json['targetNodeId'] as String,
      sourceHandleId: json['sourceHandleId'] as String,
      targetHandleId: json['targetHandleId'] as String,
      style: json['style'] != null
          ? EdgeStyle.fromJson(json['style'] as Map<String, dynamic>)
          : const EdgeStyle(),
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! FlowEdge) return false;
    return id == other.id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'FlowEdge(id: $id, source: $sourceNodeId, target: $targetNodeId)';
}
