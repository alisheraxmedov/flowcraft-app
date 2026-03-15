import 'dart:ui';

import 'package:flutter/foundation.dart';

import 'package:flowcraft/core/enums/edge_type.dart';

/// Visual style configuration for an edge.
class EdgeStyle {
  const EdgeStyle({
    this.color = const Color(0xFF42A5F5),
    this.thickness = 2.0,
    this.edgeType = EdgeType.bezier,
    this.animated = true,
    this.dashPattern = const <double>[],
    this.arrowSize = 8.0,
    this.showArrow = true,
    this.label,
  });

  final Color color;
  final double thickness;
  final EdgeType edgeType;
  final bool animated;
  final List<double> dashPattern;
  final double arrowSize;
  final bool showArrow;
  final String? label;

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
