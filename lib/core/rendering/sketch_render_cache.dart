import 'dart:math' as math;
import 'dart:typed_data' show Uint8List;
import 'dart:ui';

import 'package:flutter/foundation.dart' show ChangeNotifier;
import 'package:flutter/painting.dart'
    show FontWeight, TextDirection, TextPainter, TextSpan, TextStyle;

import 'package:flowcraft/core/domain/text_metrics.dart';
import 'package:flowcraft/models/icon_catalog.dart';

import 'package:flowcraft/core/domain/sticky_bubble_geometry.dart';
import 'package:flowcraft/models/sketch_element.dart';
import 'package:flowcraft/models/sketch_style.dart';
import 'package:flowcraft/core/rendering/rough_generator.dart';
import 'package:flowcraft/services/image_source_core.dart'
    show checkedImageSize;

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
///
/// Also owns the decoded [Image] of every [SketchImage] (decoded once, off
/// the paint path, disposed when the element leaves the cache). It is a
/// [ChangeNotifier] so a finished decode repaints whoever listens — the
/// painter subscribes through its `repaint`.
class SketchRenderCache extends ChangeNotifier {
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
  final Map<SketchEntity, EntityLabels> _entityText = {};

  /// Decoded bitmaps keyed by the *bytes* instance, not the element: a
  /// move/resize/restyle mints a new [SketchImage] sharing the same bytes,
  /// and must not re-decode (up to 4 MiB) per pointer move. A present key
  /// with a `null` value is "decoding" (or undecodable/oversized — a bad
  /// file is not retried every frame).
  final Map<Uint8List, Image?> _images = Map.identity();
  bool _disposed = false;

  /// How many decodes have been started. Exposed for tests asserting an
  /// image is decoded once however often it is painted.
  int imageDecodeCount = 0;

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

  /// Padding between an entity's edge and its text, in canvas px.
  static const double entityPad = 8.0;

  /// Width of an entity's PK/FK tag column; zero when no row has a key, so
  /// plain tables don't waste a gutter.
  static double entityTagWidth(SketchEntity e) =>
      e.attributes.any((a) => a.primaryKey || a.foreignKey)
      ? e.fontSize * 2.4
      : 0.0;

  /// The tag text of [a] (`PK`, `FK`, `PK FK`), or null for a plain column.
  static String? entityTag(EntityAttribute a) => a.primaryKey || a.foreignKey
      ? [if (a.primaryKey) 'PK', if (a.foreignKey) 'FK'].join(' ')
      : null;

