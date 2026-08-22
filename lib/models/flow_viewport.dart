import 'dart:ui';

/// Represents the current pan/zoom state of the canvas viewport.
///
/// The constructor is `const` and does not validate: a caller building one
/// directly is expected to keep [zoom] inside [minZoom]..[maxZoom] (the
/// exporter widens the limits to fit the zoom it needs, for instance).
/// [copyWith] is the path every interactive change takes, and it clamps —
/// against the limits the copy will have, not the ones it had.
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
  ///
  /// [zoom] is clamped into the *new* range: a call that narrows the limits
  /// and passes a zoom in the same breath used to clamp that zoom against
  /// the old limits, and a call that only narrowed the limits left the
  /// existing zoom outside them.
  FlowViewport copyWith({
    Offset? offset,
    double? zoom,
    double? minZoom,
    double? maxZoom,
  }) {
    final lo = minZoom ?? this.minZoom;
    final hi = maxZoom ?? this.maxZoom;
    return FlowViewport(
      offset: offset ?? this.offset,
      zoom: (zoom ?? this.zoom).clamp(lo, hi),
      minZoom: lo,
      maxZoom: hi,
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
