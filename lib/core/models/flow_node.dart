import 'dart:ui';

import 'package:flowcraft/core/enums/handle_position.dart';
import 'package:flowcraft/core/enums/node_type.dart';
import 'package:flowcraft/core/models/flow_handle.dart';
import 'package:flowcraft/core/utils/id_generator.dart';

/// Represents a single node on the flow canvas.
///
/// A node has a position, size, type, label, dynamic data, and a list
/// of connection handles.
class FlowNode {
  /// Creates a [FlowNode].
  ///
  /// If [id] is omitted, a unique ID is auto-generated.
  /// If [handles] is omitted or empty, four default handles (top, bottom,
  /// left, right) are created automatically.
  factory FlowNode({
    String? id,
    NodeType type = NodeType.defaultNode,
    String label = 'Node',
    Offset position = Offset.zero,
    Size size = const Size(180, 60),
    Map<String, dynamic>? data,
    List<FlowHandle>? handles,
  }) {
    final resolvedId = id ?? IdGenerator.nodeId();
    final resolvedHandles = (handles != null && handles.isNotEmpty)
        ? handles
        : _defaultHandles(resolvedId);
    return FlowNode._(
      id: resolvedId,
      type: type,
      label: label,
      position: position,
      size: size,
      data: data ?? {},
      handles: resolvedHandles,
    );
  }

  /// Internal constructor.
  FlowNode._({
    required this.id,
    required this.type,
    required this.label,
    required this.position,
    required this.size,
    required this.data,
    required this.handles,
  });

  /// Creates the four default handles for a new node.
  static List<FlowHandle> _defaultHandles(String nodeId) {
    return [
      FlowHandle(nodeId: nodeId, position: HandlePosition.top),
      FlowHandle(nodeId: nodeId, position: HandlePosition.bottom),
      FlowHandle(nodeId: nodeId, position: HandlePosition.left),
      FlowHandle(nodeId: nodeId, position: HandlePosition.right),
    ];
  }

  /// Unique identifier for this node.
  final String id;

  /// The visual type of this node.
  NodeType type;

  /// The display label for this node.
  String label;

  /// The top-left position of this node on the canvas.
  Offset position;

  /// The size of this node.
  Size size;

  /// Dynamic key-value data attached to this node.
  final Map<String, dynamic> data;

  /// Connection handles on this node.
  final List<FlowHandle> handles;

  /// Returns the bounding rectangle of this node.
  Rect get rect => Rect.fromLTWH(
        position.dx,
        position.dy,
        size.width,
        size.height,
      );

  /// Returns the center position of this node.
  Offset get center => Offset(
        position.dx + size.width / 2,
        position.dy + size.height / 2,
      );

  /// Finds a handle by its ID, or returns `null`.
  FlowHandle? handleById(String handleId) {
    for (final handle in handles) {
      if (handle.id == handleId) return handle;
    }
    return null;
  }

  /// Creates a copy of this [FlowNode] with the given fields replaced.
  FlowNode copyWith({
    String? id,
    NodeType? type,
    String? label,
    Offset? position,
    Size? size,
    Map<String, dynamic>? data,
    List<FlowHandle>? handles,
  }) {
    return FlowNode(
      id: id ?? this.id,
      type: type ?? this.type,
      label: label ?? this.label,
      position: position ?? this.position,
      size: size ?? this.size,
      data: data ?? Map.of(this.data),
      handles: handles ?? this.handles.map((h) => h.copyWith()).toList(),
    );
  }

  /// Serializes this [FlowNode] to a JSON map.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type.name,
      'label': label,
      'position': {'dx': position.dx, 'dy': position.dy},
      'size': {'width': size.width, 'height': size.height},
      'data': data,
      'handles': handles.map((h) => h.toJson()).toList(),
    };
  }

  /// Deserializes a [FlowNode] from a JSON map.
  factory FlowNode.fromJson(Map<String, dynamic> json) {
    final pos = json['position'] as Map<String, dynamic>;
    final sz = json['size'] as Map<String, dynamic>;
    final handlesList = (json['handles'] as List<dynamic>?)
            ?.map((h) => FlowHandle.fromJson(h as Map<String, dynamic>))
            .toList() ??
        [];
    return FlowNode(
      id: json['id'] as String,
      type: NodeType.fromString(json['type'] as String),
      label: json['label'] as String? ?? 'Node',
      position: Offset(
        (pos['dx'] as num).toDouble(),
        (pos['dy'] as num).toDouble(),
      ),
      size: Size(
        (sz['width'] as num).toDouble(),
        (sz['height'] as num).toDouble(),
      ),
      data: Map<String, dynamic>.from(json['data'] as Map? ?? {}),
      handles: handlesList,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! FlowNode) return false;
    return id == other.id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'FlowNode(id: $id, type: ${type.name}, label: $label, position: $position)';
}
