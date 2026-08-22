import 'dart:ui';

import 'package:flutter/painting.dart' show TextPainter;

import 'package:flowcraft/core/domain/sticky_bubble_geometry.dart';
import 'package:flowcraft/models/sketch_element.dart';
import 'package:flowcraft/models/sketch_style.dart';
import 'package:flowcraft/core/rendering/rough_generator.dart';

/// Per-element cache of everything the painter derives from an element
/// that is expensive to derive and does not change between frames: the
/// rough stroke path (already dashed, when the style says so), the fill
/// path, the solid outline a hatch fill is clipped to, and the laid-out
/// [TextPainter] for any label.
///
/// Keyed by element *identity*. Elements are immutable and none of the
/// `SketchElement` subclasses override `==`, so a map keyed on the
/// instance is an exact identity cache: every edit — a drag step, a
/// restyle, a collapse toggle — produces a new instance and therefore a
/// fresh entry, while undo/redo hand back the very instances the history
/// snapshot kept and hit straight away. That replaces the string keys this
/// cache used to build per element per frame (four doubles interpolated
/// and hashed per lookup, an O(points) `bounds` scan for freedraw) and the
/// `collapsed`/`strokeStyle`-in-key bookkeeping they needed.
///
/// Memory is bounded by the scene, not by a constant: [sweep] drops every
/// entry whose element is no longer in the list being painted. A fixed cap
/// (it was 512, FIFO) meant a 1 000-element board evicted, on every frame,
/// exactly the entries the next frame needed — a 0 % hit rate above the
/// cap, and every rough path rebuilt every frame.
class SketchRenderCache {
  SketchRenderCache();

  /// Insertions tolerated between two walks of the maps by [sweep].
  ///
  /// Every stale entry was once an insertion, so counting insertions bounds
  /// staleness at this many entries whatever the scene size — a cap on map
  /// size relative to the scene would not, on a board that is mostly
  /// off-screen. A drag inserts one entry per moved element per frame, so
  /// sweeping on every generation would be an O(n) walk per pointer move;
  /// this slack makes the walk amortised (every ~[sweepSlack] frames of a
  /// single-element drag).
  static const int sweepSlack = 256;

  final Map<SketchElement, Path> _stroke = {};
  final Map<SketchElement, Path> _fill = {};
  final Map<SketchElement, Path> _outline = {};
  final Map<SketchElement, TextPainter> _text = {};

  int? _sweptGen;
  int _insertsSinceSweep = 0;

  /// Number of cached stroke paths. Exposed for tests that assert the
  /// sweep keeps the cache bounded.
  int get strokeEntryCount => _stroke.length;

  /// Number of cached text painters. See [strokeEntryCount].
  int get textEntryCount => _text.length;

  /// The element's outline, rough and — when its stroke style has a
  /// pattern — already cut into dashes, so the painter draws it with one
  /// `drawPath`.
  Path strokePath(SketchElement element) =>
      _stroke[element] ?? _insert(_stroke, element, _buildStroke(element));

  /// The element's fill: its silhouette for a solid fill, the hatch lines
  /// for `hachure`/`crossHatch`, empty otherwise.
  ///
  /// Hatch lines are generated over the element's *bounding rect*; the
  /// painter clips them to [outlinePath] so a hatched circle is hatched
  /// inside the circle, not the square around it. The clip stays at paint
  /// time rather than being baked in here because `Path.combine` on open
  /// contours is not something to rely on.
  Path fillPath(SketchElement element) =>
      _fill[element] ?? _insert(_fill, element, _buildFill(element));

  /// The element's clean silhouette — what a solid fill paints — used as
  /// the clip for a hatch fill. Empty for elements with no interior.
  Path outlinePath(SketchElement element) =>
      _outline[element] ?? _insert(_outline, element, _buildOutline(element));

  /// True when a `hachure`/`crossHatch` [element] is too large to hatch and
  /// [fillPath] is therefore its solid silhouette — the painter fills it
  /// rather than stroking it. See [RoughGenerator.maxHachureSteps].
  static bool hatchFallsBackToSolid(SketchElement element) =>
      !RoughGenerator.hachureFits(element.bounds);

  /// Whether a hatch fill on [element] needs clipping to [outlinePath].
  ///
  /// Hatch lines are generated inside the bounding rect, which *is* a
  /// rectangle's outline — clipping there would be a clip per element per
  /// frame for nothing. Every other closed shape is smaller than its box.
  static bool hatchNeedsClip(SketchElement element) =>
      element is! SketchRectangle;

  /// The laid-out painter for [element]'s label, built once by [build] and
  /// owned (and eventually disposed) by this cache — do not dispose it.
  ///
  /// Everything a label's layout depends on (text, size, family, colour,
  /// opacity, the box it wraps in) lives on the element, so identity is a
  /// complete key here too.
  TextPainter textPainter(
    SketchElement element,
    TextPainter Function() build,
  ) => _text[element] ?? _insert(_text, element, build());

  V _insert<V>(Map<SketchElement, V> map, SketchElement element, V value) {
    _insertsSinceSweep++;
    return map[element] = value;
  }