  /// The glyph of icon [name] laid out at [size] px in [color]. The caller
  /// owns the painter.
  static TextPainter layoutIcon(String name, double size, Color color) {
    final data = iconFor(name);
    return TextPainter(
      text: TextSpan(
        text: String.fromCharCode(data.codePoint),
        style: TextStyle(
          fontFamily: data.fontFamily,
          package: data.fontPackage,
          fontSize: size,
          color: color,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
  }

  /// [icon]'s glyph at `min(width, height)`, in its stroke colour and
  /// opacity; built once per instance and owned by the cache.
  TextPainter iconPainter(SketchIcon icon) => textPainter(
    icon,
    () => layoutIcon(
      icon.name,
      math.min(icon.rect.width, icon.rect.height),
      icon.style.strokeColor.withValues(alpha: icon.style.opacity),
    ),
  );

  /// Laid-out header and rows of [entity], built once per instance.
  EntityLabels entityLabels(SketchEntity entity) =>
      _entityText[entity] ?? _insert(_entityText, entity, _buildLabels(entity));

  EntityLabels _buildLabels(SketchEntity e) {
    final color = e.style.strokeColor.withValues(alpha: e.style.opacity);
    TextPainter mono(String t, double size, {bool bold = false}) =>
        TextMetrics.layout(
          text: t,
          fontSize: size,
          fontFamily: 'mono',
          fontWeight: bold ? FontWeight.w500 : null,
          color: color,
        );
    return EntityLabels(
      header: TextMetrics.layout(
        text: e.name,
        fontSize: e.fontSize,
        fontWeight: FontWeight.w700,
        color: color,
      ),
      rows: [
        for (final a in e.attributes)
          (
            tag: entityTag(a) == null
                ? null
                : mono(entityTag(a)!, e.fontSize * 0.75, bold: true),
            name: TextMetrics.layout(
              text: a.name,
              fontSize: e.fontSize,
              color: color,
            ),
            type: a.type.isEmpty ? null : mono(a.type, e.fontSize * 0.85),
          ),
      ],
    );
  }

  /// The decoded bitmap of [image], or null while it is still decoding (the
  /// painter draws a placeholder and is repainted via [notifyListeners]).
  Image? imageFor(SketchImage image) {
    final bytes = image.bytes;
    if (_images.containsKey(bytes)) return _images[bytes];
    _images[bytes] = null;
    _insertsSinceSweep++;
    _decode(bytes);
    return null;
  }

  Future<void> _decode(Uint8List bytes) async {
    imageDecodeCount++;
    Image? decoded;
    try {
      await checkedImageSize(bytes); // Refuse decode bombs before decoding.
      final codec = await instantiateImageCodec(bytes);
      decoded = (await codec.getNextFrame()).image;
      codec.dispose();
    } catch (_) {
      return; // Undecodable/oversized: stays a placeholder, not retried.
    }
    // Swept (or the cache closed) while decoding: nobody will paint it.
    if (_disposed || !_images.containsKey(bytes)) {
      decoded.dispose();
      return;
    }
    _images[bytes] = decoded;
    notifyListeners();
  }

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
    _entityText.removeWhere((e, labels) {
      final stale = !live.contains(e);
      if (stale) labels.dispose();
      return stale;
    });
    // An image is shared by every element copy carrying its bytes.
    final liveBytes = Set<Uint8List>.identity();
    for (final e in elements) {
      if (e is SketchImage) liveBytes.add(e.bytes);
    }
    _images.removeWhere((bytes, image) {
      final stale = !liveBytes.contains(bytes);
      if (stale) image?.dispose();
      return stale;
    });
  }

  /// Releases every cached painter. Call when the owning widget goes away;
  /// the cache is not usable afterwards.
  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _insertsSinceSweep = 0;
    _stroke.clear();
    _fill.clear();
    _outline.clear();
    for (final painter in _text.values) {
      painter.dispose();
    }
    _text.clear();
    for (final labels in _entityText.values) {
      labels.dispose();
    }
    _entityText.clear();
    for (final image in _images.values) {
      image?.dispose();
    }
    _images.clear();
    super.dispose();
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
        path = a.elbowed
            // Straight segments: the default smoothing would round the very
            // bends that make the route elbowed.
            ? RoughGenerator.polyline(
                a.points,
                roughness: r,
                seed: seed,
                smooth: false,
              )
            : RoughGenerator.line(a.start, a.end, roughness: r, seed: seed);
      case SketchFreedraw f:
        path = RoughGenerator.polyline(
          f.points,
          roughness: 0.0, // freehand already noisy
          seed: seed,
        );
      case SketchFrame f:
        // Clean 1px border, not rough: a frame is a container, not a shape.
        path = Path()..addRect(f.rect);
      case SketchEntity e:
        path = RoughGenerator.rectangle(e.rect, roughness: r, seed: seed);
        // Header and row dividers, each a rough line like the box edge.
        for (var i = 0; i < e.attributes.length; i++) {
          final y = e.rect.top + e.headerHeight + i * e.rowHeight;
          path.addPath(
            RoughGenerator.line(
              Offset(e.rect.left, y),
              Offset(e.rect.right, y),
              roughness: r,
              seed: seed + i + 1,
            ),
            Offset.zero,
          );
        }
      case SketchText _:
      case SketchIcon _:
      case SketchImage _:
        return Path(); // Glyph / bitmap, drawn by the painter.
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
      case SketchFrame f:
        path.addRect(f.rect);
      case SketchEntity e:
        path.addRect(e.rect);
      case SketchLine _:
      case SketchArrow _:
      case SketchFreedraw _:
      case SketchText _:
      case SketchIcon _:
      case SketchImage _:
        break; // No interior.
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

/// Laid-out text of one [SketchEntity]: the header and, per attribute, the
/// optional tag and type (mono) around the name. Owned by the cache.
class EntityLabels {
  EntityLabels({required this.header, required this.rows});

  final TextPainter header;
  final List<({TextPainter? tag, TextPainter name, TextPainter? type})> rows;

  void dispose() {
    header.dispose();
    for (final r in rows) {
      r.tag?.dispose();
      r.name.dispose();
      r.type?.dispose();
    }
  }
}
