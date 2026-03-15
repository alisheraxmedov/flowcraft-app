import 'package:flowcraft/core/enums/handle_position.dart';
import 'package:flowcraft/core/utils/id_generator.dart';

/// A connection point on a [FlowNode] where edges attach.
///
/// Each handle has a position (top, bottom, left, right) on the node
/// and can optionally limit the number of connections.
class FlowHandle {
  /// Creates a [FlowHandle].
  FlowHandle({
    String? id,
    required this.nodeId,
    required this.position,
    this.maxConnections,
  }) : id = id ?? IdGenerator.generate();

  /// Unique identifier for this handle.
  final String id;

  /// The ID of the node this handle belongs to.
  final String nodeId;

  /// The side of the node where this handle is placed.
  final HandlePosition position;

  /// Maximum number of edges that can connect to this handle.
  ///
  /// If `null`, unlimited connections are allowed.
  final int? maxConnections;

  /// Creates a copy of this [FlowHandle] with the given fields replaced.
  FlowHandle copyWith({
    String? id,
    String? nodeId,
    HandlePosition? position,
    int? maxConnections,
  }) {
    return FlowHandle(
      id: id ?? this.id,
      nodeId: nodeId ?? this.nodeId,
      position: position ?? this.position,
      maxConnections: maxConnections ?? this.maxConnections,
    );
  }

  /// Serializes this [FlowHandle] to a JSON map.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'nodeId': nodeId,
      'position': position.name,
      if (maxConnections != null) 'maxConnections': maxConnections,
    };
  }

  /// Deserializes a [FlowHandle] from a JSON map.
  factory FlowHandle.fromJson(Map<String, dynamic> json) {
    return FlowHandle(
      id: json['id'] as String,
      nodeId: json['nodeId'] as String,
      position: HandlePosition.fromString(json['position'] as String),
      maxConnections: json['maxConnections'] as int?,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! FlowHandle) return false;
    return id == other.id &&
        nodeId == other.nodeId &&
        position == other.position &&
        maxConnections == other.maxConnections;
  }

  @override
  int get hashCode => Object.hash(id, nodeId, position, maxConnections);

  @override
  String toString() =>
      'FlowHandle(id: $id, nodeId: $nodeId, position: ${position.name})';
}