  /// Drops and disposes entries for elements that are not in [elements].
  ///
  /// Cheap to call every frame: it does nothing until [generation] changes
  /// (the controller's `paintGen`, which bumps on every scene mutation —
  /// the only time an entry *can* go stale), and then only walks the maps
  /// once more than [sweepSlack] entries have been inserted since the last
  /// walk.
  void sweep(List<SketchElement> elements, {required int generation}) {
    if (_sweptGen == generation) return;
    _sweptGen = generation;
    if (_insertsSinceSweep <= sweepSlack) return;
    _insertsSinceSweep = 0;
    final live = Set<SketchElement>.identity()..addAll(elements);
    _stroke.removeWhere((e, _) => !live.contains(e));
    _fill.removeWhere((e, _) => !live.contains(e));
    _outline.removeWhere((e, _) => !live.contains(e));
    _text.removeWhere((e, painter) {
      final stale = !live.contains(e);
      if (stale) painter.dispose();
      return stale;
    });
  }

  /// Releases every cached painter. Call when the owning widget goes away;
  /// the cache is not usable afterwards.
  void dispose() {
    _insertsSinceSweep = 0;
    _stroke.clear();
    _fill.clear();
    _outline.clear();
    for (final painter in _text.values) {
      painter.dispose();
    }
    _text.clear();
  }

  // ── builders ─────────────────────────────────────────────────────────────

  Path _buildStroke(SketchElement element) {
    final s = element.style;
    final r = s.roughness;
    final seed = s.seed;
    final Path path;
    switch (element) {
      case SketchRectangle rect:
        path = RoughGenerator.rectangle(
          rect.rect,
          roughness: r,
          seed: seed,
          cornerRadius: rect.cornerRadius,
        );
      case SketchEllipse el:
        path = RoughGenerator.ellipse(el.rect, roughness: r, seed: seed);
      case SketchDiamond d:
        path = RoughGenerator.diamond(d.rect, roughness: r, seed: seed);
      case SketchTriangle t:
        path = RoughGenerator.triangle(t.rect, roughness: r, seed: seed);
      case SketchSticky s:
        // Clean on purpose, whatever the element's roughness — see
        // `StickyBubbleGeometry`. Expanded, the stroke is the very path the
        // fill is painted from, so the outline hugs the fill exactly;
        // collapsed, the only line work is the badge's bubble mark, as the
        // badge itself is a solid chip — and a mark is an icon, so it is
        // never dashed either.
        if (s.collapsed) return StickyBubbleGeometry.glyphPath(s.rect);
        path = StickyBubbleGeometry.bubblePath(s.rect, s.cornerRadius);
      case SketchLine l:
        path = RoughGenerator.line(l.start, l.end, roughness: r, seed: seed);
      case SketchArrow a:
        path = RoughGenerator.line(a.start, a.end, roughness: r, seed: seed);
      case SketchFreedraw f:
        path = RoughGenerator.polyline(
          f.points,
          roughness: 0.0, // freehand already noisy
          seed: seed,
        );
      case SketchText _:
        return Path();
    }
    // The pattern is in canvas units (pre-zoom), so the dashed result is
    // zoom-invariant and as cacheable as the rough path itself.
    return RoughGenerator.dash(path, s.strokeStyle.pattern);
  }

  Path _buildOutline(SketchElement element) {
    final path = Path();
    switch (element) {
      case SketchRectangle r:
        path.addRect(r.rect);
      case SketchEllipse el:
        path.addOval(el.rect);
      case SketchDiamond d:
        path.moveTo(d.rect.center.dx, d.rect.top);
        path.lineTo(d.rect.right, d.rect.center.dy);
        path.lineTo(d.rect.center.dx, d.rect.bottom);
        path.lineTo(d.rect.left, d.rect.center.dy);
        path.close();
      case SketchTriangle t:
        path.moveTo(t.rect.center.dx, t.rect.top);
        path.lineTo(t.rect.right, t.rect.bottom);
        path.lineTo(t.rect.left, t.rect.bottom);
        path.close();
      case SketchSticky s:
        return s.collapsed
            ? StickyBubbleGeometry.badgeFillPath(s.rect)
            : StickyBubbleGeometry.bubblePath(s.rect, s.cornerRadius);
      case SketchLine _:
      case SketchArrow _:
      case SketchFreedraw _:
      case SketchText _:
        break;
    }
    return path;
  }

  Path _buildFill(SketchElement element) {
    final s = element.style;
    if (s.fillStyle == FillStyle.none || s.fillColor == null) {
      return Path();
    }

    switch (s.fillStyle) {
      case FillStyle.solid:
        return _buildOutline(element);
      case FillStyle.hachure:
      case FillStyle.crossHatch:
        final rect = element.bounds;
        // A shape too large to hatch within `RoughGenerator.maxHachureSteps`
        // is filled solid instead; the painter checks the same predicate
        // (`hatchFallsBackToSolid`) to paint it as a fill, not a stroke.
        if (!RoughGenerator.hachureFits(rect)) return _buildOutline(element);
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
