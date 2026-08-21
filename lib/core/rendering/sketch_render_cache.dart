import 'dart:ui';

import 'package:flowcraft/models/sketch_element.dart';
import 'package:flowcraft/models/sketch_style.dart';
import 'package:flowcraft/core/rendering/rough_generator.dart';

/// LRU-ish cache of rough/sketchy paths keyed by element identity.
///
/// Paths are deterministic for a given (seed, roughness, geometry) tuple,
/// so re-using them across paint frames eliminates redundant work and
/// preserves visual stability (the same wobble appears in the same place
/// across rebuilds).
class SketchRenderCache {
  SketchRenderCache({this.maxEntries = 512});

  final int maxEntries;
  final Map<String, _Entry> _strokeEntries = {};
  final Map<String, _Entry> _fillEntries = {};

  Path strokePath(SketchElement element) {
    final key = _strokeKey(element);
    final hit = _strokeEntries[key];
    if (hit != null) return hit.path;
    final path = _buildStroke(element);
    _strokeEntries[key] = _Entry(path);
    _evictIfFull(_strokeEntries);
    return path;
  }

  Path fillPath(SketchElement element) {
    final key = _fillKey(element);
    final hit = _fillEntries[key];
    if (hit != null) return hit.path;
    final path = _buildFill(element);
    _fillEntries[key] = _Entry(path);
    _evictIfFull(_fillEntries);
    return path;
  }

  void clear() {
    _strokeEntries.clear();
    _fillEntries.clear();
  }

  void _evictIfFull(Map<String, _Entry> entries) {
    if (entries.length <= maxEntries) return;
    // Drop the oldest insertion (Dart maps preserve insertion order).
    final firstKey = entries.keys.first;
    entries.remove(firstKey);
  }

  // ── key builders: cheap, identity-sensitive without allocating bigobjects
  String _strokeKey(SketchElement e) {
    final s = e.style;
    final base =
        '${e.id}|${s.seed}|${s.roughness.toStringAsFixed(2)}|s';
    switch (e) {
      case SketchRectangle r:
        return '$base|${r.rect.left},${r.rect.top},${r.rect.width},${r.rect.height},${r.cornerRadius}';
      case SketchEllipse el:
        return '$base|${el.rect.left},${el.rect.top},${el.rect.width},${el.rect.height}';
      case SketchDiamond d:
        return '$base|${d.rect.left},${d.rect.top},${d.rect.width},${d.rect.height}';
      case SketchTriangle t:
        return '$base|${t.rect.left},${t.rect.top},${t.rect.width},${t.rect.height}';
      case SketchSticky s:
        return '$base|${s.rect.left},${s.rect.top},${s.rect.width},${s.rect.height}|${s.cornerRadius}';
      case SketchLine l:
        return '$base|${l.start.dx},${l.start.dy},${l.end.dx},${l.end.dy}';
      case SketchArrow a:
        return '$base|${a.start.dx},${a.start.dy},${a.end.dx},${a.end.dy}|${a.arrowSize}';
      case SketchFreedraw f:
        return '$base|pts=${f.points.length}|h=${f.bounds.hashCode}';
      case SketchText t:
        return '$base|txt=${t.text.hashCode}|fs=${t.fontSize}';
    }
  }

  String _fillKey(SketchElement e) {
    final s = e.style;
    final base =
        '${e.id}|${s.seed}|${s.fillStyle.name}|${s.roughness.toStringAsFixed(2)}|f';
    switch (e) {
      case SketchRectangle r:
        return '$base|${r.rect.left},${r.rect.top},${r.rect.width},${r.rect.height}';
      case SketchEllipse el:
        return '$base|${el.rect.left},${el.rect.top},${el.rect.width},${el.rect.height}';
      case SketchDiamond d:
        return '$base|${d.rect.left},${d.rect.top},${d.rect.width},${d.rect.height}';
      case SketchTriangle t:
        return '$base|${t.rect.left},${t.rect.top},${t.rect.width},${t.rect.height}';
      case SketchSticky s:
        return '$base|${s.rect.left},${s.rect.top},${s.rect.width},${s.rect.height}';
      default:
        return base;
    }
  }

  Path _buildStroke(SketchElement element) {
    final s = element.style;
    final r = s.roughness;
    final seed = s.seed;
    switch (element) {
      case SketchRectangle rect:
        return RoughGenerator.rectangle(
          rect.rect,
          roughness: r,
          seed: seed,
          cornerRadius: rect.cornerRadius,
        );
      case SketchEllipse el:
        return RoughGenerator.ellipse(
          el.rect,
          roughness: r,
          seed: seed,
        );
      case SketchDiamond d:
        return RoughGenerator.diamond(
          d.rect,
          roughness: r,
          seed: seed,
        );
      case SketchTriangle t:
        return RoughGenerator.triangle(
          t.rect,
          roughness: r,
          seed: seed,
        );
      case SketchSticky s:
        return RoughGenerator.rectangle(
          s.rect,
          roughness: r,
          seed: seed,
          cornerRadius: s.cornerRadius,
          doubleStroke: false,
        );
      case SketchLine l:
        return RoughGenerator.line(
          l.start,
          l.end,
          roughness: r,
          seed: seed,
        );
      case SketchArrow a:
        return RoughGenerator.line(
          a.start,
          a.end,
          roughness: r,
          seed: seed,
        );
      case SketchFreedraw f:
        return RoughGenerator.polyline(
          f.points,
          roughness: r * 0.0, // freehand already noisy
          seed: seed,
        );
      case SketchText _:
        return Path();
    }
  }

  Path _buildFill(SketchElement element) {
    final s = element.style;
    if (s.fillStyle == FillStyle.none || s.fillColor == null) {
      return Path();
    }

    switch (s.fillStyle) {
      case FillStyle.solid:
        final path = Path();
        switch (element) {
          case SketchRectangle r:
            path.addRect(r.rect);
            return path;
          case SketchEllipse el:
            path.addOval(el.rect);
            return path;
          case SketchDiamond d:
            path.moveTo(d.rect.center.dx, d.rect.top);
            path.lineTo(d.rect.right, d.rect.center.dy);
            path.lineTo(d.rect.center.dx, d.rect.bottom);
            path.lineTo(d.rect.left, d.rect.center.dy);
            path.close();
            return path;
          case SketchTriangle t:
            path.moveTo(t.rect.center.dx, t.rect.top);
            path.lineTo(t.rect.right, t.rect.bottom);
            path.lineTo(t.rect.left, t.rect.bottom);
            path.close();
            return path;
          case SketchSticky s:
            path.addRRect(RRect.fromRectAndRadius(
              s.rect,
              Radius.circular(s.cornerRadius),
            ));
            return path;
          default:
            return path;
        }
      case FillStyle.hachure:
      case FillStyle.crossHatch:
        final rect = element.bounds;
        final hachure = RoughGenerator.hachure(
          rect,
          gap: 8.0,
          angleDeg: -41.0,
          roughness: s.roughness,
          seed: s.seed,
        );
        if (s.fillStyle == FillStyle.crossHatch) {
          final cross = RoughGenerator.hachure(
            rect,
            gap: 8.0,
            angleDeg: 41.0,
            roughness: s.roughness,
            seed: s.seed + 1,
          );
          final merged = Path()
            ..addPath(hachure, Offset.zero)
            ..addPath(cross, Offset.zero);
          return merged;
        }
        return hachure;
      case FillStyle.none:
        return Path();
    }
  }
}

class _Entry {
  _Entry(this.path);
  final Path path;
}
