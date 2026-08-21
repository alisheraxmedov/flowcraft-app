import 'dart:ui';

/// Represents the current pan/zoom state of the canvas viewport.
class FlowViewport {
  /// Creates a [FlowViewport].
  const FlowViewport({
    this.offset = Offset.zero,
    this.zoom = 1.0,
    this.minZoom = 0.1,
    this.maxZoom = 4.0,
  });

  /// The current pan offset of the canvas.
  final Offset offset;

  /// The current zoom level (1.0 = 100%).
  final double zoom;

  /// The minimum allowed zoom level.
  final double minZoom;

  /// The maximum allowed zoom level.
  final double maxZoom;

  /// Creates a copy of this [FlowViewport] with the given fields replaced.
  FlowViewport copyWith({
    Offset? offset,
    double? zoom,
    double? minZoom,
    double? maxZoom,
  }) {
    return FlowViewport(
      offset: offset ?? this.offset,
      zoom: zoom != null ? zoom.clamp(this.minZoom, this.maxZoom) : this.zoom,
      minZoom: minZoom ?? this.minZoom,
      maxZoom: maxZoom ?? this.maxZoom,
    );
  }

  /// Serializes this [FlowViewport] to a JSON map.
  Map<String, dynamic> toJson() {
    return {
      'offset': {'dx': offset.dx, 'dy': offset.dy},
      'zoom': zoom,
      'minZoom': minZoom,
      'maxZoom': maxZoom,
    };
  }

  /// Deserializes a [FlowViewport] from a JSON map.
  factory FlowViewport.fromJson(Map<String, dynamic> json) {
    final off = json['offset'] as Map<String, dynamic>;
    return FlowViewport(
      offset: Offset(
        (off['dx'] as num).toDouble(),
        (off['dy'] as num).toDouble(),
      ),
      zoom: (json['zoom'] as num).toDouble(),
      minZoom: (json['minZoom'] as num?)?.toDouble() ?? 0.1,
      maxZoom: (json['maxZoom'] as num?)?.toDouble() ?? 4.0,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! FlowViewport) return false;
    return offset == other.offset &&
        zoom == other.zoom &&
        minZoom == other.minZoom &&
        maxZoom == other.maxZoom;
  }

  @override
  int get hashCode => Object.hash(offset, zoom, minZoom, maxZoom);

  @override
  String toString() =>
      'FlowViewport(offset: $offset, zoom: ${zoom.toStringAsFixed(2)})';
}
