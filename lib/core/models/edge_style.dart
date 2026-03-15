import 'dart:ui';

import 'package:flutter/foundation.dart';

import 'package:flowcraft/core/enums/edge_type.dart';

/// Defines the visual style for an edge.
///
/// Controls color, thickness, type, animation, dasher patterns, and labels.
class EdgeStyle {
  /// Creates an [EdgeStyle].
  const EdgeStyle({
    this.color = const Color(0xFF555555),
    this.thickness = 2.0,
    this.edgeType = EdgeType.bezier,
    this.animated = false,
    this.dashPattern = const <double>[],
    this.arrowSize = 8.0,
    this.showArrow = true,
    this.label,
  });

  /// The color of the edge line.
  final Color color;

  /// The stroke width of the edge.
  final double thickness;

  /// The routing type of the edge (bezier, smoothStep, straight).
  final EdgeType edgeType;

  /// Whether the edge should display a flowing dash animation.
  final bool animated;

  /// Dash pattern as alternating [dash, gap] lengths.
  ///
  /// An empty list renders a solid line.
  final List<double> dashPattern;

  /// The size of the arrow at the target end.
  final double arrowSize;

  /// Whether to draw an arrow at the target end.
  final bool showArrow;

  /// An optional text label displayed at the edge midpoint.
  final String? label;

  /// Creates a copy of this [EdgeStyle] with the given fields replaced.
  EdgeStyle copyWith({
    Color? color,
    double? thickness,
    EdgeType? edgeType,
    bool? animated,
    List<double>? dashPattern,
    double? arrowSize,
    bool? showArrow,
    String? label,
  }) {
    return EdgeStyle(
      color: color ?? this.color,
      thickness: thickness ?? this.thickness,
      edgeType: edgeType ?? this.edgeType,
      animated: animated ?? this.animated,
      dashPattern: dashPattern ?? this.dashPattern,
      arrowSize: arrowSize ?? this.arrowSize,
      showArrow: showArrow ?? this.showArrow,
      label: label ?? this.label,
    );
  }

  /// Serializes this [EdgeStyle] to a JSON map.
  Map<String, dynamic> toJson() {
    return {
      'color': color.toARGB32(),
      'thickness': thickness,
      'edgeType': edgeType.name,
      'animated': animated,
      'dashPattern': dashPattern,
      'arrowSize': arrowSize,
      'showArrow': showArrow,
      if (label != null) 'label': label,
    };
  }

  /// Deserializes an [EdgeStyle] from a JSON map.
  factory EdgeStyle.fromJson(Map<String, dynamic> json) {
    return EdgeStyle(
      color: Color(json['color'] as int),
      thickness: (json['thickness'] as num).toDouble(),
      edgeType: EdgeType.fromString(json['edgeType'] as String),
      animated: json['animated'] as bool? ?? false,
      dashPattern: (json['dashPattern'] as List<dynamic>?)
              ?.map((e) => (e as num).toDouble())
              .toList() ??
          const [],
      arrowSize: (json['arrowSize'] as num?)?.toDouble() ?? 8.0,
      showArrow: json['showArrow'] as bool? ?? true,
      label: json['label'] as String?,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! EdgeStyle) return false;
    return color == other.color &&
        thickness == other.thickness &&
        edgeType == other.edgeType &&
        animated == other.animated &&
        listEquals(dashPattern, other.dashPattern) &&
        arrowSize == other.arrowSize &&
        showArrow == other.showArrow &&
        label == other.label;
  }

  @override
  int get hashCode => Object.hash(
        color,
        thickness,
        edgeType,
        animated,
        Object.hashAll(dashPattern),
        arrowSize,
        showArrow,
        label,
      );
}
